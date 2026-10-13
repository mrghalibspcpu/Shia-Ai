import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/library_repository.dart';
import 'package:shia_ai/models.dart';

void main() {
  group('local Arabic/Urdu search', () {
    test('normalizes diacritics and common Arabic/Persian letter variants', () {
      expect(normalizeArabicUrdu('آلِ كَافِيٌّ'), 'ال کافی');
      expect(normalizeArabicUrdu('قَالَ الشَّيْخُ عَلِيٌّ'), 'قال الشیخ علی');
    });

    test('does not produce terms for punctuation-only input', () {
      expect(normalizeArabicUrdu('  ؟ ؛ ،  '), isEmpty);
    });
  });

  group('reader citation targets', () {
    test('resolves a backend citation to the exact local record', () {
      final source = AiSource.fromJson({
        'marker': '[R1]',
        'citation': 'alkafi.db · باب فضائل العلم · record 9001 · page 12',
        'reader_target': {
          'book': 'alkafi',
          'record_id': 9001,
          'section_id': 7,
          'page': 12,
        },
      });

      expect(source.marker, '[R1]');
      expect(source.target.book, 'alkafi');
      expect(source.target.recordId, 9001);
      expect(source.target.sectionId, 7);
      expect(source.target.page, 12);
    });

    test('catalog lists the complete 14-book corpus', () {
      expect(BookDefinition.all, hasLength(14));
      expect(BookDefinition.byKey('tahzeeb')?.fileName, 'Tahzeeb.db');
      expect(BookDefinition.byKey('does-not-exist'), isNull);
    });

    test('chat persistence retains citation navigation targets', () {
      final original = ChatMessage(
        isUser: false,
        text: 'یہ روایت [R1] میں موجود ہے۔',
        sources: [
          const AiSource(
            marker: '[R1]',
            citation: 'alkafi.db, record 9001',
            target: ReaderTarget(book: 'alkafi', recordId: 9001, sectionId: 7, page: 12),
          ),
        ],
      );
      final restored = ChatMessage.fromJson(original.toJson());
      expect(restored.sources.single.target.recordId, 9001);
      expect(restored.sources.single.target.book, 'alkafi');
    });
  });
}
