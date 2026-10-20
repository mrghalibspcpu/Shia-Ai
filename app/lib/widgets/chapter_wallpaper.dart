import 'package:flutter/material.dart';

/// Chapter *name containers* carry a wallpaper in BOTH themes: warm parchment
/// by day and a deep emerald night manuscript in dark theme (its own painting,
/// not just a darkened parchment), so white text stays readable on it.
class ChapterWallpaperCard extends StatelessWidget {
  const ChapterWallpaperCard({super.key, required this.child});

  static const asset = 'assets/images/chapter_wallpaper.jpg';
  static const darkAsset = 'assets/images/chapter_wallpaper_dark.jpg';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(dark ? darkAsset : asset),
            fit: BoxFit.cover,
            colorFilter: dark
                ? const ColorFilter.mode(Color(0xB319231F), BlendMode.darken)
                : const ColorFilter.mode(Color(0x1AFFFFFF), BlendMode.lighten),
          ),
        ),
        child: DecoratedBox(
          // A jewel-toned wash (plum -> teal -> gold) over the manuscript, so
          // chapter containers feel rich and festive instead of flat green,
          // in both themes, while the wallpaper still shows through.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? <Color>[
                      const Color(0xFF241038).withValues(alpha: 0.55),
                      const Color(0xFF0B3B42).withValues(alpha: 0.45),
                      const Color(0xFF3A2A08).withValues(alpha: 0.50),
                    ]
                  : <Color>[
                      const Color(0xFF7B4FD0).withValues(alpha: 0.14),
                      const Color(0xFF0E9AA7).withValues(alpha: 0.12),
                      const Color(0xFFC59A50).withValues(alpha: 0.16),
                    ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
