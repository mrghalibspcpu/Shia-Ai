import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../text_utils.dart' show searchMatchRanges;
import 'highlighted_text.dart';

/// Reader appearance shared by every collection.
class ReaderPreferences {
  const ReaderPreferences({
    this.palette = ReaderPalette.paper,
    this.fontScale = 1.0,
    this.script = 'both',
  });

  final ReaderPalette palette;
  final double fontScale;

  /// `both`, `arabic`, or `urdu`.
  final String script;

  static Future<ReaderPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReaderPreferences(
      palette: ReaderPalette.fromName(prefs.getString('reader_palette')),
      fontScale: (prefs.getDouble('reader_font_scale') ?? 1.0).clamp(0.85, 1.6).toDouble(),
      script: prefs.getString('reader_script') ?? 'both',
    );
  }

  Future<void> savePalette(ReaderPalette palette) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_palette', palette.key);
  }

  Future<void> saveFontScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_scale', scale);
  }

  Future<void> saveScript(String script) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_script', script);
  }

  ReaderPreferences copyWith({ReaderPalette? palette, double? fontScale, String? script}) =>
      ReaderPreferences(
        palette: palette ?? this.palette,
        fontScale: fontScale ?? this.fontScale,
        script: script ?? this.script,
      );
}

/// The font size and palette controls used by every reader app bar.
///
/// The Arabic/Urdu/both choice intentionally lives in Settings, not here: a
/// toolbar button for it (the old globe icon) was removed at readers'
/// request so the reading screen stays uncluttered.
class ReaderControls extends StatelessWidget {
  const ReaderControls({
    super.key,
    required this.preferences,
    required this.onChanged,
    this.extra = const [],
  });

  final ReaderPreferences preferences;
  final ValueChanged<ReaderPreferences> onChanged;
  final List<Widget> extra;

  Future<void> _choosePalette(BuildContext context) async {
    final selected = await showModalBottomSheet<ReaderPalette>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in ReaderPalette.all)
              ListTile(
                leading: Icon(Icons.circle, color: entry.background),
                title: JustifiedText(entry.name),
                trailing: entry.key == preferences.palette.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, entry),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await preferences.savePalette(selected);
    onChanged(preferences.copyWith(palette: selected));
  }

  Future<void> _adjustFont(double delta) async {
    final next = (preferences.fontScale + delta).clamp(0.85, 1.6).toDouble();
    await preferences.saveFontScale(next);
    onChanged(preferences.copyWith(fontScale: next));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...extra,
        IconButton(
          tooltip: 'حروف چھوٹے',
          onPressed: () => _adjustFont(-0.08),
          icon: const Icon(Icons.text_decrease),
        ),
        IconButton(
          tooltip: 'حروف بڑے',
          onPressed: () => _adjustFont(0.08),
          icon: const Icon(Icons.text_increase),
        ),
        IconButton(
          tooltip: 'مطالعے کا انداز',
          onPressed: () => _choosePalette(context),
          icon: const Icon(Icons.palette_outlined),
        ),
      ],
    );
  }
}

/// One record rendered as a card: text, translation, notes, and user actions.
class PassageCard extends StatefulWidget {
  const PassageCard({
    super.key,
    required this.library,
    required this.book,
    required this.passage,
    required this.palette,
    this.fontScale = 1.0,
    this.script = 'both',
    this.indexLabel,
    this.stateId,
    this.searchQuery = '',
    this.focusMatch = false,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final Passage passage;
  final ReaderPalette palette;
  final double fontScale;
  final String script;
  final String? indexLabel;

  /// Record the bookmark/note is stored against. Readers that show one document
  /// as many cards (a supplication, a khutba) point every card at the document,
  /// while `passage.recordId` stays unique per card.
  final int? stateId;
  final String searchQuery;
  final bool focusMatch;

  @override
  State<PassageCard> createState() => _PassageCardState();
}

class _PassageCardState extends State<PassageCard> {
  bool _bookmarked = false;
  String? _note;

  /// Tafseer and footnotes stay folded until the reader asks for them; a wall
  /// of auto-expanded commentary under every verse made surahs unreadable.
  bool _showCommentary = false;
  bool _showFootnote = false;

  int get _stateId => widget.stateId ?? widget.passage.recordId;

  /// Match ranges cost a pass over the whole string, so never run the search
  /// for the (overwhelmingly common) case of a reader with no query.
  List<({int start, int end})> _matches(String text) =>
      widget.searchQuery.isEmpty ? const [] : searchMatchRanges(text, widget.searchQuery);

  /// Paints with the cached bookmark/note state; `_refresh` then corrects it.
  /// Doing it this way keeps a card at one build instead of three.
  void _syncFromCache() {
    _bookmarked = widget.library.isBookmarkedNow(widget.book.key, _stateId);
    _note = widget.library.noteNow(widget.book.key, _stateId);
  }

  @override
  void initState() {
    super.initState();
    _showCommentary = _matches(widget.passage.commentary).isNotEmpty;
    _showFootnote = _matches(widget.passage.footnote).isNotEmpty;
    _syncFromCache();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant PassageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passage.recordId != widget.passage.recordId ||
        oldWidget.book.key != widget.book.key ||
        oldWidget.stateId != widget.stateId) {
      _showCommentary = false;
      _showFootnote = false;
      _syncFromCache();
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final bookmarked = await widget.library.isBookmarked(widget.book.key, _stateId);
    final note = await widget.library.getNote(widget.book.key, _stateId);
    if (!mounted) return;
    if (bookmarked == _bookmarked && note == _note) return;
    setState(() {
      _bookmarked = bookmarked;
      _note = note;
    });
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const JustifiedText('اپنا نوٹ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          textAlign: TextAlign.start,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(hintText: 'یہاں لکھیں'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('منسوخ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('محفوظ کریں'),
          ),
        ],
      ),
    );
    if (note == null) return;
    await widget.library.saveNote(widget.book.key, _stateId, note);
    if (mounted) setState(() => _note = note.trim().isEmpty ? null : note.trim());
  }

  /// Opens the official page this ruling was taken from.
  ///
  /// The fatawa databases store one `source_url` per answer, so a reader can
  /// check the wording against the marja's own site instead of trusting a copy.
  Future<void> _openSource() async {
    final uri = Uri.tryParse(widget.passage.sourceUrl);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('یہ لنک نہیں کھل سکا — انٹرنیٹ چیک کریں۔')),
    );
  }

  Future<void> _copyText() async {
    final value = widget.passage.copyableText;
    if (value.trim().isEmpty) return;
    final header = [
      widget.book.titleUrdu,
      if (widget.passage.sectionTitle.isNotEmpty) widget.passage.sectionTitle,
      if (widget.passage.locator.isNotEmpty) widget.passage.locator,
    ].join(' — ');
    await Clipboard.setData(ClipboardData(text: '$header\n$value'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کاپی ہو گیا۔')));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.palette.foreground;
    final passage = widget.passage;
    final showArabic = widget.script != 'urdu' && passage.arabic.trim().isNotEmpty;
    final showUrdu = widget.script != 'arabic' && passage.urdu.trim().isNotEmpty;
    final showCommentary =
        widget.script != 'arabic' && passage.commentary.trim().isNotEmpty;
    final showFootnote = widget.script != 'arabic' && passage.footnote.trim().isNotEmpty;
    // Never fall back to the raw database id: Parags.ID 562276 is a storage
    // key, not a hadith number, and printing it as one confused readers.
    // Callers pass a proper indexLabel (آیت ٦, حدیث ۵) or a locator instead.
    final header = widget.indexLabel ?? passage.locator;
    final isTitle = passage.format == 1;
    final isSubHeading = passage.format == 3;

    // Isolating each card keeps a scroll (or a bookmark tap) from repainting
    // the whole list — with 286 verse cards that was visible as jank.
    return RepaintBoundary(
      child: Card(
        color: widget.palette.background,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: textColor.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      header,
                      style: TextStyle(color: textColor.withValues(alpha: 0.65), fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: _bookmarked ? 'محفوظ سے ہٹائیں' : 'محفوظ کریں',
                    onPressed: () async {
                      await widget.library.toggleBookmark(widget.book.key, _stateId);
                      if (mounted) setState(() => _bookmarked = !_bookmarked);
                    },
                    icon: Icon(
                      _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _bookmarked ? kGold : textColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'کاپی',
                    onPressed: _copyText,
                    icon: Icon(Icons.copy, color: textColor),
                  ),
                  IconButton(
                    tooltip: 'نوٹ',
                    onPressed: _editNote,
                    icon: Icon(Icons.edit_note, color: textColor),
                  ),
                ],
              ),
              if (showArabic) ...[
                // Plain Text on purpose, inside a SelectionArea provided by the
                // reader screens: a SelectableText per card made long lists
                // (286 verse cards, each with three of them) render as grey,
                // unpainted blocks on slower phones.
                HighlightedText(
                  passage.arabic,
                  query: widget.searchQuery,
                  scrollToMatch: widget.focusMatch,
                  arabic: true,
                  style: TextStyle(
                    fontSize: (isTitle ? 25 : isSubHeading ? 21 : 22) * widget.fontScale,
                    fontWeight: isTitle || isSubHeading ? FontWeight.bold : null,
                    color: isTitle || isSubHeading ? kForest : textColor,
                  ),
                ),
                if (showUrdu || showCommentary) ...[
                  const SizedBox(height: 12),
                  Divider(color: textColor.withValues(alpha: 0.12)),
                  const SizedBox(height: 8),
                ],
              ],
              if (showUrdu)
                HighlightedText(
                  passage.urdu,
                  query: widget.searchQuery,
                  scrollToMatch: widget.focusMatch && _matches(passage.arabic).isEmpty,
                  style: TextStyle(
                    fontSize: (isTitle ? 18 : 19) * widget.fontScale,
                    height: 1.6,
                    fontWeight: isTitle ? FontWeight.bold : null,
                    color: textColor,
                  ),
                ),
              if (showCommentary) ...[
                const SizedBox(height: 10),
                _ExpandableNote(
                  query: widget.searchQuery,
                  focusMatch: widget.focusMatch && _matches('${passage.arabic} ${passage.urdu}').isEmpty,
                  label: 'تفسیری حاشیہ',
                  body: passage.commentary,
                  expanded: _showCommentary,
                  onToggle: () => setState(() => _showCommentary = !_showCommentary),
                  textColor: textColor,
                  fontScale: widget.fontScale,
                ),
              ],
              if (showFootnote) ...[
                const SizedBox(height: 10),
                _ExpandableNote(
                  query: widget.searchQuery,
                  focusMatch: widget.focusMatch && _matches('${passage.arabic} ${passage.urdu} ${passage.commentary}').isEmpty,
                  label: 'حاشیہ',
                  body: passage.footnote,
                  expanded: _showFootnote,
                  onToggle: () => setState(() => _showFootnote = !_showFootnote),
                  textColor: textColor,
                  fontScale: widget.fontScale,
                ),
              ],
              if (_note != null) ...[
                const SizedBox(height: 12),
                _AnnotatedBox(
                  label: 'نوٹ',
                  body: _note!,
                  color: kGold,
                  textColor: textColor,
                  fontScale: widget.fontScale,
                ),
              ],
              if (passage.hasSource) ...[
                const SizedBox(height: 14),
                _SourceLink(
                  url: passage.sourceUrl,
                  reference: passage.sourceRef,
                  textColor: textColor,
                  fontScale: widget.fontScale,
                  onOpen: _openSource,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "verify it at the source" button under a fatawa answer.
///
/// Every row of `question_answers` carries the marja's own page, so the ruling
/// can be checked against the published original instead of a local copy. The
/// address is printed as well — a button alone hides where it leads.
class _SourceLink extends StatelessWidget {
  const _SourceLink({
    required this.url,
    required this.reference,
    required this.textColor,
    required this.fontScale,
    required this.onOpen,
  });

  final String url;
  final String reference;
  final Color textColor;
  final double fontScale;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final label = reference.trim().isEmpty
        ? 'اصل ماخذ پر جائیں'
        : 'اصل ماخذ پر جائیں — مسئلہ ${reference.trim()}';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: kForest.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kForest.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تصدیق کے لیے اصل سرکاری صفحہ',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: kForest,
              fontSize: 12 * fontScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            url,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 11 * fontScale,
              color: textColor.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: JustifiedText(label, style: TextStyle(fontSize: 14 * fontScale)),
          ),
        ],
      ),
    );
  }
}

/// A folded annotation — tafseer or footnote — that opens only on tap.
class _ExpandableNote extends StatelessWidget {
  const _ExpandableNote({
    required this.label,
    required this.body,
    required this.expanded,
    required this.onToggle,
    required this.textColor,
    required this.fontScale,
    this.query = '',
    this.focusMatch = false,
  });

  final String label;
  final String body;
  final bool expanded;
  final VoidCallback onToggle;
  final Color textColor;
  final double fontScale;
  final String query;
  final bool focusMatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: kForest,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(color: kForest, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 6),
          _AnnotatedBox(
            label: '',
            body: body,
            query: query,
            focusMatch: focusMatch,
            color: kForest,
            textColor: textColor,
            fontScale: fontScale,
          ),
        ],
      ],
    );
  }
}

class _AnnotatedBox extends StatelessWidget {
  const _AnnotatedBox({
    required this.label,
    required this.body,
    required this.color,
    required this.textColor,
    required this.fontScale,
    this.query = '',
    this.focusMatch = false,
  });

  final String label;
  final String body;
  final Color color;
  final Color textColor;
  final double fontScale;
  final String query;
  final bool focusMatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 4),
          ],
          HighlightedText(
            body,
            query: query,
            scrollToMatch: focusMatch,
            style: TextStyle(color: textColor, fontSize: 16 * fontScale, height: 1.55),
          ),
        ],
      ),
    );
  }
}

/// Shared empty/loading/error panels for the collection screens.
class CollectionMessage extends StatelessWidget {
  const CollectionMessage(this.message, {super.key, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45)),
              const SizedBox(height: 12),
            ],
            JustifiedText(message, style: const TextStyle(fontSize: 17)),
          ],
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: JustifiedText(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}
