import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../text_utils.dart' show arabicNumerals;
import '../widgets/reader_kit.dart';

/// Surah / juz / page browser for the Quran collection.
class QuranHomeScreen extends StatefulWidget {
  const QuranHomeScreen({super.key, required this.library});

  final LibraryRepository library;

  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen> {
  final TextEditingController _jumpController = TextEditingController();

  @override
  void dispose() {
    _jumpController.dispose();
    super.dispose();
  }

  Future<void> _openPage() async {
    final page = int.tryParse(_jumpController.text.trim());
    if (page == null || page < 1 || page > 604) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صفحہ نمبر ۱ سے ۶۰۴ کے درمیان لکھیں۔')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuranPageReaderScreen(library: widget.library, page: page),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const JustifiedText('قرآنِ کریم'),
          bottom: const TabBar(
            tabs: [Tab(text: 'سورتیں'), Tab(text: 'پارے')],
          ),
          actions: [
            IconButton(
              tooltip: 'صفحہ پر جائیں',
              onPressed: _openPage,
              icon: const Icon(Icons.menu_book_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _jumpController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                onSubmitted: (_) => _openPage(),
                decoration: const InputDecoration(
                  hintText: 'صفحہ نمبر لکھیں (۱ تا ۶۰۴)',
                  prefixIcon: Icon(Icons.photo_size_select_small),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SurahList(library: widget.library),
                  _JuzList(library: widget.library),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList({required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuranSurah>>(
      future: library.getSurahs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
        final surahs = snapshot.data ?? const [];
        if (surahs.isEmpty) {
          return const CollectionMessage('سورتیں دستیاب نہیں۔', icon: Icons.menu_book);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: surahs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final surah = surahs[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(arabicNumerals(surah.number), textDirection: TextDirection.rtl),
                ),
                title: JustifiedText(
                  surah.nameUrdu.isEmpty ? surah.nameArabic : surah.nameUrdu,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  maxLines: 1,
                ),
                subtitle: JustifiedText(
                  '${surah.nameArabic} • ${surah.verseCount} آیات • ${surah.revelationPlace}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 1,
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SurahReaderScreen(library: library, surah: surah),
                )),
              ),
            );
          },
        );
      },
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuranJuzEntry>>(
      future: library.getJuzIndex(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
        final entries = snapshot.data ?? const [];
        if (entries.isEmpty) {
          return const CollectionMessage('پارے دستیاب نہیں۔', icon: Icons.layers_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: JustifiedText(entry.title, maxLines: 1),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => JuzReaderScreen(library: library, juz: entry.juz),
                )),
              ),
            );
          },
        );
      },
    );
  }
}

/// Verse reader used for a surah, a juz, or a single mushaf page.
class SurahReaderScreen extends StatefulWidget {
  const SurahReaderScreen({
    super.key,
    required this.library,
    required this.surah,
    this.initialRecordId,
  });

  final LibraryRepository library;
  final QuranSurah surah;
  final int? initialRecordId;

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  @override
  Widget build(BuildContext context) {
    return _QuranVerseList(
      library: widget.library,
      title: widget.surah.displayTitle,
      subtitle: '${widget.surah.verseCount} آیات • ${widget.surah.revelationPlace}',
      loader: () => widget.library.getSurahVerses(widget.surah.number),
      bismillah: widget.surah.number > 1,
      initialRecordId: widget.initialRecordId,
      storageKey: 'quran-surah-${widget.surah.number}',
    );
  }
}

class JuzReaderScreen extends StatelessWidget {
  const JuzReaderScreen({super.key, required this.library, required this.juz});

  final LibraryRepository library;
  final int juz;

  @override
  Widget build(BuildContext context) {
    return _QuranVerseList(
      library: library,
      title: 'پارہ $juz',
      subtitle: 'مکمل پارہ',
      loader: () => library.getJuzVerses(juz),
      storageKey: 'quran-juz-$juz',
    );
  }
}

class QuranPageReaderScreen extends StatelessWidget {
  const QuranPageReaderScreen({super.key, required this.library, required this.page});

  final LibraryRepository library;
  final int page;

  @override
  Widget build(BuildContext context) {
    return _QuranVerseList(
      library: library,
      title: 'صفحہ $page',
      subtitle: 'مصحف کا صفحہ',
      loader: () => library.getQuranPage(page),
      storageKey: 'quran-page-$page',
    );
  }
}

class _QuranVerseList extends StatefulWidget {
  const _QuranVerseList({
    required this.library,
    required this.title,
    required this.subtitle,
    required this.loader,
    required this.storageKey,
    this.bismillah = false,
    this.initialRecordId,
  });

  final LibraryRepository library;
  final String title;
  final String subtitle;
  final Future<List<Passage>> Function() loader;
  final String storageKey;
  final bool bismillah;
  final int? initialRecordId;

  @override
  State<_QuranVerseList> createState() => _QuranVerseListState();
}

class _QuranVerseListState extends State<_QuranVerseList> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener = ItemPositionsListener.create();
  final BookDefinition _book = BookDefinition.bookFor(CorpusSource.quran)!;

  List<Passage> _verses = const [];
  ReaderPreferences _preferences = const ReaderPreferences();
  bool _loading = true;
  String? _error;
  int _initialIndex = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _positionsListener.itemPositions.addListener(_track);
    unawaited(_load());
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_track);
    super.dispose();
  }

  void _track() {
    final visible = _positionsListener.itemPositions.value
        .where((position) => position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1)
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    if (visible.isNotEmpty) _currentIndex = visible.first.index;
  }

  Future<void> _load() async {
    try {
      final preferences = await ReaderPreferences.load();
      final verses = await widget.loader();
      var index = 0;
      final target = widget.initialRecordId;
      if (target != null) {
        final found = verses.indexWhere((verse) => verse.recordId == target);
        if (found >= 0) index = found;
      }
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _verses = verses;
        _initialIndex = index;
        _currentIndex = index;
        _loading = false;
      });
      if (_verses.isNotEmpty && index > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.isAttached) {
            _scrollController.jumpTo(index: index, alignment: 0.04);
          }
        });
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

  void _saveLastRead() {
    if (_verses.isEmpty) return;
    final index = _currentIndex.clamp(0, _verses.length - 1);
    unawaited(widget.library.saveLastRead(
      bookKey: _book.key,
      recordId: _verses[index].recordId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = _preferences.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JustifiedText(widget.title, style: TextStyle(color: palette.foreground), maxLines: 1),
            Text(
              widget.subtitle,
              style: TextStyle(color: palette.foreground.withValues(alpha: 0.6), fontSize: 11),
              textDirection: TextDirection.rtl,
            ),
          ],
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
              : _verses.isEmpty
                  ? const CollectionMessage('اس حصے میں متن موجود نہیں۔')
                  : NotificationListener<ScrollEndNotification>(
                      onNotification: (_) {
                        _saveLastRead();
                        return false;
                      },
                      child: ScrollablePositionedList.builder(
                        key: PageStorageKey(widget.storageKey),
                        itemScrollController: _scrollController,
                        itemPositionsListener: _positionsListener,
                        initialScrollIndex: _initialIndex,
                        itemCount: _verses.length + (widget.bismillah ? 1 : 0),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                        itemBuilder: (context, index) {
                          if (widget.bismillah && index == 0) {
                            return _Bismillah(scale: _preferences.fontScale);
                          }
                          final verse = _verses[index - (widget.bismillah ? 1 : 0)];
                          return PassageCard(
                            key: ValueKey('quran-${verse.recordId}'),
                            library: widget.library,
                            book: _book,
                            passage: verse,
                            palette: palette,
                            fontScale: _preferences.fontScale,
                            script: _preferences.script,
                            indexLabel: 'آیت ${arabicNumerals(_verseNumber(verse))}',
                          );
                        },
                      ),
                    ),
    );
  }

  int _verseNumber(Passage verse) {
    final match = RegExp(r'آیت (\d+)').firstMatch(verse.locator);
    return match == null ? verse.recordId : int.tryParse(match.group(1) ?? '') ?? verse.recordId;
  }
}

class _Bismillah extends StatelessWidget {
  const _Bismillah({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: kArabicFont,
          fontSize: 26 * scale,
          height: 1.8,
          color: kForest,
        ),
      ),
    );
  }
}
