import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_ai/app_theme.dart';
import 'package:shia_ai/library_repository.dart';
import 'package:shia_ai/models.dart';
import 'package:shia_ai/screens/prayer_times_screen.dart';
import 'package:shia_ai/screens/tasbeeh_screen.dart';
import 'package:shia_ai/services/alerts.dart';
import 'package:shia_ai/services/city_index.dart';
import 'package:shia_ai/services/prayer_controller.dart';
import 'package:shia_ai/services/prayer_locations.dart';
import 'package:shia_ai/services/prayer_scope.dart';
import 'package:shia_ai/services/tasbeeh_controller.dart';
import 'package:shia_ai/widgets/home_dashboard.dart';

/// Layout checks for the 1.9 home dashboard and the screens around it on a
/// small (360 dp) phone, with the app's real fonts: any overflow fails the
/// test. When `SHIAVERSE_PREVIEW_DIR` is set (CI does), each screen is also
/// saved as a PNG so the layout can be looked at without a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final previewDir = Platform.environment['SHIAVERSE_PREVIEW_DIR'];
  final shotKey = GlobalKey();

  setUpAll(() async {
    Future<void> load(String family, String path) async {
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = file.readAsBytesSync();
      final loader = FontLoader(family)..addFont(Future.value(bytes.buffer.asByteData()));
      await loader.load();
    }

    await load(kUrduFont, 'assets/fonts/JameelNooriNastaleeq.ttf');
    await load(kArabicFont, 'assets/fonts/Amiri-Regular.ttf');
    // The phone's sans face is not available in tests; Amiri's Latin digits
    // have about the same width.
    await load(kDigitFont, 'assets/fonts/Amiri-Regular.ttf');
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      await load('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// Islamabad (UTC+5), at a local wall-clock time.
  DateTime localTime(int hour, int minute) => DateTime.utc(2026, 10, 15, hour - 5, minute);

  Future<(PrayerController, TasbeehController)> controllersAt(WidgetTester tester, DateTime device) async {
    final prayer = PrayerController(
      clock: () => device,
      feedback: const SilentFeedback(),
      locate: () async => const PrayerLocation(
        latitude: 33.6686,
        longitude: 72.9973,
        label: 'G-11، اسلام آباد',
        detail: 'اسلام آباد، پاکستان',
        source: LocationSource.gps,
        refined: true,
      ),
    );
    final tasbeeh = TasbeehController(clock: () => device, feedback: const SilentFeedback());
    await prayer.start();
    await tasbeeh.load();
    return (prayer, tasbeeh);
  }

  /// Unmounts the screen first (it listens to the controllers), then stops
  /// the controllers' clocks, so no timer outlives the test.
  Future<void> finish(WidgetTester tester, PrayerController prayer, TasbeehController tasbeeh) async {
    await tester.pumpWidget(const SizedBox.shrink());
    prayer.dispose();
    tasbeeh.dispose();
  }

  Widget host(PrayerController prayer, TasbeehController tasbeeh, Widget child, {double textScale = 1}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: PrayerScope(
          controller: prayer,
          child: TasbeehScope(
            controller: tasbeeh,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: RepaintBoundary(key: shotKey, child: inner ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
      home: child,
    );
  }

  void phone(WidgetTester tester, {double height = 800}) {
    tester.view.physicalSize = Size(360 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Lets real I/O (asset images) finish, then paints.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    if (previewDir == null) return;
    await tester.runAsync(() async {
      final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(previewDir).createSync(recursive: true);
      File('$previewDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  /// The dashboard exactly as the app mounts it: the fifteen containers, the
  /// slim notice strip above them and the bottom panel below.
  ///
  /// Nothing is installed in a test, which is the honest worst case for the
  /// layout: every section card shows its download mark and the moment card
  /// falls back to its built-in lines.
  Widget homeScreen({LibraryRepository? library}) {
    final repository = library ?? LibraryRepository();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: HomeDashboard(
          library: repository,
          onSearch: () {},
          onOpenData: () {},
        ),
      ),
      bottomNavigationBar: HomeDockBar(
        selected: HomeDockItem.home,
        onSelected: (_) {},
      ),
    );
  }

  for (final (name, hour, minute) in <(String, int, int)>[
    ('dawn', 5, 40),
    ('day', 12, 10),
    ('evening', 16, 45),
    ('night', 21, 5),
  ]) {
    testWidgets('the home dashboard fits a 360 dp phone ($name)', (tester) async {
      phone(tester);
      final (prayer, tasbeeh) = await controllersAt(tester, localTime(hour, minute));
      for (var index = 0; index < 27; index++) {
        tasbeeh.tap();
      }
      await tester.pumpWidget(host(prayer, tasbeeh, homeScreen()));
      await settle(tester);
      // The fifteen containers of the design.
      expect(find.byType(HomeDashboard), findsOneWidget);
      expect(find.text('ShiaVerse'), findsOneWidget);
      expect(find.text('G-11، اسلام آباد'), findsOneWidget);
      expect(find.text('قرآنِ کریم'), findsOneWidget);
      expect(find.text('ترجمہ و تفسیر کے ساتھ'), findsOneWidget);
      expect(find.text('ایک لاکھ کے قریب احادیث'), findsOneWidget);
      expect(find.text('مفاتیح الجنان و صحیفہ سجادیہ'), findsOneWidget);
      expect(find.text('مکمل'), findsOneWidget);
      expect(find.text('نہج البلاغہ'), findsOneWidget);
      expect(find.text('دینی مسائل'), findsOneWidget);
      expect(find.text('احکام و فتاویٰ'), findsOneWidget);
      expect(find.text('پوری لائبریری میں تلاش کریں…'), findsOneWidget);
      expect(find.byType(HomeDockBar), findsOneWidget);
      for (final item in HomeDockItem.values) {
        // احادیث names both the collection card and its dock button.
        expect(find.text(item.label), findsAtLeastNWidgets(1), reason: item.label);
      }
      await shoot(tester, 'home-$name');
      await finish(tester, prayer, tasbeeh);
    });
  }

  testWidgets('the dashboard keeps its shape with a large system font', (tester) async {
    phone(tester);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(13, 30));
    tasbeeh.saveWird(text: 'اللّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ وَآلِ مُحَمَّدٍ وَعَجِّلْ فَرَجَهُمْ', target: 14000);
    for (var index = 0; index < 2345; index++) {
      tasbeeh.tap();
    }
    await tester.pumpWidget(host(prayer, tasbeeh, homeScreen(), textScale: 1.35));
    await settle(tester);
    expect(find.byType(HomeDashboard), findsOneWidget);
    expect(find.text('قرآنِ کریم'), findsOneWidget);
    await shoot(tester, 'home-large-font');
    await finish(tester, prayer, tasbeeh);
  });

  testWidgets('the dashboard fits a short phone without scrolling', (tester) async {
    // 640 dp tall: the whole design still fits, scaled as one piece.
    phone(tester, height: 640);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(18, 20));
    await tester.pumpWidget(host(prayer, tasbeeh, homeScreen()));
    await settle(tester);
    expect(find.byType(HomeDashboard), findsOneWidget);
    expect(find.text('دینی مسائل'), findsOneWidget);
    await shoot(tester, 'home-short');
    await finish(tester, prayer, tasbeeh);
  });

  testWidgets('the bottom panel runs the features behind its five buttons', (tester) async {
    phone(tester);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(10, 0));
    final tapped = <HomeDockItem>[];
    await tester.pumpWidget(host(
      prayer,
      tasbeeh,
      Scaffold(
        bottomNavigationBar: HomeDockBar(
          selected: HomeDockItem.home,
          onSelected: tapped.add,
        ),
      ),
    ));
    await tester.pump();
    for (final item in <HomeDockItem>[HomeDockItem.quran, HomeDockItem.hadith, HomeDockItem.duas, HomeDockItem.more]) {
      await tester.tap(find.text(item.label));
      await tester.pump();
    }
    expect(tapped, <HomeDockItem>[
      HomeDockItem.quran,
      HomeDockItem.hadith,
      HomeDockItem.duas,
      HomeDockItem.more,
    ]);
    await finish(tester, prayer, tasbeeh);
  });

  testWidgets('the tasbeeh dial locks its reset button on a long press', (tester) async {
    phone(tester);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(10, 0));
    tasbeeh.tap();
    await tester.pumpWidget(host(prayer, tasbeeh, homeScreen()));
    await settle(tester);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);

    // If this ever fails again, the reason carries the hit path: which render
    // objects the press actually reached.
    final centre = tester.getCenter(find.byIcon(Icons.restart_alt));
    final path = tester
        .hitTestOnBinding(centre)
        .path
        .take(16)
        .map((entry) => entry.target.runtimeType.toString())
        .join(' > ');

    await tester.longPress(find.byIcon(Icons.restart_alt));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byIcon(Icons.lock),
      findsOneWidget,
      reason: 'the long press locks the reset button; hit path at $centre: $path',
    );
    expect(find.byIcon(Icons.restart_alt), findsNothing);
    expect(tasbeeh.count, 1);

    // The same button is the unlock button now, and a tap only says so.
    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tasbeeh.count, 1);
    expect(find.textContaining('ری سیٹ لاک ہے'), findsWidgets);

    // Long press again: unlocked, and the same button resets.
    await tester.longPress(find.byIcon(Icons.lock));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
    await finish(tester, prayer, tasbeeh);
  });

  testWidgets('the prayer screen fits, top to bottom', (tester) async {
    phone(tester, height: 2600);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(19, 50));
    await tester.pumpWidget(host(prayer, tasbeeh, const PrayerTimesScreen()));
    await settle(tester);
    expect(find.text('نماز کے اوقات'), findsOneWidget);
    await shoot(tester, 'prayer-screen');
    await finish(tester, prayer, tasbeeh);
  });

  testWidgets('the tasbeeh screen fits, with a saved wird and its own count', (tester) async {
    phone(tester, height: 2200);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(10, 0));
    tasbeeh.saveWird(text: 'یا علی مدد', note: 'مولا علی (ع) سے مدد', target: 110);
    tasbeeh.saveWird(text: 'یا حسین', target: 72);
    for (var index = 0; index < 41; index++) {
      tasbeeh.tap();
    }
    await tester.pumpWidget(host(prayer, tasbeeh, const TasbeehScreen()));
    await settle(tester);
    expect(find.text('تعداد (ہدف)'), findsOneWidget);
    await shoot(tester, 'tasbeeh-screen');
    await finish(tester, prayer, tasbeeh);
  });

  testWidgets('Tasbeeh-e-Zahra on the full counter', (tester) async {
    phone(tester, height: 1500);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(13, 0));
    tasbeeh.startZahra();
    for (var index = 0; index < 40; index++) {
      tasbeeh.tap();
    }
    await tester.pumpWidget(host(prayer, tasbeeh, const TasbeehScreen()));
    await settle(tester);
    await shoot(tester, 'tasbeeh-zahra');
    await finish(tester, prayer, tasbeeh);
  });

  testWidgets('the location picker finds towns from the offline list', (tester) async {
    phone(tester);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(11, 0));
    // The list is parsed in a background isolate: let that finish for real.
    final index = await tester.runAsync(CityIndexLoader.load);
    expect(index, isNotNull);
    await tester.pumpWidget(host(prayer, tasbeeh, const Scaffold(body: LocationPickerSheet())));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'chak');
    await settle(tester);
    expect(find.text('چکوال'), findsOneWidget);
    expect(find.text('Chak Jhumra'), findsWidgets);
    await shoot(tester, 'location-picker');
    await finish(tester, prayer, tasbeeh);
  });

  test('the moment card has built-in lines for a phone with no books', () {
    expect(kFallbackMoments.length, greaterThanOrEqualTo(3));
    for (final line in kFallbackMoments) {
      expect(line.kind, anyOf('آیت', 'حدیث'));
      expect(line.arabic.trim(), isNotEmpty);
      expect(line.urdu.trim(), isNotEmpty);
      expect(line.source.trim(), isNotEmpty);
      expect(line.isOpenable, isFalse);
    }
  });
}
