import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../widgets/reader_kit.dart';
import '../widgets/reader_chrome.dart';
import '../widgets/chapter_wallpaper.dart';
import '../widgets/resume_card.dart';

/// Nahj al-Balagha: khutbas, letters, wisdoms, prophetic traditions, and the
/// introductions that accompany them.
class BalaghaHomeScreen extends StatefulWidget {
  const BalaghaHomeScreen({super.key, required this.library});

  final LibraryRepository library;

  @override
  State<BalaghaHomeScreen> createState() => _BalaghaHomeScreenState();
}

class _BalaghaHomeScreenState extends State<BalaghaHomeScreen> {
  /// Re-reads this collection's saved position after the reader closes.
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('نہج البلاغہ')),
      body: FutureBuilder<List<BalaghaSection>>(
        future: library.getBalaghaSections(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
          final sections = snapshot.data ?? const [];
          if (sections.isEmpty) {
            return const CollectionMessage('نہج البلاغہ دستیاب نہیں۔', icon: Icons.auto_stories_outlined);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              ResumeCard(
                library: library,
                book: BookDefinition.bookFor(CorpusSource.balagha)!,
                onOpened: _refresh,
              ),
              for (final section in sections) ...[
                ChapterWallpaperCard(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.auto_stories, size: 20),
                    ),
                    title: JustifiedText(
                      section.titleUrdu,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      '${section.entryCount} عنوانات',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BalaghaSectionScreen(library: library, section: section),
                    )),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class BalaghaSectionScreen extends StatelessWidget {
  const BalaghaSectionScreen({super.key, required this.library, required this.section});

  final LibraryRepository library;
  final BalaghaSection section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: JustifiedText(section.titleUrdu, maxLines: 1)),
      body: FutureBuilder<List<BalaghaEntry>>(
        future: library.getBalaghaEntries(section.type),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
          final entries = snapshot.data ?? const [];
          if (entries.isEmpty && !section.hasIntroduction) {
            return const CollectionMessage('اس حصے میں کوئی عنوان نہیں۔');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
            itemCount: entries.length + (section.hasIntroduction ? 1 : 0),
            itemBuilder: (context, index) {
              if (section.hasIntroduction && index == 0) {
                return ChapterWallpaperCard(
                  child: ListTile(
                    leading: const Icon(Icons.import_contacts, color: kForest),
                    title: const JustifiedText('اس حصے کا مقدمہ', style: TextStyle(fontSize: 17)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BalaghaIntroductionScreen(
                        library: library,
                        type: section.type,
                        title: '${section.titleUrdu} — مقدمہ',
                      ),
                    )),
                  ),
                );
              }
              final entry = entries[index - (section.hasIntroduction ? 1 : 0)];
              return ChapterWallpaperCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Text('${entry.typeNo}'),
                  ),
                  title: JustifiedText(
                    entry.title.isEmpty ? 'عنوان ${entry.typeNo}' : entry.title,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 2,
                  ),
                  // No paragraph counts ("۲۳۸ فقرے"): the count is an internal
                  // detail of the database, not something readers asked for.
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BalaghaReaderScreen(
                      library: library,
                      type: section.type,
                      typeNo: entry.typeNo,
                      title: entry.title,
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

class BalaghaReaderScreen extends StatelessWidget {
  const BalaghaReaderScreen({
    super.key,
    required this.library,
    required this.type,
    required this.typeNo,
    required this.title,
    this.initialRecordId,
    this.searchQuery = '',
  });

  final LibraryRepository library;
  final int type;
  final int typeNo;
  final String title;
  final int? initialRecordId;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return _BalaghaPassageList(
      library: library,
      title: title.isEmpty ? '${balaghaSectionTitles[type] ?? ''} $typeNo' : title,
      loader: () => library.getBalaghaEntry(type, typeNo),
      storageKey: 'balagha-$type-$typeNo',
      initialRecordId: initialRecordId,
      searchQuery: searchQuery,
      recordIdForLastRead: typeNo,
    );
  }
}

class BalaghaIntroductionScreen extends StatelessWidget {
  const BalaghaIntroductionScreen({
    super.key,
    required this.library,
    required this.type,
    required this.title,
    this.initialRecordId,
    this.searchQuery = '',
  });

  final LibraryRepository library;
  final int type;
  final String title;
  final int? initialRecordId;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return _BalaghaPassageList(
      library: library,
      title: title,
      loader: () => library.getBalaghaIntroduction(type),
      storageKey: 'balagha-intro-$type',
      initialRecordId: initialRecordId,
      searchQuery: searchQuery,
      recordIdForLastRead: 0,
    );
  }
}

class _BalaghaPassageList extends StatefulWidget {
  const _BalaghaPassageList({
    required this.library,
    required this.title,
    this.initialRecordId,
    this.searchQuery = '',
    required this.loader,
    required this.storageKey,
    required this.recordIdForLastRead,
  });

  final LibraryRepository library;
  final String title;
  final int? initialRecordId;
  final String searchQuery;
  final Future<List<Passage>> Function() loader;
  final String storageKey;
  final int recordIdForLastRead;

  @override
  State<_BalaghaPassageList> createState() => _BalaghaPassageListState();
}

class _BalaghaPassageListState extends State<_BalaghaPassageList> {
  final BookDefinition _book = BookDefinition.bookFor(CorpusSource.balagha)!;

  List<Passage> _passages = const [];
  int _initialIndex = 0;
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
      final passages = await widget.loader();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _passages = passages;
        final index = passages.indexWhere((p) => p.recordId == widget.initialRecordId);
        _initialIndex = index < 0 ? 0 : index;
        _loading = false;
      });
      if (passages.isNotEmpty && widget.recordIdForLastRead > 0) {
        final current = passages[_initialIndex];
        unawaited(widget.library.saveLastRead(
          bookKey: _book.key,
          recordId: current.recordId,
          sectionId: current.sectionId,
          title: widget.title,
          reference: readingReference(_book, current),
        ));
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
      book: _book,
      title: widget.title,
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
                        initialScrollIndex: _initialIndex,
                        initialAlignment: 0.04,
                        key: PageStorageKey(widget.storageKey),
                        itemCount: _passages.length,
                        addAutomaticKeepAlives: false,
                        minCacheExtent: 350,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 112),
                        itemBuilder: (context, index) {
                          final passage = _passages[index];
                          if (passage.format == 4) {
                            // A decorative separator in the source text
                            // ('-----٭٭-----'): render it as one, not as a
                            // card full of dashes.
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text('٭ ٭ ٭', style: TextStyle(color: kForest)),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                            );
                          }
                          return PassageCard(
                            key: ValueKey('balagha-${passage.recordId}'),
                            library: widget.library,
                            book: _book,
                            passage: passage,
                            palette: palette,
                            fontScale: _preferences.fontScale,
                            script: widget.searchQuery.isEmpty ? _preferences.script : 'both',
                            searchQuery: widget.searchQuery,
                            focusMatch: passage.recordId == widget.initialRecordId,
                          );
                        },
                      ),
                    ),
    );
  }
}


class BalaghaNotesReaderScreen extends StatelessWidget {
  const BalaghaNotesReaderScreen({super.key, required this.library, required this.type,
    required this.typeNo, this.initialRecordId, this.searchQuery = ''});
  final LibraryRepository library;
  final int type;
  final int typeNo;
  final int? initialRecordId;
  final String searchQuery;
  @override
  Widget build(BuildContext context) => _BalaghaPassageList(library: library,
    title: '${balaghaSectionTitles[type] ?? 'نہج البلاغہ'} — حواشی',
    loader: () => library.getBalaghaNotes(type, typeNo), storageKey: 'balagha-notes-$type-$typeNo',
    initialRecordId: initialRecordId, searchQuery: searchQuery, recordIdForLastRead: typeNo);
}
