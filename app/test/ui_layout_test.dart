import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_ai/app_theme.dart';
import 'package:shia_ai/screens/prayer_times_screen.dart';
import 'package:shia_ai/screens/tasbeeh_screen.dart';
import 'package:shia_ai/services/alerts.dart';
import 'package:shia_ai/services/city_index.dart';
import 'package:shia_ai/services/prayer_controller.dart';
import 'package:shia_ai/services/prayer_locations.dart';
import 'package:shia_ai/services/prayer_scope.dart';
import 'package:shia_ai/services/tasbeeh_controller.dart';
import 'package:shia_ai/widgets/home_utilities.dart';

/// Layout checks for the 1.9 screens on a small (360 dp) phone, with the
/// app's real fonts: any overflow fails the test. When
/// `SHIAVERSE_PREVIEW_DIR` is set (CI does), each screen is also saved as a
/// PNG so the layout can be looked at without a device.
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

  Widget homeScreen() => Scaffold(
        appBar: AppBar(title: const Text('ShiaVerse')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: const <Widget>[
            SizedBox(height: 4),
            HomePrayerBanner(),
            SizedBox(height: 12),
            HomeUtilityRow(),
          ],
        ),
      );

  for (final (name, hour, minute) in <(String, int, int)>[
    ('dawn', 5, 40),
    ('day', 12, 10),
    ('evening', 16, 45),
    ('night', 21, 5),
  ]) {
    testWidgets('home prayer card and utility row fit a 360 dp phone ($name)', (tester) async {
      phone(tester);
      final (prayer, tasbeeh) = await controllersAt(tester, localTime(hour, minute));
      for (var index = 0; index < 27; index++) {
        tasbeeh.tap();
      }
      await tester.pumpWidget(host(prayer, tasbeeh, homeScreen()));
      await settle(tester);
      expect(find.byType(HomePrayerBanner), findsOneWidget);
      expect(find.text('G-11، اسلام آباد'), findsOneWidget);
      await shoot(tester, 'home-$name');
      await finish(tester, prayer, tasbeeh);
    });
  }

  testWidgets('home cards survive a large system font', (tester) async {
    phone(tester);
    final (prayer, tasbeeh) = await controllersAt(tester, localTime(13, 30));
    tasbeeh.saveWird(text: 'اللّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ وَآلِ مُحَمَّدٍ وَعَجِّلْ فَرَجَهُمْ', target: 14000);
    for (var index = 0; index < 2345; index++) {
      tasbeeh.tap();
    }
    await tester.pumpWidget(host(prayer, tasbeeh, homeScreen(), textScale: 1.35));
    await settle(tester);
    await shoot(tester, 'home-large-font');
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
}
