import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../reader_navigation.dart';
import '../text_utils.dart' show arabicNumerals;
import '../widgets/home_utilities.dart';
import '../widgets/reader_kit.dart';
import '../widgets/resume_card.dart';
import 'balagha_screen.dart';
import 'dua_collection_screen.dart';
import 'fatawa_screen.dart';
import 'quran_screen.dart';

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
    // freshly installed book appears without pulling to refresh.
    return ValueListenableBuilder<int>(
      valueListenable: widget.library.catalogVersion,
      builder: (context, _, __) => _buildHome(context),
    );
  }

  Widget _buildHome(BuildContext context) {
    // No top bar. Home, search, bookmarks, more features and settings live in
    // the bottom panel; the page is the prayer card, the tasbeeh and the five
    // sections in order.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            // The prayer card leads: place, Hijri date, the live clock and the
            // five times, over a sky that follows the time of day.
            const HomePrayerBanner(),
            const SizedBox(height: 12),
            _DownloadPrompt(library: widget.library, onOpenData: widget.onOpenData),
            // The circular mini tasbeeh, at a fixed height.
            const HomeUtilityRow(),
            _IndexingBanner(library: widget.library),
            const SizedBox(height: 14),
            ..._homeSections(context),
          ],
        ),
      ),
    );
  }

  /// The five home sections, in reading order: قرآن، احادیث، دعائیں،
  /// نہج البلاغہ، دینی مسائل. Each is one full-width card.
  List<Widget> _homeSections(BuildContext context) {
    final library = widget.library;
    final onOpenData = widget.onOpenData;
    final quran = BookDefinition.bookFor(CorpusSource.quran)!;
    final nahj = BookDefinition.bookFor(CorpusSource.balagha)!;
    final quranReady = library.isInstalled(quran);
    final nahjReady = library.isInstalled(nahj);
    final hadithReady = BookDefinition.hadithBooks.any(library.isInstalled);
    final duaReady = duaCollectionBooks.any(library.isInstalled);
    final fatawaReady = fatawaBooks.any(library.isInstalled);

    void push(Widget page) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    }

    final cards = <Widget>[
      _HomeSectionCard(
        title: quran.titleUrdu,
        subtitle: quranReady ? quran.description : 'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
        icon: Icons.menu_book_rounded,
        color: bookAccent(quran),
        installed: quranReady,
        onTap: () {
          if (quranReady) {
            push(QuranHomeScreen(library: library));
          } else {
            onOpenData?.call();
          }
        },
      ),
      _HomeSectionCard(
        title: 'احادیث',
        subtitle: hadithReady
            ? 'کتبِ احادیث کا مجموعہ'
            : 'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
        icon: Icons.format_quote_rounded,
        color: const Color(0xFF2F6FD6),
        installed: hadithReady,
        onTap: () {
          if (hadithReady) {
            push(HadithBooksScreen(library: library, onOpenData: onOpenData));
          } else {
            onOpenData?.call();
          }
        },
      ),
      _HomeSectionCard(
        title: kDuaCollectionTitle,
        subtitle: duaReady ? kDuaCollectionSubtitle : 'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
        icon: Icons.mosque,
        color: const Color(0xFFB8860B),
        installed: duaReady,
        onTap: () => push(DuaCollectionScreen(library: library, onOpenData: onOpenData)),
      ),
      _HomeSectionCard(
        title: nahj.titleUrdu,
        subtitle: nahjReady ? nahj.description : 'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
        icon: Icons.auto_stories,
        color: const Color(0xFF6D4C41),
        installed: nahjReady,
        onTap: () {
          if (nahjReady) {
            push(BalaghaHomeScreen(library: library));
          } else {
            onOpenData?.call();
          }
        },
      ),
      _HomeSectionCard(
        title: kFatawaCollectionTitle,
        subtitle: fatawaReady ? kFatawaCollectionSubtitle : 'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
        icon: Icons.gavel_rounded,
        color: const Color(0xFF6B4E9B),
        installed: fatawaReady,
        onTap: () => push(FatawaCollectionScreen(library: library, onOpenData: onOpenData)),
      ),
    ];
    return <Widget>[
      for (final card in cards) ...<Widget>[card, const SizedBox(height: 12)],
    ];
  }
}

/// One home section: a full-width card with its icon, title and one line.
class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.installed,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool installed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              _IconBadge(icon: icon, color: color, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    JustifiedText(
                      title,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    JustifiedText(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              installed
                  ? const Icon(Icons.chevron_left)
                  : Icon(Icons.download_rounded, color: Theme.of(context).colorScheme.error),
            ],
          ),
        ),
      ),
    );
  }
}

/// The download nudge at the top of the home screen.
///
/// A fresh install has no corpus: instead of blocking the library behind a
/// splash screen, the home screen opens immediately and asks for the download
/// here (and with the download icon in the app bar).
class _DownloadPrompt extends StatelessWidget {
  const _DownloadPrompt({required this.library, this.onOpenData});

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  Widget build(BuildContext context) {
    final total = BookDefinition.all.length;
    final installed = library.installedBooks.length;
    final missing = total - installed;
    final scheme = Theme.of(context).colorScheme;
    if (missing <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _downloadCard(context, installed, total, missing, scheme),
    );
  }

  Widget _downloadCard(BuildContext context, int installed, int total, int missing, ColorScheme scheme) {
    return Card(
      color: kGold.withValues(alpha: 0.16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.download_rounded, color: kForest, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: JustifiedText(
                    installed == 0 ? 'ڈیٹا ڈاؤن لوڈ کریں' : '$missing کتب ابھی باقی ہیں',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            JustifiedText(
              installed == 0
                  ? 'کتب کا ڈیٹا ابھی ڈاؤن لوڈ نہیں ہوا۔ نیچے کے بار میں ڈاؤن لوڈ کے بٹن پر ٹیپ کریں، '
                    'یا نیچے دیے گئے بٹن کو دبائیں، اور پھر اپنی پسند کی کتب منتخب کریں۔'
                  : '$installed / $total کتب موجود ہیں۔ باقی $missing کتب کے لیے نیچے کے بار میں '
                    'ڈاؤن لوڈ کے بٹن پر ٹیپ کریں۔',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenData,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('ڈاؤن لوڈ کریں'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress of the background search-index build.
///
/// The index used to block the first screen; now the library opens straight
/// away and this strip only appears while the index is still catching up.
class _IndexingBanner extends StatelessWidget {
  const _IndexingBanner({required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IndexBuildState>(
      valueListenable: library.indexProgress,
      builder: (context, state, _) {
        if (!state.active) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  JustifiedText(state.message, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: state.progress <= 0 ? null : state.progress),
                  const SizedBox(height: 6),
                  Text(
                    'کتب پڑھی جا سکتی ہیں؛ تلاش کی فہرست تیار ہو رہی ہے۔',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A coloured rounded tile with a white icon: the colour of a book or collection.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 42});

  final IconData icon;
  final Color color;
  final double size;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _IconBadge(icon: Icons.menu_book_rounded, color: bookAccent(book)),
                    const Spacer(),
                    if (!installed) Icon(Icons.download, size: 16, color: colors.error),
                  ],
                ),
                const Spacer(),
                JustifiedText(
                  book.titleUrdu,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  maxLines: 3,
                ),
                const SizedBox(height: 7),
                Text(
                  book.titleLatin,
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'sans-serif', color: colors.onSurfaceVariant, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        installed ? 'ابواب دیکھیں' : 'ڈاؤن لوڈ درکار',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Icon(Icons.arrow_back_ios_new_rounded, color: colors.primary, size: 16),
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
              return Card(
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
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = sections[index];
              final secid = _toInt(row['Secid']);
              final title = (row['title'] ?? '').toString();
              return ListTile(
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
  bool _loading = true;
  String? _error;
  ReaderPreferences _preferences = const ReaderPreferences();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        title: JustifiedText(
          widget.sectionTitle ?? widget.book.titleUrdu,
          style: TextStyle(color: palette.foreground),
          maxLines: 1,
        ),
        actions: [
          ReaderControls(
            preferences: _preferences,
            onChanged: (value) => setState(() => _preferences = value),
          ),
        ],
      ),
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
                      itemCount: _passages.length,
                      // Long chapters kept every card alive, which grew the
                      // element tree until the GC ran mid-scroll.
                      addAutomaticKeepAlives: false,
                      minCacheExtent: 350,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemBuilder: (context, index) => PassageCard(
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
                      ),
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
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final (book, passage) = items[index];
            final preview = passage.urdu.isNotEmpty
                ? passage.urdu
                : (passage.arabic.isNotEmpty ? passage.arabic : passage.commentary);
            return Card(
              child: ListTile(
                title: JustifiedText(
                  passage.sectionTitle.isNotEmpty ? passage.sectionTitle : book.titleUrdu,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  maxLines: 1,
                ),
                subtitle: JustifiedText(preview, maxLines: 2),
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

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
