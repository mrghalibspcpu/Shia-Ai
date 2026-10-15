import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// The colours the new utility screens share: cream glass with emerald and
/// gold accents in light mode, smoked glass in dark mode. Every one of the
/// three features (prayer times, Qibla compass, tasbeeh) is painted with this
/// palette so they read as one family with the rest of the dashboard.
class GlassPalette {
  const GlassPalette({
    required this.scaffold,
    required this.fill,
    required this.solid,
    required this.border,
    required this.highlight,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.gold,
    required this.goldSoft,
    required this.shadow,
    required this.track,
  });

  /// Page background the panels sit on.
  final Color scaffold;

  /// Translucent panel fill (the glass).
  final Color fill;

  /// Opaque panel fill, for the few places a blur would be wasteful.
  final Color solid;

  final Color border;

  /// The bright inner edge that makes the glass read as glass.
  final Color highlight;

  final Color ink;
  final Color muted;

  /// Emerald — active states and the Qibla needle.
  final Color accent;

  /// A washed accent for fills behind active text.
  final Color accentSoft;

  final Color gold;
  final Color goldSoft;

  final Color shadow;

  /// Unfilled part of a progress ring or bar.
  final Color track;

  bool get isDark => scaffold.computeLuminance() < 0.4;

  static GlassPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? _dark : _light;
  }

  /// Light mode: `#f4f6f8` page, cream glass, emerald and gold.
  static const GlassPalette _light = GlassPalette(
    scaffold: Color(0xFFF4F6F8),
    fill: Color(0xB8FFFFFF),
    solid: Color(0xFFFDFCF7),
    border: Color(0xE6FFFFFF),
    highlight: Color(0x99FFFFFF),
    ink: Color(0xFF1D2925),
    muted: Color(0xFF6B7A73),
    accent: kForest,
    accentSoft: Color(0x1F145B45),
    gold: Color(0xFFB8862F),
    goldSoft: Color(0x24C59A50),
    shadow: Color(0x1A145B45),
    track: Color(0x1F145B45),
  );

  /// Dark mode keeps the same layout with smoked glass and a lighter emerald.
  static const GlassPalette _dark = GlassPalette(
    scaffold: Color(0xFF101715),
    fill: Color(0xCC18211F),
    solid: Color(0xFF1A2421),
    border: Color(0x14FFFFFF),
    highlight: Color(0x0FFFFFFF),
    ink: Color(0xFFE8EEE8),
    muted: Color(0xFF9AA79F),
    accent: Color(0xFF7AC4A2),
    accentSoft: Color(0x267AC4A2),
    gold: Color(0xFFE4BC70),
    goldSoft: Color(0x26E4BC70),
    shadow: Color(0x66000000),
    track: Color(0x1FFFFFFF),
  );
}

/// A frosted container: translucent fill, hairline border, soft elevation.
///
/// [blur] is deliberately small — a large sigma on a light background turns
/// the text underneath muddy and costs a saveLayer on every frame.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.blur = 14,
    this.fill,
    this.border,
    this.shadow = true,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? fill;
  final Color? border;
  final bool shadow;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final radiusValue = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radiusValue,
        boxShadow: shadow
            ? <BoxShadow>[
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radiusValue,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill ?? palette.fill,
              borderRadius: radiusValue,
              border: Border.all(color: border ?? palette.border, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A small pill, used for chips like the calculation method or the location
/// source. Tappable when [onTap] is given.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.tone,
    this.dense = false,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? tone;
  final bool dense;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final accent = tone ?? palette.accent;
    final foreground = selected ? accent : palette.ink;
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 12,
        vertical: dense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.14) : palette.fill,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.45) : palette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 13 : 15, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 11.5 : 12.5,
              height: 1.1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
    final wrapped = onTap == null
        ? chip
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: chip,
          );
    if (tooltip == null) return wrapped;
    return Tooltip(message: tooltip!, child: wrapped);
  }
}

/// A round, tappable glass button for the action rows.
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
    this.tone,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final Color? tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final accent = tone ?? palette.accent;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GlassPanel(
          radius: 18,
          blur: 10,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          fill: selected ? accent.withValues(alpha: 0.16) : palette.fill,
          border: selected ? accent.withValues(alpha: 0.45) : palette.border,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 22,
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 20, color: selected ? accent : palette.ink),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The section heading the utility screens use.
class GlassSectionHeader extends StatelessWidget {
  const GlassSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
