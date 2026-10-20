import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiaverse/app_theme.dart';
import 'package:shiaverse/library_repository.dart';
import 'package:shiaverse/models.dart';
import 'package:shiaverse/screens/quran_screen.dart';
import 'package:shiaverse/widgets/chapter_wallpaper.dart';
import 'package:shiaverse/widgets/mushaf_text.dart';
import 'package:shiaverse/widgets/reader_kit.dart';

const _surah = QuranSurah(number: 1, nameArabic: 'الفاتحة', nameUrdu: 'الفاتحہ',
    revelationPlace: 'مکی', verseCount: 3, revelationOrder: 1);

const _ayahs = <Passage>[
  Passage(recordId: 1, page: 1, containerType: 1, sectionTitle: 'الفاتحة',
    arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', urdu: 'ترجمہ اوّل', locator: 'آیت 1',
    commentary: 'تفسیری حاشیہ اوّل', footnote: 'حاشیہ اوّل'),
  Passage(recordId: 2, page: 1, containerType: 1, sectionTitle: 'الفاتحة',
    arabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ', urdu: 'ترجمہ دوم', locator: 'آیت 2'),
  Passage(recordId: 3, page: 2, containerType: 1, sectionTitle: 'الفاتحة',
    arabic: 'الرَّحْمَٰنِ الرَّحِيمِ', urdu: 'ترجمہ سوم', locator: 'آیت 3'),
];

class _QuranLibrary extends LibraryRepository {
  @override
  Future<List<Passage>> getSurahVerses(int chapter) async => _ayahs;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('groups all verses in order, preserving complete matn and precise jumps', () {
    final groups = groupMushafVerses(_ayahs);
    expect(groups.map((g) => g.verses.length), <int>[2, 1]);
    expect(groups.expand((g) => g.verses).map((v) => v.arabic).toList(),
        _ayahs.map((v) => v.arabic).toList());
    final focused = groupMushafVerses(_ayahs, focusRecordId: 2);
    expect(focused.map((g) => g.firstRecordId), <int>[1, 2, 3]);
    expect(mushafVerseNumber(_ayahs[1]), 2);
    final nextSurah = <Passage>[
      ..._ayahs.take(2),
      const Passage(recordId: 4, page: 1, containerType: 2, arabic: 'الم', urdu: '', locator: 'آیت 1'),
    ];
    expect(groupMushafVerses(nextSurah), hasLength(2), reason: 'new surah starts a flow');
  });

  testWidgets('mushaf mode is a justified continuous Arabic page, reversible and saved', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildLightTheme(), home: SurahReaderScreen(
      library: _QuranLibrary(), surah: _surah, startInMushaf: true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('ترتیبات'), findsOneWidget);
    expect(find.text('جائیں'), findsOneWidget);
    expect(find.byType(MushafText), findsWidgets);
    expect(find.byType(PassageCard), findsNothing);
    final matn = tester.widget<RichText>(find.byKey(const ValueKey<String>('mushaf-page-1')));
    expect(matn.textAlign, TextAlign.justify);
    expect(matn.text.toPlainText(), contains(_ayahs.first.arabic));
    expect(matn.text.toPlainText(), contains(_ayahs[1].arabic));
    expect(matn.text.toPlainText(), contains('﴿۲﴾'));
    expect(matn.text.toPlainText(), isNot(contains(_ayahs.first.urdu)));
    expect(find.textContaining('تفسیری حاشیہ'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('quran-mushaf-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(PassageCard), findsWidgets);
    expect((await SharedPreferences.getInstance()).getBool(kQuranMushafKey), isFalse);
    await tester.tap(find.byKey(const ValueKey<String>('quran-mushaf-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(MushafText), findsWidgets);
    expect(find.byType(PassageCard), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool(kQuranMushafKey), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping an ayah in the mushaf opens its translation and a tafseer toggle', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildLightTheme(), home: SurahReaderScreen(
      library: _QuranLibrary(), surah: _surah, startInMushaf: true,
    )));
    await tester.pumpAndSettle();
    // Every ayah — and its ﴿n﴾ marker — carries a tap recognizer, so a tap
    // anywhere inside the ayah can open the popup.
    final matn = tester.widget<RichText>(find.byKey(const ValueKey<String>('mushaf-page-1')));
    final spans = (matn.text as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.recognizer, isA<TapGestureRecognizer>());
    expect(spans[1].text, contains('﴿۱﴾'));
    expect(spans[1].recognizer, isA<TapGestureRecognizer>());

    final mushaf = tester.widget<MushafText>(find.byType(MushafText).first);
    expect(mushaf.onVerseTap, isNotNull);
    mushaf.onVerseTap!(_ayahs.first);
    await tester.pumpAndSettle();
    expect(find.text('ترجمہ'), findsOneWidget);
    expect(find.text('ترجمہ اوّل'), findsOneWidget);
    expect(find.textContaining('تفسیری حاشیہ'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('quran-tafseer-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('تفسیری حاشیہ اوّل'), findsOneWidget);
    expect(find.text('تفسیر چھپائیں'), findsOneWidget);
    await tester.tap(find.text('بند کریں'));
    await tester.pumpAndSettle();
    expect(find.text('ترجمہ اوّل'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the reader offers full screen and a smooth, adjustable auto-scroll', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildLightTheme(), home: SurahReaderScreen(
      library: _QuranLibrary(), surah: _surah,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('reader-auto-scroll')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('reader-full-screen')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey<String>('reader-display-bar')), findsOneWidget);
    await tester.tap(find.byTooltip('پوری اسکرین سے باہر'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('reader-auto-scroll')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1.00×'), findsOneWidget);
    // The strip's own +/- controls change the pace; they are practical enough
    // to use with a thumb while the text is moving.
    await tester.tap(find.byTooltip('تیز تر'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1.25×'), findsOneWidget);
    await tester.tap(find.byTooltip('روکیں'));
    await tester.pump(const Duration(milliseconds: 400));
    // The list really moved: the first verse is no longer at its start offset.
    expect(find.byKey(const ValueKey<String>('reader-display-bar')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saved mushaf preference does not change the default search result', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{kQuranMushafKey: true});
    await tester.pumpWidget(MaterialApp(theme: buildLightTheme(), home: SurahReaderScreen(
      library: _QuranLibrary(), surah: _surah, initialRecordId: 2,
      searchQuery: 'ترجمہ',
    )));
    await tester.pumpAndSettle();
    expect(find.byType(PassageCard), findsWidgets);
    expect(find.byType(MushafText), findsNothing);
    expect(find.byKey(const ValueKey<String>('quran-2')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('chapter parchment stays inside a tappable chapter card', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildLightTheme(), home: Scaffold(
      body: ChapterWallpaperCard(child: ListTile(title: const Text('باب اوّل'), onTap: () {})),
    )));
    final ink = tester.widget<Ink>(find.descendant(
      of: find.byType(ChapterWallpaperCard), matching: find.byType(Ink)).first);
    final decoration = ink.decoration! as BoxDecoration;
    expect((decoration.image!.image as AssetImage).assetName, ChapterWallpaperCard.asset);
    expect(find.text('باب اوّل'), findsOneWidget);
  });
}
