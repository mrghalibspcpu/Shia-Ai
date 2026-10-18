import 'package:flutter/material.dart';

import 'models.dart';
import 'library_repository.dart';
import 'screens/balagha_screen.dart';
import 'screens/duas_screen.dart';
import 'screens/library_screen.dart';
import 'screens/quran_screen.dart';

/// Opens the right reader for any collection.
///
/// Every screen (search results, bookmarks, notes, deep links) goes through here
/// so a Quran verse, a supplication, a Nahj al-Balagha paragraph, and a hadith
/// all resolve to their own reader without the caller knowing the difference.
Future<void> pushReaderFor(
  BuildContext context, {
  required LibraryRepository library,
  required BookDefinition book,
  Passage? passage,
  int? recordId,
  int? sectionId,
  String? title,
  String searchQuery = '',
}) async {
  final navigator = Navigator.of(context);
  var resolved = passage;
  final targetRecord = recordId ?? passage?.recordId;

  if (resolved == null && targetRecord != null && targetRecord != 0) {
    try {
      resolved = await library.getPassageById(book, targetRecord);
    } catch (_) {
      resolved = null;
    }
  }

  if (!context.mounted) return;
  switch (book.source) {
    case CorpusSource.sahifa:
    case CorpusSource.fatwa:
    case CorpusSource.hadith:
    case CorpusSource.wiki:
      await navigator.push(MaterialPageRoute(
        builder: (_) => ReaderScreen(
          library: library,
          book: book,
          recordId: targetRecord,
          searchQuery: searchQuery,
          sectionId: sectionId ?? resolved?.sectionId,
          sectionTitle: title ?? (resolved?.sectionTitle.isEmpty == false ? resolved!.sectionTitle : null),
        ),
      ));
    case CorpusSource.quran:
      final chapter = resolved?.containerType ?? 1;
      final urduName = chapter >= 1 && chapter <= urduSurahNames.length
          ? urduSurahNames[chapter - 1]
          : '';
      await navigator.push(MaterialPageRoute(
        builder: (_) => SurahReaderScreen(
          library: library,
          initialRecordId: targetRecord,
          searchQuery: searchQuery,
          surah: QuranSurah(
            number: chapter,
            nameArabic: resolved?.sectionTitle ?? '',
            nameUrdu: urduName,
            revelationPlace: '',
            verseCount: 0,
            revelationOrder: 0,
          ),
        ),
      ));
    case CorpusSource.dua:
      final itemRowId = resolved?.containerId ?? targetRecord ?? 0;
      if (itemRowId <= 0) return;
      await navigator.push(MaterialPageRoute(
        builder: (_) => DuaReaderScreen(
          library: library,
          searchQuery: searchQuery,
          item: DuaItem(
            rowId: itemRowId,
            name: resolved?.sectionTitle ?? title ?? '',
            categoryId: resolved?.containerType ?? 0,
            isHeader: false,
            isFeatured: false,
          ),
        ),
      ));
    case CorpusSource.balagha:
      final type = resolved?.containerType ?? 1;
      final typeNo = resolved?.containerId ?? 0;
      await navigator.push(MaterialPageRoute(
        builder: (_) => (targetRecord ?? 0) < 0 && (targetRecord ?? 0) > -1000000 && type != 5
            ? BalaghaNotesReaderScreen(library: library, type: type, typeNo: typeNo,
                initialRecordId: targetRecord, searchQuery: searchQuery)
            : typeNo > 0
            ? BalaghaReaderScreen(
                library: library,
                initialRecordId: targetRecord,
                searchQuery: searchQuery,
                type: type,
                typeNo: typeNo,
                title: resolved?.sectionTitle ?? title ?? '',
              )
            : BalaghaIntroductionScreen(
                library: library,
                initialRecordId: targetRecord,
                searchQuery: searchQuery,
                type: type,
                title: title ?? '${balaghaSectionTitles[type] ?? ''} — مقدمہ',
              ),
      ));
  }
}
