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
}) async {
  final navigator = Navigator.of(context);
  var resolved = passage;
  final targetRecord = recordId ?? passage?.recordId;

  if (resolved == null && targetRecord != null && targetRecord > 0) {
    try {
      resolved = await library.getPassageById(book, targetRecord);
    } catch (_) {
      resolved = null;
    }
  }

  switch (book.source) {
    case CorpusSource.hadith:
      await navigator.push(MaterialPageRoute(
        builder: (_) => ReaderScreen(
          library: library,
          book: book,
          recordId: targetRecord,
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
        builder: (_) => typeNo > 0
            ? BalaghaReaderScreen(
                library: library,
                type: type,
                typeNo: typeNo,
                title: resolved?.sectionTitle ?? title ?? '',
              )
            : BalaghaIntroductionScreen(
                library: library,
                type: type,
                title: title ?? '${balaghaSectionTitles[type] ?? ''} — مقدمہ',
              ),
      ));
  }
}
