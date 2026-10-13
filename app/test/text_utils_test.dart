import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/text_utils.dart';

void main() {
  group('Arabic display spacing', () {
    test('collapses extra spaces, CRLF, and bidi marks', () {
      const raw = 'قَالَ\u200f  أَبُو جَعْفَرٍ\r\n  عَلَيْهِ السَّلَامُ';
      final compact = compactDisplayText(raw);
      expect(compact, 'قَالَ أَبُو جَعْفَرٍ\nعَلَيْهِ السَّلَامُ');
      expect(compact.contains('  '), isFalse);
      expect(compact.contains('\u200f'), isFalse);
      expect(compact.contains('\r'), isFalse);
    });
  });

  group('search tokens and FTS', () {
    test('normalizes diacritics and common letter variants', () {
      expect(normalizeArabicUrdu('آلِ كَافِيٌّ'), 'ال کافی');
      expect(searchTokens('الشيخ علي'), containsAll(['الشیخ', 'علی']));
    });

    test('builds prefix FTS queries without interpolating operators', () {
      expect(buildFtsQuery(['علی', 'امام'], fts4: false, prefix: true, andMode: true), '"علی"* AND "امام"*');
      expect(buildFtsQuery(['علی'], fts4: true, prefix: true, andMode: true), 'علی*');
      expect(escapeFtsToken('foo:bar*'), 'foobar');
    });

    test('drops Urdu stopwords and stems plurals', () {
      final tokens = searchTokens('نمازوں کو ملا کر پڑھنا کیسا ہے');
      expect(tokens, isNot(contains('کو')));
      expect(tokens, isNot(contains('ہے')));
      expect(tokens, contains('نماز'));
    });

    test('expands combining-prayers questions to jam bayn al-salatayn', () {
      final queries = expandSearchQueries('نمازوں کو ملا کر پڑھنا کیسا ہے');
      expect(queries.join(' '), contains('جمع بین'));
    });

    test('maps Roman Urdu Hussain questions onto Arabic book phrases', () {
      final queries = expandSearchQueries(
        'imam Hussain ko shadeed karny waloon mein sar e fehrist 5 afraad',
      );
      final blob = queries.join(' ');
      expect(blob, contains('قتل الحسین'));
      expect(blob, contains('یزید بن معاویہ'));
      expect(blob, contains('عمر بن سعد'));
      expect(queries.any((query) => query.toLowerCase().contains('hussain')), isFalse);
    });

    test('builds LIKE needles that cannot inject wildcards', () {
      expect(likeNeedle('ع%ل_ی'), '%علی%');
      expect(likeNeedle('علی'), '%علی%');
    });
  });

  group('display helpers', () {
    test('writes numbers with Arabic-Indic digits', () {
      expect(arabicNumerals(1), '۱');
      expect(arabicNumerals(114), '۱۱۴');
      expect(arabicNumerals(6236), '۶۲۳۶');
    });
  });

  group('citations', () {
    test('lists book, volume/chapter, section, and record number', () {
      final citation = formatCitation(
        bookTitle: 'وسائل الشیعہ',
        chapterTitle: 'جلد ۴ · باب الجمع بین الصلاتین',
        sectionTitle: 'جواز الجمع',
        recordId: 565809,
        page: 12,
      );
      expect(citation, contains('کتاب: وسائل الشیعہ'));
      expect(citation, contains('جلد / باب: جلد ۴ · باب الجمع بین الصلاتین'));
      expect(citation, contains('فصل: جواز الجمع'));
      expect(citation, contains('حدیث نمبر: 565809'));
      expect(citation, contains('صفحہ: 12'));
    });

    test('uses the record label of the collection being cited', () {
      final citation = formatCitation(
        bookTitle: 'قرآنِ کریم',
        chapterTitle: 'سورہ البقرہ',
        sectionTitle: '',
        recordId: 8,
        recordLabel: 'آیت',
      );
      expect(citation, contains('آیت: 8'));
      expect(citation, isNot(contains('حدیث نمبر')));
    });
  });
}
