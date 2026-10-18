import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../astro/prayer_calculator.dart';
import '../astro/prayer_format.dart';
import '../astro/sky_phase.dart';
import '../library_repository.dart';
import '../models.dart';
import '../reader_navigation.dart';
import '../screens/balagha_screen.dart';
import '../screens/dua_collection_screen.dart';
import '../screens/fatawa_screen.dart';
import '../screens/library_screen.dart' show HadithBooksScreen;
import '../screens/prayer_times_screen.dart';
import '../screens/quran_screen.dart';
import '../screens/tasbeeh_screen.dart';
import '../services/prayer_controller.dart';
import '../services/prayer_scope.dart';
import '../services/tasbeeh_controller.dart';
import 'sky_backdrop.dart';

/// The home dashboard: the fifteen containers of the approved design.
///
/// 1  the vertical **ShiaVerse** rail, 2 the mini prayer card over its animated
/// sky, 3–7 the five collections, 8 **آیت / حدیثِ وقت**, 9 the circular tasbeeh,
/// 10 the search bar, and 11–15 the five buttons of the bottom panel.
///
/// The original arrangement is preserved, but its columns fill the screen's
/// available height. Width-based scaling keeps the proportions on a phone or
/// tablet without leaving an empty band above and below the dashboard.

/// Width-based design units. Height is supplied by the screen, not a fixed
/// canvas: both columns end on the same baseline and start by the status bar.
const double _canvasWidth = 360;
const double _canvasHeight = 610;
const double _pad = 6;
const double _gap = 8;
const double _rowGap = 8;
const double _railWidth = 40;
const double _searchHeight = 46;
const double _rightWidth = 96;

/// The dashboard and its dock share this width cap and the same edge inset.
const double _maxScale = 1.45;

/// One of the five collections on the dashboard — containers 3 to 7 — and
/// where it opens.
enum HomeSection {
  quran(
    'قرآنِ کریم',
    'ترجمہ و تفسیر کے ساتھ',
    Icons.menu_book_rounded,
    Color(0xFF19654C),
    Color(0xFF0A3528),
  ),
  hadith(
    'احادیث',
    'ایک لاکھ کے قریب احادیث',
    Icons.format_quote_rounded,
    Color(0xFF146B70),
    Color(0xFF073B42),
  ),
  duas(
    'مفاتیح الجنان و صحیفہ سجادیہ',
    'مکمل',
    Icons.mosque,
    Color(0xFF135C78),
    Color(0xFF082F44),
  ),
  balagha(
    'نہج البلاغہ',
    'خطبات، خطوط اور حکمت',
    Icons.auto_stories,
    Color(0xFF23563F),
    Color(0xFF0E2E20),
  ),
  fatawa(
    'دینی مسائل',
    'احکام و فتاویٰ',
    Icons.gavel_rounded,
    Color(0xFF4A2260),
    Color(0xFF27103A),
  );

  const HomeSection(this.title, this.slogan, this.icon, this.start, this.end);

  /// The container's heading, exactly as the reader knows the collection.
  final String title;

  /// The one small line under it.
  final String slogan;

  final IconData icon;

  /// The card's own gradient: dark glass, gold hairline, white text.
  final Color start;
  final Color end;

  bool isInstalled(LibraryRepository library) => switch (this) {
        HomeSection.quran => library.isInstalled(BookDefinition.bookFor(CorpusSource.quran)!),
        HomeSection.hadith => BookDefinition.hadithBooks.any(library.isInstalled),
        HomeSection.duas => duaCollectionBooks.any(library.isInstalled),
        HomeSection.balagha => library.isInstalled(BookDefinition.bookFor(CorpusSource.balagha)!),
        HomeSection.fatawa => fatawaBooks.any(library.isInstalled),
      };

  Widget screen(LibraryRepository library, VoidCallback? onOpenData) => switch (this) {
        HomeSection.quran => QuranHomeScreen(library: library),
        HomeSection.hadith => HadithBooksScreen(library: library, onOpenData: onOpenData),
        HomeSection.duas => DuaCollectionScreen(library: library, onOpenData: onOpenData),
        HomeSection.balagha => BalaghaHomeScreen(library: library),
        HomeSection.fatawa => FatawaCollectionScreen(library: library, onOpenData: onOpenData),
      };
}

/// Opens a collection from the dashboard (or from the bottom panel): its own
/// screen when the book is installed, the download screen when it is not.
Future<void> openHomeSection(
  BuildContext context, {
  required LibraryRepository library,
  required HomeSection section,
  VoidCallback? onOpenData,
}) async {
  if (!section.isInstalled(library)) {
    onOpenData?.call();
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => section.screen(library, onOpenData)),
  );
}

/// The collections already have their own side rail. The dock is for the
/// reader's personal tools instead, with English names on every button.
enum HomeDockItem {
  qibla('Qibla', Icons.explore_rounded, Color(0xFF00897B)),
  settings('Settings', Icons.settings_rounded, Color(0xFF19654C)),
  bookmarks('Bookmarks', Icons.bookmark_rounded, Color(0xFF146B70)),
  lastSeen('Last seen', Icons.history_rounded, Color(0xFF135C78)),
  xplore('Xplore', Icons.apps_rounded, Color(0xFF45225C));

  const HomeDockItem(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Large glass icon containers on one true-black dock. Their names remain
/// outside the containers; the black surface also fills the system safe area.
class HomeDockBar extends StatelessWidget {
  const HomeDockBar({super.key, required this.selected, required this.onSelected});

  final HomeDockItem? selected;
  final ValueChanged<HomeDockItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarDividerColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          top: false,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(constraints.maxWidth, _canvasWidth * _maxScale);
                final scale = width / _canvasWidth;
                final iconHeight = 76.0 * math.min(scale, 1.25);
                return Align(
                  heightFactor: 1,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(_pad * scale, 4, _pad * scale, 6),
                      child: SizedBox(
                        height: iconHeight + 24,
                        child: Row(
                          children: <Widget>[
                            for (final item in HomeDockItem.values) ...<Widget>[
                              if (item != HomeDockItem.values.first) const SizedBox(width: 4),
                              Expanded(
                                child: _DockSquare(
                                  item: item,
                                  iconHeight: iconHeight,
                                  selected: item == selected,
                                  onTap: () => onSelected(item),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DockSquare extends StatelessWidget {
  const _DockSquare({
    required this.item,
    required this.iconHeight,
    required this.selected,
    required this.onTap,
  });

  final HomeDockItem item;
  final double iconHeight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('dock-${item.name}'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedContainer(
                key: ValueKey<String>('dock-icon-${item.name}'),
                duration: const Duration(milliseconds: 200),
                height: iconHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const <double>[0, 0.48, 1],
                    colors: <Color>[
                      Color.lerp(item.color, Colors.white, selected ? 0.30 : 0.22)!,
                      item.color.withValues(alpha: 0.96),
                      Color.lerp(item.color, Colors.black, 0.46)!,
                    ],
                  ),
                  border: Border.all(color: palette.goldSoft.withValues(alpha: 0.94), width: selected ? 1.8 : 1.2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: item.color.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5)),
                    const BoxShadow(color: Color(0x65000000), blurRadius: 5, offset: Offset(0, -2)),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const _GlassSheen(radius: 20),
                    Center(child: Icon(item.icon, size: 29, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    key: ValueKey<String>('dock-label-${item.name}'),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: kDigitFont,
                      fontSize: 11.5,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? palette.goldSoft : const Color(0xFFF3F3F3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet specular highlight, inside the rounded surface, makes the side
/// rail, collection tiles and dock keys read as raised frosted glass instead
/// of flat opaque colour. It never intercepts a tap or paints over the label.
class _GlassSheen extends StatelessWidget {
  const _GlassSheen({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _GlassSheenPainter(radius)),
      );
}

class _GlassSheenPainter extends CustomPainter {
  const _GlassSheenPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rounded = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawRect(
      rect,
      Paint()..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: <double>[0, 0.38, 0.68, 1],
        colors: <Color>[
          Color(0x42FFFFFF), Color(0x16FFFFFF), Color(0x00FFFFFF), Color(0x38000000),
        ],
      ).createShader(rect),
    );
    canvas.drawLine(
      Offset(radius * 0.7, 1.6),
      Offset(size.width - radius * 0.7, 1.6),
      Paint()
        ..strokeWidth = 1.4
        ..shader = const LinearGradient(
          colors: <Color>[Color(0x00FFFFFF), Color(0xADFFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 2)),
    );
    canvas.drawArc(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      -math.pi / 4,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0x55FFFFFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassSheenPainter old) => old.radius != radius;
}

/// The same fifteen containers, now filling the available height instead of
/// centring a short drawing in a tall screen.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.library,
    required this.onSearch,
    this.onOpenData,
  });

  final LibraryRepository library;

  /// Opens the search screen: the search bar itself (container 10) lives here
  /// now, and it is the working search, one tap away.
  final VoidCallback onSearch;

  final VoidCallback? onOpenData;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : _canvasWidth;
        final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : _canvasHeight;
        final scale = math.min(
          math.min(availableWidth / _canvasWidth, _maxScale),
          availableHeight / 500,
        );
        final designHeight = availableHeight / scale;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: const ValueKey<String>('home-canvas'),
            width: _canvasWidth * scale,
            height: availableHeight,
            child: FittedBox(
              fit: BoxFit.fill,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: palette.backdrop),
                  child: SizedBox(
                    width: _canvasWidth,
                    height: designHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(_pad),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SizedBox(width: _rightWidth, child: _sectionColumn(context)),
                          const SizedBox(width: _gap),
                          Expanded(child: _leftColumn(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Containers 1, 2, 8, 9 and 10.
  ///
  /// The rows line up with the five collection cards of the right column: the
  /// title rail and the mini prayer card run down to just above the moment
  /// card, whose TOP edge sits level with the TOP edge of the third card
  /// (مفاتیح الجنان و صحیفہ سجادیہ); the tasbeeh dial then sits low in what is
  /// left, resting on the search bar's upper edge.
  Widget _leftColumn(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      // The right column's five cards share this height with four gaps.
      final cardHeight = (height - 4 * _gap) / 5;
      // Two cards and two gaps down is the duas card's top edge; the moment
      // card starts there, so the prayer/title row ends one row-gap above it.
      final prayerHeight = (2 * cardHeight + 2 * _gap - _rowGap).clamp(150.0, height - 180.0).toDouble();
      // The dial is width-limited on tall phones. Give its otherwise-empty
      // space to the moment card, so that card reaches almost to the dial's
      // upper edge without pulling the dial away from the search bar.
      final minimumMoment = (height * 0.12).clamp(60.0, 78.0).toDouble();
      final roomForDial = height - prayerHeight - minimumMoment - 2 * _rowGap - _searchHeight;
      final dialDiameter = math.min(constraints.maxWidth, roomForDial) * 0.99;
      final momentHeight = height - prayerHeight - 2 * _rowGap - _searchHeight - dialDiameter;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: prayerHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _MiniPrayerCard()),
                const SizedBox(width: _gap),
                const SizedBox(width: _railWidth, child: _TitleRail()),
              ],
            ),
          ),
          const SizedBox(height: _rowGap),
          SizedBox(height: momentHeight, child: _MomentCard(library: library)),
          const SizedBox(height: _rowGap),
          // The dial hugs the bottom of its box, so its lower edge meets the
          // search bar's upper edge instead of floating in the middle.
          const Expanded(child: _TasbeehDial()),
          SizedBox(
            key: const ValueKey<String>('home-search'),
            height: _searchHeight,
            child: _SearchPill(onTap: onSearch),
          ),
        ],
      );
    });
  }

  /// Equal-height side cards stretch to the EXACT same baseline as search.
  Widget _sectionColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final section in HomeSection.values) ...<Widget>[
          Expanded(
            child: _SectionCard(
              key: ValueKey<String>('home-section-${section.name}'),
              section: section,
              installed: section.isInstalled(library),
              onTap: () => unawaited(
                openHomeSection(context, library: library, section: section, onOpenData: onOpenData),
              ),
            ),
          ),
          if (section != HomeSection.values.last) const SizedBox(height: _gap),
        ],
      ],
    );
  }
}

/// 1 — the app title rail: the ShiaVerse mark, and the name written down the
/// spine.
class _TitleRail extends StatelessWidget {
  const _TitleRail();

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    return Semantics(
      label: 'ShiaVerse',
      child: Container(
        decoration: BoxDecoration(
          gradient: palette.plum,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: palette.gold, width: 1.2),
          boxShadow: <BoxShadow>[
            BoxShadow(color: palette.plum.colors.last.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const _GlassSheen(radius: 21),
            Column(
              children: <Widget>[
                const SizedBox(height: 9),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.cream,
                    border: Border.all(color: palette.gold, width: 1.2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/shiaverse_icon.png',
                      fit: BoxFit.cover,
                      cacheWidth: 96,
                      cacheHeight: 96,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'ShiaVerse',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: kDigitFont,
                            fontSize: 34,
                            height: 1.1,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: palette.goldSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// White text with a soft shadow, readable on every sky.
TextStyle _onSky(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color color = Colors.white,
  bool digits = false,
  double? height,
}) =>
    TextStyle(
      fontFamily: digits ? kDigitFont : null,
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: color,
      fontFeatures: digits ? const <FontFeature>[FontFeature.tabularFigures()] : null,
      shadows: const <Shadow>[
        Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1)),
      ],
    );

/// 2 — the mini prayer card: the place, the clock, the Hijri date and the five
/// prayers, over the animated sky of the hour.
class _MiniPrayerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = PrayerScope.of(context);
    return ValueListenableBuilder<DateTime>(
      valueListenable: controller.now,
      builder: (context, now, _) {
        final schedule = controller.schedule;
        final window = schedule.window(now);
        final next = schedule.nextEntry(now);
        final running = !window.previousNight && now.isBefore(window.endsAt);
        final prayers = schedule.obligatory;
        return Container(
          key: const ValueKey<String>('home-prayer-card'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DashboardPalette.of(context).gold, width: 1.2),
          ),
          child: SkyBackdrop(
            phase: skyPhaseFor(schedule, now),
            radius: 19,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrayerTimesScreen()),
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  final compact = constraints.maxHeight < 205;
                  Widget prayerRow(Iterable<PrayerEntry> entries) => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final entry in entries)
                        Expanded(
                          child: _MiniPrayerCell(
                            entry: entry,
                            active: running && window.marker == entry.marker,
                            upcoming: !(running && window.marker == entry.marker) && next.marker == entry.marker,
                            remaining: next.marker == entry.marker ? next.time.difference(now) : null,
                          ),
                        ),
                    ],
                  );
                  return Padding(
                    padding: const EdgeInsets.all(7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(height: 22, child: _placeRow(context, controller)),
                        SizedBox(
                          height: compact ? 32 : 46,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              TextSpan(children: <InlineSpan>[
                                TextSpan(
                                  text: formatClockDigitsUrdu(now),
                                  style: _onSky(40, weight: FontWeight.w800, digits: true, height: 1),
                                ),
                                TextSpan(
                                  text: ' ${formatClockSeconds(now)}',
                                  style: _onSky(12, weight: FontWeight.w600, digits: true),
                                ),
                              ]),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 18,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                controller.hijriFor(now).labelUrdu,
                                maxLines: 1,
                                style: _onSky(11.5, weight: FontWeight.w700, color: const Color(0xFFFFE1A1), height: 1.2),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 3 : 8),
                        // The names and times sit against the wallpaper's
                        // lower edge, not in the middle of the spare sky.
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              key: const ValueKey<String>('home-prayer-row'),
                              height: compact ? 52.0 : 64.0,
                              child: prayerRow(prayers),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The place, centred, with the "find me" button at the end of the row.
  Widget _placeRow(BuildContext context, PrayerController controller) {
    return Row(
      children: <Widget>[
        const Icon(Icons.place, size: 11, color: Colors.white),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            controller.loadingLocation ? 'مقام تلاش کیا جا رہا ہے…' : controller.location.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _onSky(11, weight: FontWeight.w700, height: 1.25),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.loadingLocation ? null : () => unawaited(refreshLocationWithFeedback(context)),
          child: Tooltip(
            message: controller.locationProblem?.messageUrdu ?? 'میرا موجودہ مقام معلوم کریں',
            child: Icon(
              controller.loadingLocation
                  ? Icons.sync
                  : (controller.locationProblem != null ? Icons.location_disabled : Icons.my_location),
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// One of the five prayers on the mini card: its name, its time, and either the
/// **Now** tag or the time left until it.
class _MiniPrayerCell extends StatelessWidget {
  const _MiniPrayerCell({
    required this.entry,
    required this.active,
    required this.upcoming,
    this.remaining,
  });

  final PrayerEntry entry;
  final bool active;
  final bool upcoming;
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFE1A1);
    final lit = active || upcoming;
    final left = remaining;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.22)
            : (upcoming ? gold.withValues(alpha: 0.14) : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? Colors.white.withValues(alpha: 0.55)
              : (upcoming ? gold.withValues(alpha: 0.9) : Colors.transparent),
          width: lit ? 1.3 : 1,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              entry.marker.labelUrdu,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: _onSky(11, weight: lit ? FontWeight.w800 : FontWeight.w600, height: 1.2),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatClockDigitsUrdu(entry.time),
                textDirection: TextDirection.ltr,
                style: _onSky(14, weight: FontWeight.w800, digits: true, height: 1, color: upcoming ? gold : Colors.white),
              ),
            ),
            const SizedBox(height: 1),
            SizedBox(
              height: 11,
              child: Center(
                child: active
                    ? const _NowTag()
                    : (left == null
                        ? const SizedBox.shrink()
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatCountdownClock(left),
                              style: _onSky(9, weight: FontWeight.w700, color: gold, digits: true),
                            ),
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small gold **Now** badge on the prayer that is running.
class _NowTag extends StatelessWidget {
  const _NowTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1A1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        'Now',
        maxLines: 1,
        style: TextStyle(
          fontFamily: kDigitFont,
          fontSize: 7.5,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4A2A05),
        ),
      ),
    );
  }
}

/// 8 — **آیت / حدیثِ وقت**: one short verse with its translation, or a short
/// narration from Mizan al-Hikmah, rolled once per app start and changed by the
/// button at its end.
class _MomentCard extends StatefulWidget {
  const _MomentCard({required this.library});

  final LibraryRepository library;

  /// One roll per app start, shared by every rebuild of the home screen. The
  /// list is thrown away when the process ends, which is what "a new line
  /// every time the app opens" means.
  static Future<List<MomentPassage>>? _rolled;

  @override
  State<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<_MomentCard> {
  List<MomentPassage> _lines = const <MomentPassage>[];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_roll());
  }

  Future<void> _roll() async {
    // A fresh install has no books yet (or a book may fail to open): the card
    // falls back to its built-in lines and never shows an empty box.
    final rolled = _MomentCard._rolled ??= widget.library
        .momentPassages(limit: 6)
        .catchError((Object _) => const <MomentPassage>[]);
    final lines = await rolled;
    if (!mounted || lines.isEmpty) return;
    setState(() {
      _lines = lines;
      _index = math.Random().nextInt(lines.length);
    });
  }

  void _next() {
    setState(() => _index++);
  }

  Future<void> _open(MomentPassage line) {
    final book = line.book;
    if (book == null || !line.isOpenable) {
      _next();
      return Future<void>.value();
    }
    return pushReaderFor(
      context,
      library: widget.library,
      book: book,
      recordId: line.recordId,
      sectionId: line.sectionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    final source = _lines.isEmpty ? kFallbackMoments : _lines;
    final line = source[_index % source.length];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(_open(line)),
        child: Ink(
          key: const ValueKey<String>('home-moment-card'),
          padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
          decoration: BoxDecoration(
            gradient: palette.moment,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.gold, width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(color: palette.gold.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            // The tag is written along the card's edge (rotated a quarter
            // turn), and a turned box reads its constraints bottom-up: the
            // row's boxes are laid out from the top.
            verticalDirection: VerticalDirection.up,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _MomentTag(kind: line.kind),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // One line always: a short ayah is still longer than the
                    // card on a small phone, so it scales down instead of
                    // clipping half a word.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        line.arabic,
                        maxLines: 1,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: kArabicFont,
                          fontSize: 12.5,
                          height: 1.35,
                          color: palette.momentInk,
                        ),
                      ),
                    ),
                    Text(
                      line.urdu,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: kUrduFont,
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: palette.momentInk.withValues(alpha: 0.88),
                      ),
                    ),
                    Text(
                      line.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: kUrduFont,
                        fontSize: 9,
                        height: 1.3,
                        color: palette.momentInk.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Center(
                child: Tooltip(
                  message: 'دوسری آیت یا حدیث',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _next,
                    child: Container(
                      width: 26,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.gold.withValues(alpha: 0.6)),
                      ),
                      child: Icon(Icons.chevron_left, size: 20, color: palette.momentInk),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The `آیت` / `حدیث` tag that stands at the start of the moment card.
class _MomentTag extends StatelessWidget {
  const _MomentTag({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    return Container(
      width: 34,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.gold.withValues(alpha: 0.55)),
      ),
      child: RotatedBox(
        quarterTurns: 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            kind,
            maxLines: 1,
            style: TextStyle(
              fontFamily: kUrduFont,
              fontSize: 11.5,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: palette.momentInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// 9 — the circular tasbeeh: the wird in the Arabic face along the top, the
/// count glowing in the middle, **+** on one side, the reset button (long press
/// locks it, and the same button unlocks) on the other, and the expand button
/// that opens the full counter.
class _TasbeehDial extends StatefulWidget {
  const _TasbeehDial();

  /// Remembers the reset lock between sessions: a locked button that forgot
  /// would be no protection at all.
  static const String lockKey = 'tasbeeh_reset_locked';

  @override
  State<_TasbeehDial> createState() => _TasbeehDialState();
}

class _TasbeehDialState extends State<_TasbeehDial> {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLock());
  }

  Future<void> _loadLock() async {
    final prefs = await SharedPreferences.getInstance();
    final locked = prefs.getBool(_TasbeehDial.lockKey) ?? false;
    if (mounted && locked != _locked) setState(() => _locked = locked);
  }

  Future<void> _setLock(bool locked) async {
    setState(() => _locked = locked);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_TasbeehDial.lockKey, locked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(locked ? 'ری سیٹ لاک ہو گیا — کھولنے کے لیے دبا کر رکھیں' : 'ری سیٹ کھل گیا'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _tapReset(TasbeehController controller) {
    if (_locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ری سیٹ لاک ہے — کھولنے کے لیے بٹن دبا کر رکھیں'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    unawaited(confirmTasbeehReset(context, controller));
  }

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    final controller = TasbeehScope.of(context);
    final target = controller.target;
    final arabicWird = !controller.preset.custom || looksArabic(controller.step.arabic);
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(constraints.maxWidth, constraints.maxHeight) * 0.99;
        final radius = diameter / 2;
        final bead = diameter * 0.50;
        final sideButton = diameter * 0.19;
        // Bottom-aligned: the dial sits down against the search bar's top
        // edge, leaving any spare room above it instead of around it.
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox.square(
            key: const ValueKey<String>('home-tasbeeh'),
            dimension: diameter,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DialPainter(palette: palette, progress: controller.progress),
                  ),
                ),
                // The wird, along the top of the dial. Tap it to change it.
                Positioned(
                  top: diameter * 0.065,
                  left: diameter * 0.22,
                  right: diameter * 0.22,
                  child: Tooltip(
                    message: 'ذکر یا ورد بدلیں',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => unawaited(showWirdPicker(context)),
                      child: Text(
                        controller.step.arabic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: arabicWird ? kArabicFont : kUrduFont,
                          fontSize: arabicWird ? 16 : 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: palette.metalInk,
                        ),
                      ),
                    ),
                  ),
                ),
                // The expand button, at the top of the dial's near side.
                Positioned(
                  left: diameter * 0.06,
                  top: diameter * 0.06,
                  child: _DialRoundButton(
                    icon: Icons.open_in_full,
                    tooltip: 'مکمل تسبیح کھولیں',
                    size: diameter * 0.14,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const TasbeehScreen()),
                    ),
                  ),
                ),
                Positioned(
                  left: radius - bead / 2,
                  top: radius - bead / 2,
                  child: _Bead(controller: controller, diameter: bead),
                ),
                Positioned(
                  left: radius - sideButton / 2 - diameter * 0.36,
                  top: radius - sideButton / 2,
                  child: _DialRoundButton(
                    icon: Icons.add,
                    tooltip: 'ایک دانہ (+1)',
                    size: sideButton,
                    filled: true,
                    iconSize: 24,
                    onTap: controller.tap,
                  ),
                ),
                Positioned(
                  right: radius - sideButton / 2 - diameter * 0.36,
                  top: radius - sideButton / 2,
                  child: _DialRoundButton(
                    icon: _locked ? Icons.lock : Icons.restart_alt,
                    tooltip: _locked
                        ? 'ری سیٹ لاک ہے — کھولنے کے لیے دبا کر رکھیں'
                        : 'ری سیٹ (لاک کرنے کے لیے دبا کر رکھیں)',
                    size: sideButton * 0.95,
                    muted: _locked,
                    onTap: () => _tapReset(controller),
                    onLongPress: () => unawaited(_setLock(!_locked)),
                  ),
                ),
                Positioned(
                  left: diameter * 0.14,
                  right: diameter * 0.14,
                  top: diameter * 0.855,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: <Widget>[
                        Text('آج', style: TextStyle(fontFamily: kUrduFont, fontSize: 11, height: 1.3, color: palette.metalInk)),
                        const SizedBox(width: 4),
                        Text(
                          formatCount(controller.dailyTotal),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontFamily: kDigitFont, fontSize: 11, height: 1.1, color: palette.metalInk),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: Container(width: 2, height: 2, decoration: BoxDecoration(color: palette.gold, shape: BoxShape.circle)),
                        ),
                        Text(
                          target == 0 ? 'لامحدود' : '${formatCount(controller.count)} / ${formatCount(target)}',
                          textDirection: target == 0 ? TextDirection.rtl : TextDirection.ltr,
                          style: TextStyle(fontFamily: target == 0 ? kUrduFont : kDigitFont, fontSize: 11, height: 1.1, color: palette.metalInk),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The glowing count in the middle of the dial. Tapping it counts too.
class _Bead extends StatelessWidget {
  const _Bead({required this.controller, required this.diameter});

  final TasbeehController controller;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    return Semantics(
      button: true,
      label: 'تسبیح گنتی ${controller.count}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: controller.tap,
        child: TweenAnimationBuilder<double>(
          key: ValueKey<int>(controller.count),
          tween: Tween<double>(begin: 0.93, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.5),
                radius: 1.1,
                colors: <Color>[
                  Color.lerp(palette.bead, Colors.white, 0.32)!,
                  palette.bead,
                  Color.lerp(palette.bead, Colors.black, 0.55)!,
                ],
                stops: const <double>[0, 0.55, 1],
              ),
              border: Border.all(color: palette.gold, width: 1.6),
              boxShadow: <BoxShadow>[
                BoxShadow(color: palette.gold.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -2),
                const BoxShadow(color: Color(0x66000000), blurRadius: 9, offset: Offset(0, 5)),
                const BoxShadow(color: Color(0xBBFFFFFF), blurRadius: 2, offset: Offset(-1, -2)),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: EdgeInsets.all(diameter * 0.14),
                child: Text(
                  formatCount(controller.count),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: kDigitFont,
                    fontSize: diameter * 0.42,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF4F8FF),
                    shadows: const <Shadow>[
                      Shadow(color: Color(0xCCFFFFFF), blurRadius: 16),
                      Shadow(color: Color(0x99B9A2FF), blurRadius: 26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dial's face: a brushed-metal disc with a gold rim, the turning marks of
/// a real bead frame, and the progress ring around the bead.
class _DialPainter extends CustomPainter {
  _DialPainter({required this.palette, required this.progress});

  final DashboardPalette palette;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    // A real cast shadow, not a glow: the dial sits above the white page.
    final outline = Path()..addOval(Rect.fromCircle(center: centre, radius: radius - 5));
    canvas.drawShadow(outline.shift(const Offset(0, 5)), const Color(0x88000000), 8, true);
    canvas.drawCircle(
      centre,
      radius - 2,
      Paint()..shader = const SweepGradient(
        colors: <Color>[
          Color(0xFF8C9298), Color(0xFFF9FCFF), Color(0xFFCBD1D6),
          Color(0xFF6E7882), Color(0xFFEFF4F6), Color(0xFF8C9298),
        ],
        stops: <double>[0, 0.20, 0.38, 0.62, 0.83, 1],
      ).createShader(rect),
    );
    canvas.drawCircle(
      centre,
      radius - 9,
      Paint()..shader = palette.metal.createShader(rect),
    );
    canvas.drawCircle(
      centre,
      radius - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = SweepGradient(colors: <Color>[
          palette.gold, palette.goldSoft, palette.gold,
          Color.lerp(palette.gold, Colors.black, 0.45)!, palette.gold,
        ]).createShader(rect),
    );
    canvas.drawCircle(
      centre,
      radius - 9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x88000000), Color(0xCCFFFFFF)],
        ).createShader(rect),
    );
    // Fine turning marks and engraved minute/bead ticks catch the light.
    final marks = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..color = Colors.white.withValues(alpha: 0.24);
    for (var r = radius * 0.54; r < radius - 11; r += 2.5) {
      canvas.drawCircle(centre, r, marks);
    }
    for (var index = 0; index < 60; index++) {
      final angle = index * math.pi / 30;
      final outer = radius - 13;
      final inner = outer - (index % 5 == 0 ? 5 : 2);
      canvas.drawLine(
        centre + Offset(math.cos(angle), math.sin(angle)) * inner,
        centre + Offset(math.cos(angle), math.sin(angle)) * outer,
        Paint()
          ..strokeWidth = index % 5 == 0 ? 1.2 : 0.7
          ..color = palette.metalInk.withValues(alpha: index % 5 == 0 ? 0.36 : 0.18),
      );
    }

    // How far today's wird has come, hugging the bead.
    final ring = radius * 0.68;
    canvas.drawCircle(
      centre,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = palette.sunken,
    );
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: ring),
      -math.pi / 2,
      math.max(0.02, progress) * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.2
        ..color = palette.gold,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress || old.palette != palette;
}

/// A round button on the dial: cream with a gold ring, or filled emerald.
class _DialRoundButton extends StatelessWidget {
  const _DialRoundButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onTap,
    this.onLongPress,
    this.filled = false,
    this.muted = false,
    this.iconSize,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback onTap;

  /// Long press: the reset button locks (and unlocks) with it.
  final VoidCallback? onLongPress;

  final bool filled;
  final bool muted;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    return _maybeTooltip(
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: filled
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[const Color(0xFF1E7A5E), kForestDark],
                      )
                    : null,
                color: filled ? null : palette.cream,
                border: Border.all(color: palette.gold, width: filled ? 1.6 : 1.3),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: filled ? 0.24 : 0.14),
                    blurRadius: filled ? 10 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize ?? size * 0.52,
                  color: filled
                      ? Colors.white
                      : (muted ? palette.metalInk.withValues(alpha: 0.45) : palette.metalInk),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Every button except the one that owns the long press gets a tooltip: a
  /// tooltip carries its own long-press recognizer, and two recognizers for one
  /// gesture is how a long press gets swallowed.
  Widget _maybeTooltip({required Widget child}) {
    final long = onLongPress;
    if (long == null) return Tooltip(message: tooltip, child: child);
    // The long press is claimed by exactly one recognizer, wrapped *around*
    // the button, so the tap inside it stays the InkWell's and nothing else
    // can take the press away from the button the reader is holding.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: long,
      child: child,
    );
  }
}

/// 10 — the search bar, moved off the bottom panel. It opens the working
/// search screen with the keyboard already up.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    final height = _searchHeight;
    return Semantics(
      button: true,
      label: 'تلاش',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: palette.search,
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: palette.gold, width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(color: palette.gold.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: height - 8,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: AlignmentDirectional.centerStart,
                      decoration: BoxDecoration(
                        color: palette.cream,
                        borderRadius: BorderRadius.circular((height - 8) / 2),
                      ),
                      child: Text(
                        'پوری لائبریری میں تلاش کریں…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: kUrduFont,
                          fontSize: 11.5,
                          height: 1.3,
                          color: palette.creamInk,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: height - 8,
                    height: height - 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[palette.goldSoft, palette.gold],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    child: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF3A2708)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the five collection cards (3–7): its mark, its name and its one line.
/// A collection whose books are not installed shows the download mark and opens
/// the data screen instead.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.installed,
    required this.onTap,
  });

  final HomeSection section;
  final bool installed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    return Semantics(
      button: true,
      label: section.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const <double>[0, 0.48, 1],
                colors: <Color>[
                  Color.lerp(section.start, Colors.white, 0.18)!,
                  section.start.withValues(alpha: 0.95),
                  Color.lerp(section.end, Colors.black, 0.20)!,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.goldSoft.withValues(alpha: 0.9), width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(color: section.end.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: _GlassSheen(radius: 18)),
                if (!installed)
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Icon(Icons.download_rounded, size: 12, color: palette.goldSoft),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                  child: LayoutBuilder(builder: (context, constraints) => Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Center(
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: palette.goldSoft.withValues(alpha: 0.65)),
                                ),
                                child: Icon(section.icon, size: 17, color: palette.goldSoft),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              section.title,
                              maxLines: 3,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: kUrduFont,
                                fontSize: 17.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: palette.onDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              section.slogan,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: kUrduFont,
                                fontSize: 12,
                                height: 1.25,
                                color: palette.onDarkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
