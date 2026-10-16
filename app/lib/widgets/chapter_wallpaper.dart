import 'package:flutter/material.dart';

/// The parchment belongs to chapter *name containers*, never the reading page.
/// Ink paints the image on the Card's Material, below ListTile's ripple; an
/// Image/Stack above the tile would make the tile look tappable but hide ink.
class ChapterWallpaperCard extends StatelessWidget {
  const ChapterWallpaperCard({super.key, required this.child});

  static const asset = 'assets/images/chapter_wallpaper.jpg';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage(asset),
            fit: BoxFit.cover,
            // Dark theme must keep its light text readable on the parchment.
            colorFilter: dark
                ? const ColorFilter.mode(Color(0xFF19231F), BlendMode.multiply)
                : const ColorFilter.mode(Color(0x1AFFFFFF), BlendMode.lighten),
          ),
        ),
        child: child,
      ),
    );
  }
}
