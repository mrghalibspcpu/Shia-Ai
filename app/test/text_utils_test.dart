import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/text_utils.dart';

void main() {
  group('Gemini key detection', () {
    test('accepts Google AI Studio keys that start with AIza', () {
      expect(looksLikeGeminiApiKey('AIzaSyDummyTestKeyValueForUnitTests12345'), isTrue);
    });

    test('rejects backend URLs and short strings', () {
      expect(looksLikeGeminiApiKey('https://api.example.com'), isFalse);
      expect(looksLikeGeminiApiKey('AIzaShort'), isFalse);
      expect(looksLikeGeminiApiKey(''), isFalse);
    });
  });

  group('Arabic display spacing', () {
    test('collapses extra spaces, CRLF, and bidi marks', () {
      const raw = 'قَالَ\u200f  أَبُو جَعْفَرٍ\r\n  عَلَيْهِ السَّلَامُ';
      final compact = compactDisplayText(raw);
      expect(compact, 'قَالَ أَبُو جَعْفَرٍ\nعَلَيْهِ السَّلَامُ');
      expect(compact.contains('  '), isFalse);
      expect(compact.contains('\u200f'), isFalse);
      expect(compact.contains('\r'), isFalse);
    });
  });

  group('search tokens and FTS', () {
    test('normalizes diacritics and common letter variants', () {
      expect(normalizeArabicUrdu('آلِ كَافِيٌّ'), 'ال کافی');
      expect(searchTokens('الشيخ علي'), containsAll(['الشیخ', 'علی']));
    });

    test('builds prefix FTS queries without interpolating operators', () {
      expect(buildFtsQuery(['علی', 'امام'], fts4: false, prefix: true, andMode: true), '"علی"* AND "امام"*');
      expect(buildFtsQuery(['علی'], fts4: true, prefix: true, andMode: true), 'علی*');
      expect(escapeFtsToken('foo:bar*'), 'foobar');
    });
  });
}
