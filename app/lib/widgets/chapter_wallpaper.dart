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
        child: child,
      ),
    );
  }
}
