import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import 'glass_panel.dart';

/// The four daily-utility sections — تسبیح و ذکر, قبلہ نما, چاند کی رویت and
/// اسلامی تقویم — share one **container** wallpaper per section.
///
/// The photograph is no longer painted behind the page. It is published through
/// [SectionWallpaper] and every [GlassPanel] below paints it as its own
/// background, which is what readers asked for ("container ke andar"). The page
/// keeps a calm, dark backdrop so the glass edges still read, and the dark
/// palette keeps every label's contrast exactly as before.
class SectionBackground extends StatelessWidget {
  const SectionBackground({
    super.key,
    required this.asset,
    required this.builder,
    this.dim = 0.52,
  });

  /// Bundled wallpaper (`assets/images/wall_*.jpg`) handed to each panel.
  final String asset;

  /// The page itself. It is built INSIDE the dark theme, so
  /// `GlassPalette.of(context)` returns the dark glass palette and every panel
  /// is legible in both app themes.
  final WidgetBuilder builder;

  /// 0…1 — retained for call sites; it now tunes the page backdrop's depth.
  final double dim;

  @override
  Widget build(BuildContext context) {
    final depth = dim.clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0B1B14),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: DecoratedBox(
        key: ValueKey<String>('section-backdrop-$asset'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(const Color(0xFF0E1A15), const Color(0xFF050B09), depth)!,
              Color.lerp(const Color(0xFF12251D), const Color(0xFF0A1611), depth)!,
            ],
          ),
        ),
        child: Theme(
          data: buildDarkTheme().copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: SectionWallpaper(
            asset: asset,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }
}
