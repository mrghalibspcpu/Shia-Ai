import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';

class LibraryHomeScreen extends StatelessWidget {
  const LibraryHomeScreen({super.key, required this.library, required this.onOpenAi});

  final LibraryRepository library;
  final void Function(BookDefinition book, Passage passage) onOpenAi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const JustifiedText('کتبِ احادیث'),
        actions: [
          IconButton(
            tooltip: 'محفوظ روایات',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BookmarksScreen(library: library, onOpenAi: onOpenAi),
            )),
            icon: const Icon(Icons.bookmark_outline),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
              child: _LibraryBanner(onOpenBookmarks: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BookmarksScreen(library: library, onOpenAi: onOpenAi),
                ));
              }),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverGrid.builder(
              itemCount: BookDefinition.all.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.94,
              ),
              itemBuilder: (context, index) => _BookCard(
                book: BookDefinition.all[index],
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChapterListScreen(library: library, book: BookDefinition.all[index], onOpenAi: onOpenAi),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryBanner extends StatelessWidget {
  const _LibraryBanner({required this.onOpenBookmarks});

  final VoidCallback onOpenBookmarks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [kForestDark, kForest],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [BoxShadow(color: kForest.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('شیعہ اے آئی', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('روایات، مطالعہ اور تحقیق', style: TextStyle(color: Color(0xFFE4D7B9), fontSize: 15)),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x88FFFFFF)),
                  ),
                  onPressed: onOpenBookmarks,
                  icon: const Icon(Icons.bookmark_border, size: 18),
                  label: const Text('محفوظ روایات'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/images/tasneemlogo.png', fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});

  final BookDefinition book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Icon(Icons.menu_book_rounded, color: colors.primary, size: 24),
              ),
              const Spacer(),
              JustifiedText(book.titleUrdu, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700), maxLines: 3),
              const SizedBox(height: 7),
              Text(book.titleLatin, textAlign: TextAlign.left, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'sans-serif', color: colors.onSurfaceVariant, fontSize: 11)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('ابواب دیکھیں', style: TextStyle(fontSize: 12))),
                  Icon(Icons.arrow_back_ios_new_rounded, color: colors.primary, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChapterListScreen extends StatelessWidget {
  const ChapterListScreen({super.key, required this.library, required this.book, required this.onOpenAi});

  final LibraryRepository library;
  final BookDefinition book;
  final void Function(BookDefinition book, Passage passage) onOpenAi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: JustifiedText(book.titleUrdu)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: library.getChapters(book),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _ErrorPanel(error: snapshot.error.toString());
          final chapters = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chapters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = chapters[index];
              final cid = _toInt(row['cid']) ?? 0;
              final title = (row['title'] ?? '').toString();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text('${index + 1}')),
                  title: JustifiedText(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SectionListScreen(library: library, book: book, chapterId: cid, chapterTitle: title, onOpenAi: onOpenAi),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SectionListScreen extends StatelessWidget {
  const SectionListScreen({
    super.key,
    required this.library,
    required this.book,
    required this.chapterId,
    required this.chapterTitle,
    required this.onOpenAi,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final int chapterId;
  final String chapterTitle;
  final void Function(BookDefinition book, Passage passage) onOpenAi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: JustifiedText(chapterTitle, maxLines: 1)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: library.getSections(book, chapterId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _ErrorPanel(error: snapshot.error.toString());
          final sections = snapshot.data ?? [];
          if (sections.isEmpty) return const Center(child: Text('اس باب میں کوئی فصل موجود نہیں۔'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = sections[index];
              final secid = _toInt(row['Secid']);
              final title = (row['title'] ?? '').toString();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                leading: const Icon(Icons.article_outlined),
                title: JustifiedText(title, style: const TextStyle(fontSize: 16)),
                subtitle: JustifiedText('فصل ${index + 1}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                trailing: const Icon(Icons.chevron_left),
                onTap: secid == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReaderScreen(library: library, book: book, sectionId: secid, sectionTitle: title, onOpenAi: onOpenAi),
                        )),
              );
            },
          );
        },
      ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.library,
    required this.book,
    this.recordId,
    this.sectionId,
    this.sectionTitle,
    this.cameFromAi = false,
    this.onOpenAi,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final int? recordId;
  final int? sectionId;
  final String? sectionTitle;
  final bool cameFromAi;
  final void Function(BookDefinition book, Passage passage)? onOpenAi;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  List<Passage> _passages = [];
  int _initialIndex = 0;
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;
  ReaderPalette _palette = ReaderPalette.paper;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_trackVisiblePassage);
    unawaited(_load());
  }

  void _trackVisiblePassage() {
    final visible = _itemPositionsListener.itemPositions.value
        .where((position) => position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1)
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    if (visible.isNotEmpty) _currentIndex = visible.first.index;
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_trackVisiblePassage);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final palette = ReaderPalette.fromName(prefs.getString('reader_palette'));
      List<Passage> passages;
      if (widget.recordId != null) {
        final passage = await widget.library.getPassageById(widget.book, widget.recordId!);
        if (passage == null) {
          passages = [];
        } else if (passage.sectionId != null) {
          passages = await widget.library.getSectionPassages(widget.book, passage.sectionId!);
          if (!passages.any((item) => item.recordId == passage.recordId)) passages.add(passage);
        } else {
          passages = [passage];
        }
      } else if (widget.sectionId != null) {
        passages = await widget.library.getSectionPassages(widget.book, widget.sectionId!);
      } else {
        passages = [];
      }
      var index = passages.indexWhere((passage) => passage.recordId == widget.recordId);
      if (index < 0) index = 0;
      if (mounted) {
        setState(() {
          _palette = palette;
          _passages = passages;
          _initialIndex = index;
          _currentIndex = index;
          _loading = false;
        });
        if (widget.recordId != null && passages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_itemScrollController.isAttached) {
              _itemScrollController.jumpTo(index: index, alignment: 0.04);
            }
          });
        }
      }
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _choosePalette() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final entry in const [('paper', ReaderPalette.paper), ('sepia', ReaderPalette.sepia), ('night', ReaderPalette.night)])
            ListTile(
              leading: Icon(Icons.circle, color: entry.$2.background),
              title: JustifiedText(entry.$2.name),
              onTap: () => Navigator.pop(context, entry.$1),
            ),
        ]),
      ),
    );
    if (selected == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_palette', selected);
    if (mounted) setState(() => _palette = ReaderPalette.fromName(selected));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _palette.background,
      appBar: AppBar(
        backgroundColor: _palette.background,
        foregroundColor: _palette.foreground,
        title: JustifiedText(widget.sectionTitle ?? widget.book.titleUrdu, style: TextStyle(color: _palette.foreground), maxLines: 1),
        actions: [
          IconButton(tooltip: 'مطالعے کا انداز', onPressed: _choosePalette, icon: const Icon(Icons.palette_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorPanel(error: _error!)
              : _passages.isEmpty
                  ? const Center(child: Text('اس حصے میں متن موجود نہیں۔'))
                  : ScrollablePositionedList.builder(
                      key: PageStorageKey('reader-${widget.book.key}-${widget.sectionId ?? widget.recordId}'),
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      initialScrollIndex: _initialIndex,
                      itemCount: _passages.length,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemBuilder: (context, index) => _PassageCard(
                        key: ValueKey('${widget.book.key}-${_passages[index].recordId}'),
                        library: widget.library,
                        book: widget.book,
                        passage: _passages[index],
                        palette: _palette,
                      ),
                    ),
      floatingActionButton: widget.cameFromAi || (widget.onOpenAi != null && _passages.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () {
                if (widget.cameFromAi) {
                  Navigator.of(context).pop();
                  return;
                }
                if (_passages.isEmpty) return;
                final index = _currentIndex.clamp(0, _passages.length - 1).toInt();
                final passage = _passages[index];
                final callback = widget.onOpenAi;
                Navigator.of(context).pop();
                callback?.call(widget.book, passage);
              },
              icon: const Icon(Icons.auto_awesome),
              label: Text(widget.cameFromAi ? 'واپس شیعہ اے آئی' : 'اس روایت سے سوال کریں'),
            )
          : null,
    );
  }
}

class _PassageCard extends StatefulWidget {
  const _PassageCard({super.key, required this.library, required this.book, required this.passage, required this.palette});

  final LibraryRepository library;
  final BookDefinition book;
  final Passage passage;
  final ReaderPalette palette;

  @override
  State<_PassageCard> createState() => _PassageCardState();
}

class _PassageCardState extends State<_PassageCard> {
  bool _bookmarked = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final bookmarked = await widget.library.isBookmarked(widget.book.key, widget.passage.recordId);
    final note = await widget.library.getNote(widget.book.key, widget.passage.recordId);
    if (mounted) setState(() { _bookmarked = bookmarked; _note = note; });
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const JustifiedText('اس روایت پر نوٹ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(hintText: 'اپنا نوٹ لکھیں'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('منسوخ')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('محفوظ کریں')),
        ],
      ),
    );
    if (note == null) return;
    await widget.library.saveNote(widget.book.key, widget.passage.recordId, note);
    if (mounted) setState(() => _note = note.trim().isEmpty ? null : note.trim());
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.palette.foreground;
    return Card(
      color: widget.palette.background,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: textColor.withValues(alpha: 0.08))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('حدیث نمبر ${widget.passage.recordId}${widget.passage.page == null ? '' : '  •  صفحہ ${widget.passage.page}'}', style: TextStyle(color: textColor.withValues(alpha: 0.65), fontSize: 12))),
                IconButton(
                  tooltip: _bookmarked ? 'محفوظ سے ہٹائیں' : 'محفوظ کریں',
                  onPressed: () async {
                    await widget.library.toggleBookmark(widget.book.key, widget.passage.recordId);
                    if (mounted) setState(() => _bookmarked = !_bookmarked);
                  },
                  icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border, color: _bookmarked ? kGold : textColor),
                ),
                IconButton(tooltip: 'نوٹ', onPressed: _editNote, icon: Icon(Icons.edit_note, color: textColor)),
              ],
            ),
            if (widget.passage.arabic.trim().isNotEmpty) ...[
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  widget.passage.arabic,
                  textAlign: TextAlign.justify,
                  style: TextStyle(fontFamily: kArabicFont, fontSize: 23, height: 1.9, color: textColor),
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: textColor.withValues(alpha: 0.12)),
              const SizedBox(height: 8),
            ],
            if (widget.passage.urdu.trim().isNotEmpty)
              JustifiedText(widget.passage.urdu, style: TextStyle(fontSize: 20, height: 1.75, color: textColor)),
            if (_note != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kGold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: JustifiedText('نوٹ: $_note', style: TextStyle(color: textColor, fontSize: 15)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key, required this.library, required this.onOpenAi});

  final LibraryRepository library;
  final void Function(BookDefinition book, Passage passage) onOpenAi;

  Future<List<(BookDefinition, Passage)>> _load() async {
    final targets = await library.getBookmarks();
    final output = <(BookDefinition, Passage)>[];
    for (final target in targets) {
      final book = BookDefinition.byKey(target.book);
      if (book == null) continue;
      final passage = await library.getPassageById(book, target.recordId);
      if (passage != null) output.add((book, passage));
    }
    return output;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('محفوظ روایات')),
      body: FutureBuilder<List<(BookDefinition, Passage)>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data ?? [];
          if (items.isEmpty) return const Center(child: JustifiedText('ابھی کوئی روایت محفوظ نہیں کی گئی۔'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final (book, passage) = items[index];
              return Card(
                child: ListTile(
                  title: JustifiedText(book.titleUrdu, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: JustifiedText(passage.urdu.isNotEmpty ? passage.urdu : passage.arabic, maxLines: 2),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ReaderScreen(library: library, book: book, recordId: passage.recordId, onOpenAi: onOpenAi),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: JustifiedText(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
