import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';

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

  String get nextScript => switch (script) {
        'arabic' => 'urdu',
        'urdu' => 'both',
        _ => 'arabic',
      };
}

/// The font/palette/script controls used by every reader app bar.
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

  Future<void> _cycleScript() async {
    final next = preferences.nextScript;
    await preferences.saveScript(next);
    onChanged(preferences.copyWith(script: next));
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
          tooltip: switch (preferences.script) {
            'arabic' => 'صرف عربی',
            'urdu' => 'صرف اردو',
            _ => 'عربی و اردو',
          },
          onPressed: _cycleScript,
          icon: Icon(switch (preferences.script) {
            'arabic' => Icons.translate,
            'urdu' => Icons.text_fields,
            _ => Icons.language,
          }),
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

  @override
  State<PassageCard> createState() => _PassageCardState();
}

class _PassageCardState extends State<PassageCard> {
  bool _bookmarked = false;
  String? _note;

  int get _stateId => widget.stateId ?? widget.passage.recordId;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant PassageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passage.recordId != widget.passage.recordId ||
        oldWidget.book.key != widget.book.key ||
        oldWidget.stateId != widget.stateId) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final bookmarked = await widget.library.isBookmarked(widget.book.key, _stateId);
    final note = await widget.library.getNote(widget.book.key, _stateId);
    if (mounted) {
      setState(() {
        _bookmarked = bookmarked;
        _note = note;
      });
    }
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
    final header = widget.indexLabel ??
        (passage.locator.isNotEmpty
            ? passage.locator
            : (passage.recordId > 0 ? '${widget.book.recordLabel} ${passage.recordId}' : ''));

    return Card(
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
              Directionality(
                textDirection: TextDirection.rtl,
                child: SelectableText(
                  passage.arabic,
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontFamily: kArabicFont,
                    fontSize: 22 * widget.fontScale,
                    height: 1.65,
                    letterSpacing: 0,
                    color: textColor,
                  ),
                ),
              ),
              if (showUrdu || showCommentary) ...[
                const SizedBox(height: 12),
                Divider(color: textColor.withValues(alpha: 0.12)),
                const SizedBox(height: 8),
              ],
            ],
            if (showUrdu)
              JustifiedText(
                passage.urdu,
                selectable: true,
                style: TextStyle(fontSize: 19 * widget.fontScale, height: 1.6, color: textColor),
              ),
            if (showCommentary) ...[
              const SizedBox(height: 10),
              _AnnotatedBox(
                label: 'تفسیری حاشیہ',
                body: passage.commentary,
                color: kForest,
                textColor: textColor,
                fontScale: widget.fontScale,
              ),
            ],
            if (showFootnote) ...[
              const SizedBox(height: 10),
              _AnnotatedBox(
                label: 'حاشیہ',
                body: passage.footnote,
                color: kForest,
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
          ],
        ),
      ),
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
  });

  final String label;
  final String body;
  final Color color;
  final Color textColor;
  final double fontScale;

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
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          JustifiedText(
            body,
            selectable: true,
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
