import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiaverse/library_repository.dart';
import 'package:shiaverse/models.dart';
import 'package:shiaverse/screens/quran_screen.dart';
import 'package:shiaverse/text_utils.dart';
import 'package:shiaverse/widgets/highlighted_text.dart';

class _ReaderLibrary extends LibraryRepository {
  @override
  Future<List<Passage>> getSurahVerses(int chapter) async => List.generate(286,
    (index) => Passage(recordId: index + 1, arabic: 'آیت ${index + 1}',
      urdu: 'اللہ کے نام سے', locator: 'آیت ${index + 1}'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normalized highlighting retains original diacritics and letter variants', () {
    const text = 'قَالَ الشَّيْخُ عَلِيٌّ';
    final ranges = searchMatchRanges(text, 'الشیخ علی');
    expect(ranges, hasLength(2));
    expect(text.substring(ranges[0].start, ranges[0].end), 'الشَّيْخُ');
    expect(text.substring(ranges[1].start, ranges[1].end), 'عَلِيٌّ');
    expect(searchMatchRanges('آلِ كَافِيٌّ', 'کافی'), isNotEmpty);
    expect(searchMatchRanges(text, '؟'), isEmpty);
  });

  test('matches single letters, repeated terms and whitespace without corrupting offsets', () {
    final ranges = searchMatchRanges('اللہ  اللہ', 'اللہ');
    expect(ranges, [(start: 0, end: 4), (start: 6, end: 10)]);
    expect(searchMatchRanges('ا ب', 'ا'), [(start: 0, end: 1)]);
    expect(searchMatchRanges('الف\n\nباء', 'الف باء'), hasLength(2));
  });

  test('jump input accepts all three digit scripts', () {
    expect(parseReaderNumber('114'), 114);
    expect(parseReaderNumber('۱۱۴'), 114);
    expect(parseReaderNumber('١١٤'), 114);
    expect(parseReaderNumber('bad'), isNull);
  });

  test('a word near the end of a long passage is in the snippet', () {
    final text = '${List.filled(200, 'عبارت').join(' ')} مخصوص';
    final snippet = searchSnippet(text, 'مخصوص');
    expect(snippet, contains('مخصوص'));
    expect(snippet.length, lessThan(text.length));
  });

  testWidgets('Quran starts on a late ayah without eagerly building the full surah', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SurahReaderScreen(
      library: _ReaderLibrary(), initialRecordId: 280, searchQuery: 'اللہ',
      surah: const QuranSurah(number: 2, nameArabic: 'البقرة', nameUrdu: 'البقرہ',
        revelationPlace: 'مدنی', verseCount: 286, revelationOrder: 87))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quran-280')), findsOneWidget);
    expect(find.byKey(const ValueKey('quran-1')), findsNothing);
    expect(find.byType(HighlightedText).evaluate().length, lessThan(50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exact word scrolling works inside SelectionArea, not just at paragraph start', (tester) async {
    final controller = ScrollController();
    final text = '${List.filled(150, 'متن\n').join()}مخصوص';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SelectionArea(
      child: SingleChildScrollView(controller: controller, child: HighlightedText(
        text, query: 'مخصوص', scrollToMatch: true))))));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(1000));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
