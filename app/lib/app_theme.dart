import 'package:flutter/material.dart';

import 'models.dart';

const Color kForest = Color(0xFF145B45);
const Color kForestDark = Color(0xFF0E3B34);
const Color kGold = Color(0xFFC59A50);
const Color kInk = Color(0xFF1D2925);
const String kUrduFont = 'JameelNooriNastaleeq';
const String kArabicFont = 'Amiri';

/// English digits on the prayer card, the Qibla compass and the tasbeeh: the
/// Nastaliq face draws Latin numerals small, so numbers use the system sans.
const String kDigitFont = 'sans-serif';

/// One vivid colour per book. The home screen paints every book's icon in its
/// own colour, and the same colour follows the book into the bottom panel.
const List<Color> kBookPalette = <Color>[
  Color(0xFF1B7F5B), // green
  Color(0xFFD9466B), // rose
  Color(0xFF2F6FD6), // blue
  Color(0xFFE08A1E), // amber
  Color(0xFF7B4FD0), // violet
  Color(0xFF0E9AA7), // teal
  Color(0xFFC2452D), // brick
  Color(0xFF5B8C2A), // olive
  Color(0xFF3D5AFE), // indigo
  Color(0xFFB8860B), // dark gold
  Color(0xFF00897B), // emerald
  Color(0xFFAD1457), // plum
  Color(0xFF6D4C41), // brown
  Color(0xFF455A64), // slate
  Color(0xFF8E24AA), // purple
  Color(0xFF039BE5), // sky
  Color(0xFF7CB342), // lime
  Color(0xFFEF6C00), // orange
  Color(0xFF546E7A), // steel
  Color(0xFFC0CA33), // yellow-green
];

/// The icon colour of [book]: its position in the library, so neighbours in
/// the grid never share a colour.
Color bookAccent(BookDefinition book) {
  final index = BookDefinition.all.indexWhere((item) => item.key == book.key);
  return kBookPalette[(index < 0 ? 0 : index) % kBookPalette.length];
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kForest,
    primary: kForest,
    secondary: kGold,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Light is the default look: a plain white page with coloured icons.
    scaffoldBackgroundColor: Colors.white,
    fontFamily: kUrduFont,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kInk,
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kForest.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: kUrduFont,
          fontSize: 12,
          color: states.contains(WidgetState.selected) ? kForest : Colors.black54,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE7E2D8), thickness: 0.8),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kForest,
    brightness: Brightness.dark,
    primary: const Color(0xFF7AC4A2),
    secondary: const Color(0xFFE4BC70),
    surface: const Color(0xFF18211F),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF101715),
    fontFamily: kUrduFont,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101715),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A2421),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A2421),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class ReaderPalette {
  const ReaderPalette({
    required this.background,
    required this.foreground,
    required this.name,
    required this.key,
  });

  final Color background;
  final Color foreground;
  final String name;
  final String key;

  static const paper = ReaderPalette(
    background: Color(0xFFFFFEFA),
    foreground: Color(0xFF252721),
    name: 'کاغذی',
    key: 'paper',
  );
  static const sepia = ReaderPalette(
    background: Color(0xFFF3E8D1),
    foreground: Color(0xFF3F3322),
    name: 'سیپیا',
    key: 'sepia',
  );
  static const night = ReaderPalette(
    background: Color(0xFF171E1C),
    foreground: Color(0xFFE5E7DC),
    name: 'رات',
    key: 'night',
  );

  static const List<ReaderPalette> all = [paper, sepia, night];

  static ReaderPalette fromName(String? name) => switch (name) {
        'sepia' => sepia,
        'night' => night,
        _ => paper,
      };
}

class JustifiedText extends StatelessWidget {
  const JustifiedText(
    this.text, {
    super.key,
    this.arabic = false,
    this.style,
    this.maxLines,
    this.selectable = false,
  });

  final String text;
  final bool arabic;
  final TextStyle? style;
  final int? maxLines;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final resolved = (arabic
            ? const TextStyle(fontFamily: kArabicFont, height: 1.7, letterSpacing: 0)
            : const TextStyle(fontFamily: kUrduFont, height: 1.55))
        .merge(style);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: selectable
          ? SelectableText(
              text,
              textAlign: TextAlign.justify,
              maxLines: maxLines,
              style: resolved,
            )
          : Text(
              text,
              textAlign: TextAlign.justify,
              maxLines: maxLines,
              overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
              style: resolved,
            ),
    );
  }
}

TextDirection directionFor(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x0600 && rune <= 0x08FF) || (rune >= 0xFB50 && rune <= 0xFEFF)) {
      return TextDirection.rtl;
    }
  }
  return TextDirection.ltr;
}
