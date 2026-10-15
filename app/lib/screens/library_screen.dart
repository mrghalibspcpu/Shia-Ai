import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../reader_navigation.dart';
import '../text_utils.dart' show arabicNumerals;
import '../widgets/reader_kit.dart';
import '../widgets/resume_card.dart';
import 'balagha_screen.dart';
import 'duas_screen.dart';
import 'fatawa_screen.dart';
import 'quran_screen.dart';

class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key, required this.library, this.onOpenData});

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  LastReadEntry? _lastRead;
  Future<List<LastReadEntry>>? _perBookFuture;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastRead());
  }

  Future<void> _loadLastRead() async {
    final last = await widget.library.getLastRead();
    if (mounted) {
      setState(() {
        _lastRead = last;
        _perBookFuture = widget.library.getLastReads();
      });
    }
  }

  Future<void> _openLast(LastReadEntry entry) async {
    await openLastRead(context, widget.library, entry);
    await _loadLastRead();
  }

  @override
  Widget build(BuildContext context) {
    final lastBook = _lastRead?.book;
    final showLastRead =
        lastBook != null && _lastRead != null && widget.library.isInstalled(lastBook);
    return Scaffold(
      appBar: AppBar(
        title: const JustifiedText('شیعہ لائبریری'),
        actions: [
          if (widget.onOpenData != null)
            IconButton(
              tooltip: 'ڈیٹا اور ڈاؤن لوڈ',
              onPressed: widget.onOpenData,
              icon: const Icon(Icons.download_outlined),
            ),
          IconButton(
            tooltip: 'محفوظات',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SavedItemsScreen(library: widget.library),
            )),
            icon: const Icon(Icons.bookmark_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLastRead,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            _DownloadPrompt(library: widget.library, onOpenData: widget.onOpenData),
            _IndexingBanner(library: widget.library),
            const SizedBox(height: 12),
            _LibraryBanner(
              onOpenSaved: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SavedItemsScreen(library: widget.library),
              )),
            ),
            if (showLastRead) ...[
              const SizedBox(height: 14),
              LastReadTile(
                library: widget.library,
                entry: _lastRead!,
                margin: EdgeInsets.zero,
                title: 'آخری مطالعہ جاری رکھیں',
                onOpened: _loadLastRead,
              ),
            ],
            _PerBookLastRead(
              future: _perBookFuture,
              library: widget.library,
              onOpened: _loadLastRead,
            ),
            const SizedBox(height: 22),
            const _SectionHeader('قرآن، دعائیں، فتاویٰ اور نہج البلاغہ'),
            const SizedBox(height: 10),
            _CollectionsRow(library: widget.library, onOpenData: widget.onOpenData),
            const SizedBox(height: 22),
            const _SectionHeader('کتبِ احادیث'),
            const SizedBox(height: 10),
            GridView.builder(
              key: const PageStorageKey('hadith-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: BookDefinition.hadithBooks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.94,
              ),
              itemBuilder: (context, index) {
                final book = BookDefinition.hadithBooks[index];
                final installed = widget.library.isInstalled(book);
                return _BookCard(
                  book: book,
                  installed: installed,
                  onTap: () {
                    if (!installed) {
                      widget.onOpenData?.call();
                      return;
                    }
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChapterListScreen(library: widget.library, book: book),
                    ));
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => JustifiedText(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      );
}

/// One card in the home row: either a single collection or the combined
/// دینی مسائل tile that opens the marja picker.
class _CollectionEntry {
  const _CollectionEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.installed,
    this.book,
    this.combined = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool installed;
  final BookDefinition? book;

  /// True for the shared fatawa tile (two marjas behind one card).
  final bool combined;
}

class _CollectionsRow extends StatelessWidget {
  const _CollectionsRow({required this.library, this.onOpenData});

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  List<_CollectionEntry> _entries() {
    final fatawa = fatawaBooks;
    final ready = fatawa.where(library.isInstalled).length;
    return <_CollectionEntry>[
      _CollectionEntry(
        title: kFatawaCollectionTitle,
        subtitle: ready == 0
            ? 'فتاویٰ — ابھی نصب نہیں، ڈاؤن لوڈ کریں'
            : kFatawaCollectionSubtitle,
        icon: Icons.gavel_rounded,
        color: const Color(0xFF6B4E9B),
        installed: ready > 0,
        combined: true,
      ),
      for (final book in featuredCollections)
        _CollectionEntry(
          title: book.titleUrdu,
          subtitle: library.isInstalled(book) ? book.description : 'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
          icon: switch (book.source) {
            CorpusSource.quran => Icons.menu_book,
            CorpusSource.dua => Icons.mosque,
            CorpusSource.balagha => Icons.auto_stories,
            _ => Icons.auto_stories,
          },
          color: switch (book.source) {
            CorpusSource.dua => kGold,
            CorpusSource.balagha => const Color(0xFF7A4E2D),
            _ => kForest,
          },
          installed: library.isInstalled(book),
          book: book,
        ),
    ];
  }

  void _open(BuildContext context, _CollectionEntry entry) {
    if (entry.combined) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FatawaCollectionScreen(library: library, onOpenData: onOpenData),
      ));
      return;
    }
    final book = entry.book;
    if (book == null) return;
    if (!library.isInstalled(book)) {
      onOpenData?.call();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => switch (book.source) {
        CorpusSource.quran => QuranHomeScreen(library: library),
        CorpusSource.dua => DuasHomeScreen(library: library),
        CorpusSource.balagha => BalaghaHomeScreen(library: library),
        CorpusSource.sahifa || CorpusSource.fatwa || CorpusSource.hadith =>
          ChapterListScreen(library: library, book: book),
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final collections = _entries();
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final entry = collections[index];
          return SizedBox(
            width: 190,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _open(context, entry),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(entry.icon, color: entry.color, size: 22),
                          const Spacer(),
                          if (!entry.installed)
                            Icon(Icons.download, size: 16, color: Theme.of(context).colorScheme.error),
                        ],
                      ),
                      const Spacer(),
                      JustifiedText(
                        entry.title,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      JustifiedText(
                        entry.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
                  ? 'کتب کا ڈیٹا ابھی ڈاؤن لوڈ نہیں ہوا۔ اوپر ڈاؤن لوڈ (⬇) کے نشان پر ٹیپ کریں، '
                    'یا نیچے دیے گئے بٹن کو دبائیں، اور پھر اپنی پسند کی کتب منتخب کریں۔'
                  : '$installed / $total کتب موجود ہیں۔ باقی $missing کتب کے لیے اوپر ڈاؤن لوڈ (⬇) کے نشان '
                    'یا نیچے دیے گئے بٹن پر ٹیپ کریں۔',
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

/// Every book's own last position, most recently read first.
class _PerBookLastRead extends StatelessWidget {
  const _PerBookLastRead({required this.future, required this.library, this.onOpened});

  final Future<List<LastReadEntry>>? future;
  final LibraryRepository library;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    final pending = future;
    if (pending == null) return const SizedBox.shrink();
    return FutureBuilder<List<LastReadEntry>>(
      future: pending,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <LastReadEntry>[];
        final readable = entries
            .where((entry) => entry.book != null && library.isInstalled(entry.book!))
            .toList();
        if (readable.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            const _SectionHeader('ہر کتاب کا آخری مقام'),
            const SizedBox(height: 10),
            for (final entry in readable)
              LastReadTile(
                library: library,
                entry: entry,
                title: entry.book!.titleUrdu,
                showBookName: false,
                onOpened: onOpened,
              ),
          ],
        );
      },
    );
  }
}

class _LibraryBanner extends StatelessWidget {
  const _LibraryBanner({required this.onOpenSaved});

  final VoidCallback onOpenSaved;

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
        boxShadow: [
          BoxShadow(color: kForest.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'شیعہ لائبریری',
                  style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'قرآن، دعائیں، نہج البلاغہ اور چودہ کتبِ احادیث',
                  style: TextStyle(color: Color(0xFFE4D7B9), fontSize: 14),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x88FFFFFF)),
                  ),
                  onPressed: onOpenSaved,
                  icon: const Icon(Icons.bookmark_border, size: 18),
                  label: const Text('محفوظات اور نوٹس'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/images/tasneemlogo.png', fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}

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
                    Icon(Icons.menu_book_rounded, color: colors.primary, size: 22),
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
