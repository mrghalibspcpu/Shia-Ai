import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../reader_navigation.dart';
import '../screens/balagha_screen.dart';
import '../screens/duas_screen.dart';
import '../screens/fatawa_screen.dart';
import '../screens/library_screen.dart';
import '../screens/quran_screen.dart';
import '../screens/dua_collection_screen.dart';

/// Re-opens the position a reader left off at.
///
/// Every reader writes two things when it saves progress (see
/// `LibraryRepository.saveLastRead`): the global entry, which powers the
/// "آخری مطالعہ" card on the home screen, and one entry per book. This widget
/// renders the second kind — so the Quran remembers its own surah while
/// Mafatih, Sahifa, Nahj al-Balagha and each hadith book remember theirs.
Future<void> openLastRead(
  BuildContext context,
  LibraryRepository library,
  LastReadEntry entry, {
  bool includeCollection = true,
}) async {
  final book = entry.book;
  if (book == null || !library.isInstalled(book) || !context.mounted) return;
  final navigator = Navigator.of(context);
  Passage? passage;
  final recordId = entry.recordId;
  if (recordId != 0) {
    try {
      passage = await library.getPassageById(book, recordId);
    } catch (_) {
      passage = null;
    }
  }
  if (!context.mounted) return;

  Future<void> openReader() => pushReaderFor(
        context,
        library: library,
        book: book,
        passage: passage,
        recordId: recordId,
        sectionId: entry.sectionId ?? passage?.sectionId,
      );

  switch (book.source) {
    case CorpusSource.quran:
      final surah = passage?.containerType ?? entry.sectionId;
      // The list goes on the stack first and is not awaited: awaiting it would
      // wait until the reader pressed back, and the passage would never open.
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => QuranHomeScreen(library: library, focusSurah: surah),
      ));
      await openReader();
    case CorpusSource.dua:
      final categoryId = passage?.containerType ?? entry.sectionId;
      final rowId = passage?.containerId ?? recordId;
      DuaCategory? category;
      if (categoryId != null && categoryId != 0) {
        final categories = await library.getDuaCategories();
        for (final item in categories) {
          if (item.id == categoryId) category = item;
        }
      }
      if (!context.mounted) return;
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => DuasHomeScreen(library: library, focusCategoryId: categoryId),
      ));
      if (category != null) {
        final chosen = category;
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => DuaCategoryScreen(
            library: library,
            category: chosen,
            focusRowId: rowId,
          ),
        ));
      }
      await openReader();
    case CorpusSource.balagha:
      final type = passage?.containerType ?? 0;
      final typeNo = passage?.containerId ?? 0;
      if (type < 1 || type > 3 || typeNo <= 0) {
        await navigator.push(MaterialPageRoute<void>(
          builder: (_) => BalaghaHomeScreen(library: library),
        ));
        return;
      }
      final sections = await library.getBalaghaSections();
      BalaghaSection? section;
      for (final item in sections) {
        if (item.type == type) section = item;
      }
      if (!context.mounted) return;
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => BalaghaHomeScreen(library: library),
      ));
      if (section != null) {
        final chosen = section;
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => BalaghaSectionScreen(
            library: library,
            section: chosen,
            focusTypeNo: typeNo,
          ),
        ));
      }
      await openReader();
    case CorpusSource.fatwa:
      if (includeCollection) {
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => FatawaCollectionScreen(library: library),
        ));
      }
      await _pushChapterThenReader(context, library, book, entry, passage, openReader);
    case CorpusSource.sahifa:
      if (includeCollection) {
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => DuaCollectionScreen(library: library),
        ));
      }
      await _pushChapterThenReader(context, library, book, entry, passage, openReader);
    case CorpusSource.hadith:
    case CorpusSource.encyclopedia:
      await _pushChapterThenReader(context, library, book, entry, passage, openReader);
  }
}

/// Puts the chapter list (scrolled to the saved chapter) under the reader, so
/// back from the passage lands on that chapter instead of the collection root.
Future<void> _pushChapterThenReader(
  BuildContext context,
  LibraryRepository library,
  BookDefinition book,
  LastReadEntry entry,
  Passage? passage,
  Future<void> Function() openReader,
) async {
  final navigator = Navigator.of(context);
  final sectionId = entry.sectionId ?? passage?.sectionId ?? passage?.containerId;
  int? chapterId;
  if (sectionId != null && sectionId != 0) {
    try {
      chapterId = await library.chapterIdFor(book, sectionId);
    } catch (_) {
      chapterId = sectionId;
    }
  }
  if (!context.mounted) return;
  navigator.push(MaterialPageRoute<void>(
    builder: (_) => ChapterListScreen(
      library: library,
      book: book,
      focusChapterId: chapterId,
    ),
  ));
  await openReader();
}

/// "جاری رکھیں" for one book. Renders nothing when that book has no history.
class ResumeCard extends StatelessWidget {
  const ResumeCard({
    super.key,
    required this.library,
    required this.book,
    this.margin = const EdgeInsets.only(bottom: 10),
    this.onOpened,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LastReadEntry?>(
      future: library.getLastReadFor(book.key),
      builder: (context, snapshot) {
        final entry = snapshot.data;
        if (entry == null) return const SizedBox.shrink();
        return LastReadTile(
          library: library,
          entry: entry,
          margin: margin,
          title: 'جاری رکھیں',
          onOpened: onOpened,
        );
      },
    );
  }
}

/// One saved position as a tappable card: book, reference, and when it was left.
class LastReadTile extends StatelessWidget {
  const LastReadTile({
    super.key,
    required this.library,
    required this.entry,
    this.title = 'آخری مطالعہ',
    this.margin = const EdgeInsets.only(bottom: 10),
    this.showBookName = true,
    this.onOpened,
    this.onBeforeOpen,
    this.openContext,
  });

  final LibraryRepository library;
  final LastReadEntry entry;
  final String title;
  final EdgeInsetsGeometry margin;

  /// Runs first on tap, before the reader opens (a sheet closes here).
  final VoidCallback? onBeforeOpen;

  /// Where the reader is opened from. A sheet passes the page underneath, since
  /// its own context is gone once the sheet has closed.
  final BuildContext? openContext;

  /// False when the caller already prints the book name as the title.
  final bool showBookName;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    final book = entry.book;
    if (book == null) return const SizedBox.shrink();
    final subtitle = <String>[
      if (showBookName) book.titleUrdu,
      if (entry.referenceOrTitle.isNotEmpty) entry.referenceOrTitle,
      if (entry.timeLabel.isNotEmpty) entry.timeLabel,
    ].join(' — ');
    return Card(
      margin: margin,
      child: ListTile(
        leading: const Icon(Icons.history_toggle_off, color: kForest),
        title: JustifiedText(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: JustifiedText(subtitle, maxLines: 2),
        trailing: const Icon(Icons.chevron_left),
        onTap: () async {
          onBeforeOpen?.call();
          await openLastRead(openContext ?? context, library, entry);
          onOpened?.call();
        },
      ),
    );
  }
}
