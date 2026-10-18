import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../reader_navigation.dart';
import '../text_utils.dart' show arabicNumerals;
import '../widgets/home_dashboard.dart';
import '../widgets/reader_kit.dart';
import '../widgets/reader_chrome.dart';
import '../widgets/chapter_wallpaper.dart';
import '../widgets/resume_card.dart';
import 'search_screen.dart';

class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({
    super.key,
    required this.library,
    this.onOpenData,
  });

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  @override
  Widget build(BuildContext context) {
    // The library rebuilds as soon as a download lands (catalogVersion), so a
    // freshly installed book appears in its container without pulling to
    // refresh.
    return ValueListenableBuilder<int>(
      valueListenable: widget.library.catalogVersion,
      builder: (context, _, __) => _buildHome(context),
    );
  }

  Widget _buildHome(BuildContext context) {
    // No top bar: the dashboard is the fifteen containers of the design — the
    // ShiaVerse rail, the prayer card, the five collections, آیت / حدیثِ وقت,
    // the tasbeeh dial and the search bar. The download notice and the search
    // index progress sit above it as one slim strip, and both disappear on
    // their own once they are done.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _HomeNoticeStrip(library: widget.library, onOpenData: widget.onOpenData),
            Expanded(
              child: HomeDashboard(
                library: widget.library,
                onOpenData: widget.onOpenData,
                onSearch: _openSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The search bar on the dashboard opens the working search screen, with the
  /// keyboard already up: the bar is a door, the search screen is the room.
  void _openSearch() {
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(
          library: widget.library,
          onOpenData: widget.onOpenData,
          autofocus: true,
        ),
      ),
    ));
  }
}

/// The one-line strip above the dashboard: what is not on the phone yet, and
/// how far the background search index has come. Nothing to say, no strip.
class _HomeNoticeStrip extends StatelessWidget {
  const _HomeNoticeStrip({required this.library, this.onOpenData});

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IndexBuildState>(
      valueListenable: library.indexProgress,
      builder: (context, state, _) {
        final total = BookDefinition.all.length;
        final installed = library.installedBooks.length;
        final missing = total - installed;
        if (missing <= 0 && !state.active) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
          child: Row(
            children: <Widget>[
              if (missing > 0)
                Expanded(
                  child: _NoticeChip(
                    icon: Icons.download_rounded,
                    label: installed == 0 ? 'ڈیٹا ڈاؤن لوڈ کریں' : '$missing کتب ابھی باقی ہیں',
                    onTap: onOpenData,
                    color: kGold,
                    ink: kForest,
                  ),
                ),
              if (missing > 0 && state.active) const SizedBox(width: 8),
              if (state.active)
                Expanded(
                  child: _NoticeChip(
                    icon: Icons.search_rounded,
                    label: 'تلاش کی فہرست بن رہی ہے ${(state.progress * 100).round()}%',
                    color: scheme.primary,
                    ink: scheme.primary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One small pill of the notice strip: an icon and one line of text.
class _NoticeChip extends StatelessWidget {
  const _NoticeChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.ink,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color ink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 16, color: ink),
              const SizedBox(width: 6),
              Expanded(
                child: JustifiedText(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  /// The badge the book rows and the hadith grid draw.
  static const double size = 42;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

/// Bookmarks and settings: the two things the bottom panel does not carry.
class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap, this.installed = true});

  final BookDefinition book;
  final VoidCallback onTap;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: installed ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(15),
            // Everything on the card is centred: the badge, the Urdu title,
            // the Latin title and the footer line all share one axis.
            child: Stack(
              children: [
                if (!installed)
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    child: Icon(Icons.download, size: 16, color: colors.error),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(child: _IconBadge(icon: Icons.menu_book_rounded, color: bookAccent(book))),
                    const Spacer(),
                    Text(
                      book.titleUrdu,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: kUrduFont,
                        height: 1.55,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      book.titleLatin,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'sans-serif', color: colors.onSurfaceVariant, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          installed ? 'ابواب دیکھیں' : 'ڈاؤن لوڈ درکار',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 5),
                        Icon(Icons.arrow_back_ios_new_rounded, color: colors.primary, size: 14),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The احادیث section: every hadith book as a card in a two-column grid.
class HadithBooksScreen extends StatelessWidget {
  const HadithBooksScreen({super.key, required this.library, this.onOpenData});

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  Widget build(BuildContext context) {
    final books = BookDefinition.hadithBooks;
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('احادیث')),
      body: ValueListenableBuilder<int>(
        valueListenable: library.catalogVersion,
        builder: (context, _, __) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          key: const PageStorageKey('hadith-grid'),
          itemCount: books.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.94,
          ),
          itemBuilder: (context, index) {
            final book = books[index];
            final installed = library.isInstalled(book);
            return _BookCard(
              book: book,
              installed: installed,
              onTap: () {
                if (!installed) {
                  onOpenData?.call();
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChapterListScreen(library: library, book: book),
                ));
              },
            );
          },
        ),
      ),
    );
  }
}

class ChapterListScreen extends StatefulWidget {
  const ChapterListScreen({super.key, required this.library, required this.book});

  final LibraryRepository library;
  final BookDefinition book;

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  Future<List<Map<String, Object?>>>? _chapters;

  @override
  void initState() {
    super.initState();
    _chapters = widget.library.getChapters(widget.book);
  }

  /// Called after the reader closes so this book's saved position is current.
  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final library = widget.library;
    return Scaffold(
      appBar: AppBar(title: JustifiedText(book.titleUrdu)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _chapters,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
          final chapters = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            // One extra slot on top: this book's own "جاری رکھیں" row, which
            // collapses to nothing until the book has been opened once.
            itemCount: chapters.length + 1,
            separatorBuilder: (_, index) => index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ResumeCard(library: library, book: book, onOpened: _refresh);
              }
              final row = chapters[index - 1];
              final cid = _toInt(row['cid']) ?? 0;
              final title = (row['title'] ?? '').toString();
              return ChapterWallpaperCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text('$index'),
                  ),
                  title: JustifiedText(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SectionListScreen(
                      library: library,
                      book: book,
                      chapterId: cid,
                      chapterTitle: title,
                    ),
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
  });

  final LibraryRepository library;
  final BookDefinition book;
  final int chapterId;
  final String chapterTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: JustifiedText(chapterTitle, maxLines: 1)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: library.getSections(book, chapterId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
          final sections = snapshot.data ?? [];
          if (sections.isEmpty) return const CollectionMessage('اس باب میں کوئی فصل موجود نہیں۔');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = sections[index];
              final secid = _toInt(row['Secid']);
              final title = (row['title'] ?? '').toString();
              return ChapterWallpaperCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  leading: const Icon(Icons.article_outlined),
                  title: JustifiedText(title, style: const TextStyle(fontSize: 16)),
                  subtitle: JustifiedText(
                    'فصل ${index + 1}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: secid == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ReaderScreen(
                              library: library,
                              book: book,
                              sectionId: secid,
                              sectionTitle: title,
                            ),
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

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.library,
    required this.book,
    this.recordId,
    this.sectionId,
    this.sectionTitle,
    this.searchQuery = '',
  });

  final LibraryRepository library;
  final BookDefinition book;
  final int? recordId;
  final int? sectionId;
  final String? sectionTitle;
  final String searchQuery;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();

  List<Passage> _passages = [];
  int _initialIndex = 0;

  /// Every section (متن) of this book in reading order: (sectionId, title).
  List<(int, String)> _navSections = const [];
  bool _navBusy = false;

  int? get _currentSectionId =>
      widget.sectionId ?? (_passages.isNotEmpty ? _passages.first.sectionId : null);

  Future<void> _loadNavSections() async {
    try {
      final ordered = <(int, String)>[];
      final chapters = await widget.library.getChapters(widget.book);
      for (final chapter in chapters) {
        final cid = _toInt(chapter['cid']) ?? _toInt(chapter['ID']) ?? 0;
        final sections = await widget.library.getSections(widget.book, cid);
        for (final section in sections) {
          final secId = _toInt(section['Secid']) ?? _toInt(section['ID']);
          if (secId != null && !ordered.any((s) => s.$1 == secId)) {
            ordered.add((secId, (section['title'] ?? '').toString()));
          }
        }
      }
      if (mounted) setState(() => _navSections = ordered);
    } catch (_) {
      // Navigation is a convenience; reading must never fail because of it.
    }
  }

  int get _navIndex {
    final current = _currentSectionId;
    if (current == null) return -1;
    return _navSections.indexWhere((s) => s.$1 == current);
  }

  /// Opens the next/previous متن (section) — crossing chapter boundaries —
  /// replacing this reader so the back button still returns to the lists.
  void _openAdjacentSection(int delta) {
    final index = _navIndex;
    if (_navBusy || index < 0) return;
    final targetIndex = index + delta;
    if (targetIndex < 0 || targetIndex >= _navSections.length) return;
    _navBusy = true;
    final (secId, title) = _navSections[targetIndex];
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(
        library: widget.library,
        book: widget.book,
        sectionId: secId,
        sectionTitle: title.isEmpty ? widget.book.titleUrdu : title,
      ),
    ));
  }

  bool _loading = true;
  String? _error;
  ReaderPreferences _preferences = const ReaderPreferences();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadNavSections());
  }


  Future<void> _load() async {
    try {
      final preferences = await ReaderPreferences.load();
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
          _preferences = preferences;
          _passages = passages;
          _initialIndex = index;
          _loading = false;
        });
        if (passages.isNotEmpty) {
          final current = passages[index.clamp(0, passages.length - 1)];
          unawaited(widget.library.saveLastRead(
            bookKey: widget.book.key,
            recordId: current.recordId,
            sectionId: current.sectionId,
            title: current.sectionTitle,
            reference: readingReference(widget.book, current),
          ));
        }
        if (widget.recordId != null && passages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_itemScrollController.isAttached) {
              _itemScrollController.jumpTo(index: index, alignment: 0.04);
            }
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _preferences.palette;
    return ReaderScaffold(
      book: widget.book,
      title: widget.sectionTitle ?? widget.book.titleUrdu,
      preferences: _preferences,
      onPreferencesChanged: (value) => setState(() => _preferences = value),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorPanel(error: _error!)
              : _passages.isEmpty
                  ? const CollectionMessage('اس حصے میں متن موجود نہیں۔')
                  : SelectionArea(
                      child: ScrollablePositionedList.builder(
                      key: PageStorageKey('reader-${widget.book.key}-${widget.sectionId ?? widget.recordId}'),
                      itemScrollController: _itemScrollController,
                      initialScrollIndex: _initialIndex,
                      itemCount: _passages.length + 1,
                      // Long chapters kept every card alive, which grew the
                      // element tree until the GC ran mid-scroll.
                      addAutomaticKeepAlives: false,
                      minCacheExtent: 350,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 112),
                      itemBuilder: (context, index) {
                        if (index >= _passages.length) {
                          final navIndex = _navIndex;
                          final hasSectionNav = navIndex >= 0 && _navSections.length > 1;
                          if (!hasSectionNav) return const SizedBox.shrink();
                          // Passage-by-passage buttons were removed from the
                          // end of the reader. Keep only the useful jump to a
                          // different text/chapter when one exists.
                          return ReaderPrevNextBar(
                            key: const ValueKey<String>('reader-section-prev-next'),
                            hasPrevious: navIndex > 0,
                            hasNext: navIndex < _navSections.length - 1,
                            onPrevious: () => _openAdjacentSection(-1),
                            onNext: () => _openAdjacentSection(1),
                            previousLabel: 'پچھلا متن',
                            nextLabel: 'اگلا متن',
                            label: 'متن ${navIndex + 1} از ${_navSections.length}',
                          );
                        }
                        return PassageCard(
                        key: ValueKey('${widget.book.key}-${_passages[index].recordId}'),
                        library: widget.library,
                        book: widget.book,
                        passage: _passages[index],
                        palette: palette,
                        fontScale: _preferences.fontScale,
                        script: widget.searchQuery.isEmpty ? _preferences.script : 'both',
                        searchQuery: widget.searchQuery,
                        focusMatch: _passages[index].recordId == widget.recordId,
                        // Numbered within this section (۱، ۲، ۳…) — not the
                        // database row id, which reached 562276 and was
                        // mistaken for a hadith count that does not exist.
                        indexLabel: widget.book.source == CorpusSource.hadith
                            ? 'حدیث ${arabicNumerals(index + 1)}'
                            : null,
                        );
                      },
                      ),
                    ),
    );
  }
}

/// Bookmarks and notes for every collection, behind one tabbed screen.
class SavedItemsScreen extends StatelessWidget {
  const SavedItemsScreen({super.key, required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const JustifiedText('محفوظات'),
          bottom: const TabBar(tabs: [Tab(text: 'محفوظ عنوانات'), Tab(text: 'نوٹس')]),
        ),
        body: TabBarView(
          children: [
            BookmarksScreen(library: library),
            NotesScreen(library: library),
          ],
        ),
      ),
    );
  }
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key, required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<(BookDefinition, Passage, String)>>(
      future: library.getNotes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const CollectionMessage('ابھی کوئی نوٹ محفوظ نہیں۔', icon: Icons.edit_note);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final (book, passage, note) = items[index];
            return Card(
              child: ListTile(
                title: JustifiedText(
                  passage.sectionTitle.isNotEmpty ? passage.sectionTitle : book.titleUrdu,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  maxLines: 1,
                ),
                subtitle: JustifiedText(note, maxLines: 3),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => pushReaderFor(
                  context,
                  library: library,
                  book: book,
                  passage: passage,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key, required this.library});

  final LibraryRepository library;

  Future<List<(BookDefinition, Passage)>> _load() async {
    final targets = await library.getBookmarks();
    final output = <(BookDefinition, Passage)>[];
    for (final target in targets) {
      final book = BookDefinition.byKey(target.book);
      if (book == null || !library.isInstalled(book)) continue;
      try {
        final passage = await library.getPassageById(book, target.recordId);
        if (passage != null) output.add((book, passage));
      } catch (_) {
        continue;
      }
    }
    return output;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<(BookDefinition, Passage)>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const CollectionMessage('ابھی کچھ محفوظ نہیں کیا گیا۔', icon: Icons.bookmark_border);
        }
        // Step 1: a GRID of just those books that actually have bookmarks.
        final grouped = <String, List<(BookDefinition, Passage)>>{};
        for (final item in items) {
          grouped.putIfAbsent(item.$1.key, () => []).add(item);
        }
        final books = grouped.values.map((list) => list.first.$1).toList();
        return GridView.builder(
          key: const ValueKey<String>('bookmarks-book-grid'),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            final bookItems = grouped[book.key]!;
            final accent = bookAccent(book);
            return Card(
              key: ValueKey<String>('bookmarks-grid-${book.key}'),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => _BookBookmarksScreen(library: library, book: book, items: bookItems),
                )),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [accent.withValues(alpha: 0.24), accent.withValues(alpha: 0.07)],
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: JustifiedText(book.titleUrdu,
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold), maxLines: 3),
                      ),
                      Row(children: [
                        Icon(Icons.bookmark_rounded, size: 16, color: accent),
                        const SizedBox(width: 4),
                        Text('${bookItems.length} محفوظ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                        const Spacer(),
                        const Icon(Icons.chevron_left, size: 18),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Step 2: ONE book's bookmarks, as a simple list. Reached by tapping that
/// book's card in the bookmarks grid.
class _BookBookmarksScreen extends StatelessWidget {
  const _BookBookmarksScreen({required this.library, required this.book, required this.items});

  final LibraryRepository library;
  final BookDefinition book;
  final List<(BookDefinition, Passage)> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: JustifiedText(book.titleUrdu, maxLines: 1)),
      body: ListView.separated(
        key: ValueKey<String>('bookmarks-list-${book.key}'),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final (itemBook, passage) = items[index];
          final preview = passage.urdu.isNotEmpty
              ? passage.urdu
              : (passage.arabic.isNotEmpty ? passage.arabic : passage.commentary);
          return Card(
            child: ListTile(
              title: JustifiedText(
                passage.sectionTitle.isNotEmpty ? passage.sectionTitle : itemBook.titleUrdu,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                maxLines: 1,
              ),
              subtitle: JustifiedText(preview, maxLines: 2),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => pushReaderFor(context, library: library, book: itemBook, passage: passage),
            ),
          );
        },
      ),
    );
  }
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
