import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../reader_navigation.dart';
import '../widgets/reader_kit.dart';
import 'balagha_screen.dart';
import 'duas_screen.dart';
import 'quran_screen.dart';

class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key, required this.library, this.onOpenData});

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  ReaderTarget? _lastRead;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastRead());
  }

  Future<void> _loadLastRead() async {
    final last = await widget.library.getLastRead();
    if (mounted) setState(() => _lastRead = last);
  }

  Future<void> _openTarget(ReaderTarget target) async {
    final book = BookDefinition.byKey(target.book);
    if (book == null || !mounted) return;
    await pushReaderFor(
      context,
      library: widget.library,
      book: book,
      recordId: target.recordId,
      sectionId: target.sectionId,
    );
    await _loadLastRead();
  }

  @override
  Widget build(BuildContext context) {
    final lastBook = BookDefinition.byKey(_lastRead?.book);
    final showLastRead = lastBook != null &&
        _lastRead != null &&
        widget.library.isInstalled(lastBook);
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          _LibraryBanner(
            onOpenSaved: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SavedItemsScreen(library: widget.library),
            )),
          ),
          if (showLastRead) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history, color: kForest),
                title: const JustifiedText('آخری مطالعہ جاری رکھیں'),
                subtitle: JustifiedText(lastBook.titleUrdu, maxLines: 1),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _openTarget(_lastRead!),
              ),
            ),
          ],
          const SizedBox(height: 22),
          const _SectionHeader('قرآن، دعائیں اور نہج البلاغہ'),
          const SizedBox(height: 10),
          _CollectionsRow(library: widget.library, onOpenData: widget.onOpenData),
          const SizedBox(height: 22),
          const _SectionHeader('کتبِ احادیث'),
          const SizedBox(height: 10),
          GridView.builder(
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

class _CollectionsRow extends StatelessWidget {
  const _CollectionsRow({required this.library, this.onOpenData});

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  Widget build(BuildContext context) {
    final collections = <({BookDefinition book, IconData icon, Color color})>[
      (book: BookDefinition.bookFor(CorpusSource.quran)!, icon: Icons.menu_book, color: kForest),
      (book: BookDefinition.bookFor(CorpusSource.dua)!, icon: Icons.mosque, color: kGold),
      (
        book: BookDefinition.bookFor(CorpusSource.balagha)!,
        icon: Icons.auto_stories,
        color: const Color(0xFF7A4E2D),
      ),
    ];
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final entry = collections[index];
          final installed = library.isInstalled(entry.book);
          return SizedBox(
            width: 190,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  if (!installed) {
                    onOpenData?.call();
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => switch (entry.book.source) {
                      CorpusSource.quran => QuranHomeScreen(library: library),
                      CorpusSource.dua => DuasHomeScreen(library: library),
                      CorpusSource.balagha => BalaghaHomeScreen(library: library),
                      CorpusSource.hadith =>
                        ChapterListScreen(library: library, book: entry.book),
                    },
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(entry.icon, color: entry.color, size: 22),
                          const Spacer(),
                          if (!installed)
                            Icon(Icons.download, size: 16, color: Theme.of(context).colorScheme.error),
                        ],
                      ),
                      const Spacer(),
                      JustifiedText(
                        entry.book.titleUrdu,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      JustifiedText(
                        installed
                            ? entry.book.description
                            : 'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
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

class ChapterListScreen extends StatelessWidget {
  const ChapterListScreen({super.key, required this.library, required this.book});

  final LibraryRepository library;
  final BookDefinition book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: JustifiedText(book.titleUrdu)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: library.getChapters(book),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
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
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text('${index + 1}'),
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
  });

  final LibraryRepository library;
  final BookDefinition book;
  final int? recordId;
  final int? sectionId;
  final String? sectionTitle;

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
                  : ScrollablePositionedList.builder(
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
                        script: _preferences.script,
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
