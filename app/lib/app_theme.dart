import 'package:flutter/material.dart';

const Color kForest = Color(0xFF145B45);
const Color kForestDark = Color(0xFF0E3B34);
const Color kGold = Color(0xFFC59A50);
const Color kInk = Color(0xFF1D2925);
const String kUrduFont = 'JameelNooriNastaleeq';
const String kArabicFont = 'Amiri';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kForest,
    primary: kForest,
    secondary: kGold,
    surface: const Color(0xFFFFFCF6),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7F5EF),
    fontFamily: kUrduFont,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F5EF),
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
  const ReaderPalette({required this.background, required this.foreground, required this.name});

  final Color background;
  final Color foreground;
  final String name;

  static const paper = ReaderPalette(
    background: Color(0xFFFFFEFA),
    foreground: Color(0xFF252721),
    name: 'کاغذی',
  );
  static const sepia = ReaderPalette(
    background: Color(0xFFF3E8D1),
    foreground: Color(0xFF3F3322),
    name: 'سیپیا',
  );
  static const night = ReaderPalette(
    background: Color(0xFF171E1C),
    foreground: Color(0xFFE5E7DC),
    name: 'رات',
  );

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
  });

  final String text;
  final bool arabic;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        textAlign: TextAlign.justify,
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
        style: (arabic
                ? const TextStyle(fontFamily: kArabicFont)
                : const TextStyle(fontFamily: kUrduFont))
            .merge(style),
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

bool hasArabicScript(String text) => directionFor(text) == TextDirection.rtl;
