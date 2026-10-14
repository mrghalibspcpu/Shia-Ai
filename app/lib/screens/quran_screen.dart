import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../text_utils.dart' show arabicNumerals, parseReaderNumber;
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
    final page = parseReaderNumber(_jumpController.text);
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
            IconButton(tooltip: 'سورہ / آیت پر جائیں', icon: const Icon(Icons.my_location),
              onPressed: () => showQuranJump(context, widget.library)),
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
    this.searchQuery = '',
  });

  final LibraryRepository library;
  final QuranSurah surah;
  final int? initialRecordId;
  final String searchQuery;

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  @override
  Widget build(BuildContext context) {
    return _QuranVerseList(
      library: widget.library,
      title: widget.surah.displayTitle,
      subtitle: widget.surah.verseCount > 0
          ? '${widget.surah.verseCount} آیات • ${widget.surah.revelationPlace}' : 'قرآنِ کریم',
      loader: () => widget.library.getSurahVerses(widget.surah.number),
      bismillah: widget.surah.number > 1 && widget.surah.number != 9,
      initialRecordId: widget.initialRecordId,
      searchQuery: widget.searchQuery,
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
    this.searchQuery = '',
  });

  final LibraryRepository library;
  final String title;
  final String subtitle;
  final Future<List<Passage>> Function() loader;
  final String storageKey;
  final bool bismillah;
  final int? initialRecordId;
  final String searchQuery;

  @override
  State<_QuranVerseList> createState() => _QuranVerseListState();
}

class _QuranVerseListState extends State<_QuranVerseList> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();
  int _initialIndex = 0;
  int? _lastSavedRecord;

  final BookDefinition _book = BookDefinition.bookFor(CorpusSource.quran)!;

  List<Passage> _verses = const [];
  ReaderPreferences _preferences = const ReaderPreferences();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final preferences = await ReaderPreferences.load();
      final verses = await widget.loader();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _verses = verses;
        final index = verses.indexWhere((v) => v.recordId == widget.initialRecordId);
        _initialIndex = (index < 0 ? 0 : index) + (widget.bismillah ? 1 : 0);
        _loading = false;
      });
      final target = widget.initialRecordId;
      if (verses.isNotEmpty) {
        final opened = target != null && verses.any((verse) => verse.recordId == target)
            ? target
            : verses.first.recordId;
        unawaited(widget.library.saveLastRead(bookKey: _book.key, recordId: opened));
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

  /// O(visible items), not a scan/layout of hundreds of offscreen verses.
  void _saveLastRead() {
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList()..sort((a, b) => a.index.compareTo(b.index));
    if (visible.isEmpty) return;
    final index = visible.first.index - (widget.bismillah ? 1 : 0);
    if (index < 0 || index >= _verses.length) return;
    final record = _verses[index].recordId;
    if (record == _lastSavedRecord) return;
    _lastSavedRecord = record;
    unawaited(widget.library.saveLastRead(bookKey: _book.key, recordId: record));
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
          IconButton(tooltip: 'سورہ / آیت پر جائیں', icon: const Icon(Icons.my_location),
            onPressed: () => showQuranJump(context, widget.library)),
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
                      child: SelectionArea(
                        child: ScrollablePositionedList.builder(
                          key: PageStorageKey(widget.storageKey),
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _positions,
                          initialScrollIndex: _initialIndex,
                          initialAlignment: 0.04,
                          minCacheExtent: 400,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 60),
                          itemCount: _verses.length + (widget.bismillah ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (widget.bismillah && index == 0) return _Bismillah(scale: _preferences.fontScale);
                            final verse = _verses[index - (widget.bismillah ? 1 : 0)];
                            return PassageCard(
                              key: ValueKey('quran-${verse.recordId}'),
                              library: widget.library, book: _book, passage: verse,
                              palette: palette, fontScale: _preferences.fontScale,
                              script: widget.searchQuery.isEmpty ? _preferences.script : 'both',
                              searchQuery: widget.searchQuery,
                              focusMatch: verse.recordId == widget.initialRecordId,
                              indexLabel: 'آیت ${arabicNumerals(_verseNumber(verse))}',
                            );
                          },
                        ),
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

/// Available from the Quran index and every surah/juz/page reader.
Future<void> showQuranJump(BuildContext context, LibraryRepository library) async {
  try {
    final surahs = await library.getSurahs();
    if (!context.mounted || surahs.isEmpty) return;
    final controller = TextEditingController(text: '1');
    var selected = surahs.first;
    String? error;
    final target = await showDialog<({QuranSurah surah, int verse})>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const JustifiedText('سورہ / آیت پر جائیں'),
        content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButton<int>(value: selected.number, isExpanded: true,
            items: [for (final surah in surahs) DropdownMenuItem(value: surah.number,
              child: Text('${surah.number}. ${surah.displayTitle}', overflow: TextOverflow.ellipsis))],
            onChanged: (value) => setState(() {
              selected = surahs.firstWhere((s) => s.number == value);
              error = null;
            })),
          TextField(controller: controller, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'آیت نمبر (۱ تا ${selected.verseCount})', errorText: error),
            textDirection: TextDirection.rtl),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('منسوخ')),
          FilledButton(onPressed: () {
            final verse = parseReaderNumber(controller.text);
            if (verse == null || verse < 1 || verse > selected.verseCount) {
              setState(() => error = 'درست آیت نمبر لکھیں');
              return;
            }
            Navigator.pop(context, (surah: selected, verse: verse));
          }, child: const Text('جائیں')),
        ],
      )),
    );
    // Let the dialog's TextField leave the tree before releasing its controller.
    unawaited(Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose));
    if (target == null) return;
    final verse = await library.getQuranVerse(target.surah.number, target.verse);
    if (!context.mounted) return;
    if (verse == null) throw StateError('آیت دستیاب نہیں');
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SurahReaderScreen(
      library: library, surah: target.surah, initialRecordId: verse.recordId)));
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }
}
