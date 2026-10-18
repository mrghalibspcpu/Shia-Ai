import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';

/// The four daily-utility sections — تسبیح و ذکر, قبلہ نما, چاند کی رویت and
/// اسلامی تقویم — share one full-page wallpaper instead of a flat colour.
///
/// The image is painted edge to edge behind `child`; a vertical scrim keeps
/// every glass panel and every line of text readable in both themes, and the
/// status-bar icons are forced light because the wallpaper is always dark.
/// The page's own [Scaffold] must use a transparent background (the screens
/// pass `Colors.transparent`); nothing else about their layout changes.
class SectionBackground extends StatelessWidget {
  const SectionBackground({
    super.key,
    required this.asset,
    required this.builder,
    this.dim = 0.52,
  });

  /// Bundled wallpaper (`assets/images/wall_*.jpg`).
  final String asset;

  /// The page itself. It is built INSIDE the dark theme and the wallpaper
  /// stack, so `GlassPalette.of(context)` returns the dark glass palette and
  /// every panel is legible over the photograph even in the light theme.
  final WidgetBuilder builder;

  /// 0…1 — how much of the wallpaper's brightness is taken away behind the
  /// content. 0.45 keeps a bright wallpaper calm; the night skies use less.
  final double dim;

  @override
  Widget build(BuildContext context) {
    final top = Colors.black.withValues(alpha: (dim * 0.55).clamp(0.0, 1.0));
    final bottom = Colors.black.withValues(alpha: dim.clamp(0.0, 1.0));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0B1B14),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            asset,
            key: ValueKey<String>('section-background-$asset'),
            fit: BoxFit.cover,
            // 900 px is more than a 360 dp phone needs at 3× and keeps the
            // decoded bitmap at ~5 MB instead of the full 1600 px file.
            cacheWidth: 900,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0F2A1E)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[top, bottom],
              ),
            ),
          ),
          // The wallpaper is always a dark, photographic page. These four
          // sections therefore use the same dark glass panels in both app
          // themes, so the wallpaper is genuinely visible instead of being
          // covered by a near-opaque light scrim, and every label keeps the
          // contrast it had before.
          Theme(
            data: buildDarkTheme().copyWith(scaffoldBackgroundColor: Colors.transparent),
            child: Builder(builder: builder),
          ),
        ],
      ),
    );
  }
}
