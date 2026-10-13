import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/library_repository.dart';
import 'package:shia_ai/models.dart';

void main() {
  group('local Arabic/Urdu search', () {
    test('normalizes diacritics and common Arabic/Persian letter variants', () {
      expect(normalizeArabicUrdu('آلِ كَافِيٌّ'), 'ال کافی');
      expect(normalizeArabicUrdu('قَالَ الشَّيْخُ عَلِيٌّ'), 'قال الشیخ علی');
    });

    test('compacts Arabic display text used by the reader', () {
      final passage = Passage.fromMap({
        'record_id': 1,
        'arabic': 'قَالَ\u200f  أَبُو جَعْفَرٍ',
        'urdu': 'امام  نے  فرمایا',
      });
      expect(passage.arabic.contains('  '), isFalse);
      expect(passage.urdu, 'امام نے فرمایا');
    });

    test('does not produce terms for punctuation-only input', () {
      expect(normalizeArabicUrdu('  ؟ ؛ ،  '), isEmpty);
    });
  });

  group('corpus catalogue', () {
    test('lists the 14 hadith books plus the three new collections', () {
      expect(BookDefinition.all, hasLength(17));
      expect(BookDefinition.hadithBooks, hasLength(14));
      expect(BookDefinition.byKey('tahzeeb')?.fileName, 'Tahzeeb.db');
      expect(BookDefinition.byKey('quran')?.source, CorpusSource.quran);
      expect(BookDefinition.byKey('mafatih')?.fileName, 'mafatihdb-v4.db');
      expect(BookDefinition.byKey('nahjul_balagha')?.source, CorpusSource.balagha);
      expect(BookDefinition.byKey('does-not-exist'), isNull);
    });

    test('every book resolves from its own source', () {
      for (final source in CorpusSource.values) {
        expect(BookDefinition.bookFor(source), isNotNull, reason: source.wire);
      }
      expect(BookDefinition.bookFor(CorpusSource.quran)?.key, 'quran');
      expect(corpusSourceFromWire('dua'), CorpusSource.dua);
      expect(corpusSourceFromWire('nonsense'), CorpusSource.hadith);
    });

    test('file names stay unique so downloads cannot overwrite each other', () {
      final names = BookDefinition.all.map((book) => book.fileName).toSet();
      expect(names, hasLength(BookDefinition.all.length));
      final keys = BookDefinition.all.map((book) => book.key).toSet();
      expect(keys, hasLength(BookDefinition.all.length));
    });
  });

  group('reader records', () {
    test('reads the shared columns of every collection', () {
      final passage = Passage.fromMap({
        'record_id': 12,
        'arabic': 'بِسْمِ اللَّهِ',
        'urdu': 'اللہ کے نام سے',
        'commentary': 'تفسیری حاشیہ',
        'locator': 'آیت 1',
        'container_type': 1,
        'container_id': 1,
      });
      expect(passage.recordId, 12);
      expect(passage.locator, 'آیت 1');
      expect(passage.containerType, 1);
      expect(passage.commentary, 'تفسیری حاشیہ');
      expect(passage.copyableText, contains('بِسْمِ اللَّهِ'));
      expect(passage.copyWith(footnote: 'حاشیہ').footnote, 'حاشیہ');
    });

    test('hadith citations keep the record locator', () {
      final source = ReaderTarget.fromJson({
        'book': 'alkafi',
        'record_id': 9001,
        'section_id': 7,
        'page': 12,
      });
      expect(source.book, 'alkafi');
      expect(source.recordId, 9001);
      expect(source.sectionId, 7);
      expect(source.page, 12);
    });
  });

  group('new collections', () {
    test('maps surah rows and adds the Urdu name', () {
      final surah = QuranSurah.fromMap(
        {'Id': 1, 'Name': 'الْفَاتِحَة', 'Nozol': 'مکی', 'Verse': 7, 'revel': 5},
        index: 0,
      );
      expect(surah.nameUrdu, 'الفاتحہ');
      expect(surah.verseCount, 7);
      expect(surah.revelationOrder, 5);
      expect(surah.displayTitle, contains('الْفَاتِحَة'));
    });

    test('surah name list covers the whole mushaf', () {
      expect(urduSurahNames, hasLength(114));
      expect(urduSurahNames.first, 'الفاتحہ');
      expect(urduSurahNames.last, 'الناس');
    });

    test('maps Mafatih catalogue rows', () {
      final header = DuaItem.fromMap({
        'row_id': 1,
        'M_name': 'تعقیبات نماز',
        'M_cat_id': 2,
        'M_type': 2,
        'M_montakhab': 0,
        'line_count': 0,
      });
      final leaf = DuaItem.fromMap({
        'row_id': 2,
        'M_name': 'تعقیبات مشترکہ',
        'M_cat_id': 2,
        'M_type': 1,
        'M_montakhab': 1,
        'line_count': 41,
      });
      expect(header.isHeader, isTrue);
      expect(leaf.isHeader, isFalse);
      expect(leaf.isFeatured, isTrue);
      expect(leaf.lineCount, 41);
      expect(duaCategoryTitles, hasLength(6));
    });

    test('names every Nahj al-Balagha division', () {
      expect(balaghaSectionTitles[1], 'خطب');
      expect(balaghaSectionTitles[2], 'کتب و خطوط');
      expect(balaghaSectionTitles[3], 'حکمت و اقوالِ قصار');
      expect(balaghaSectionTitles[4], contains('احادیث'));
      expect(balaghaSectionTitles[5], contains('مقدمات'));
    });

    test('describes where a juz starts', () {
      const entry = QuranJuzEntry(juz: 30, firstRecordId: 5678, surah: 78, verse: 1);
      expect(entry.title, contains('پارہ 30'));
      expect(entry.title, contains('النبا'));
      expect(entry.title, contains('آیت 1'));
    });
  });
}
