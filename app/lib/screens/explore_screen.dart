import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/more_features.dart';
import '../widgets/reading_hub.dart';

/// Full-screen Xplore dashboard.
///
/// The page is the camera-lens plate of the reference artwork, in portrait:
/// six amber lenses on a brushed-metal body, the sixth destination on a red
/// bevel plate hanging off the left edge, and the red plate in the bottom-right
/// corner that carries the radial-menu button. Lens one sits top-left, lens two
/// steps down towards the middle, three reaches the right edge, four comes back
/// to the centre, five closes at the bottom-left — the same diagonal climb as
/// the artwork, so the controls read as a machine and not as a grid.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.features,
    required this.onAction,
    required this.onHubVisibilityChanged,
    required this.routeObserver,
  });

  final List<MoreFeature> features;
  final ValueChanged<HubDestination> onAction;
  final ValueChanged<bool> onHubVisibilityChanged;
  final RouteObserver<PageRoute<dynamic>> routeObserver;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with RouteAware {
  bool _menuOpen = false;
  PageRoute<dynamic>? _subscribedRoute;

  MoreFeature? _feature(String title) {
    for (final feature in widget.features) {
      if (feature.title == title) return feature;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) widget.routeObserver.unsubscribe(this);
      _subscribedRoute = route;
      widget.routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() => widget.onHubVisibilityChanged(true);

  @override
  void didPopNext() => widget.onHubVisibilityChanged(true);

  @override
  void didPushNext() => widget.onHubVisibilityChanged(false);

  @override
  void didPop() => widget.onHubVisibilityChanged(false);

  @override
  void dispose() {
    widget.routeObserver.unsubscribe(this);
    widget.onHubVisibilityChanged(false);
    super.dispose();
  }

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  void _selectDestination(HubDestination destination) {
    setState(() => _menuOpen = false);
    widget.onAction(destination);
  }

  @override
  Widget build(BuildContext context) {
    final tasbeeh = _feature('تسبیح و ذکر');
    final prayer = _feature('نماز کے اوقات');
    final crescent = _feature('چاند کی رویت');
    final calendar = _feature('اسلامی تقویم');
    final extra = _feature('Xplore Xtra');
    final encyclopedia = _feature('اثنا عشری انسائکلوپیڈیا');

    return Scaffold(
      backgroundColor: const Color(0xFF0B1218),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _MachineBody(),
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              // Lens diameter: about 40% of the width on a phone, and never so
              // tall that the five lenses plus the corner plates stop fitting.
              final lens = math.min(width * 0.40, height * 0.20);
              final anchor = Offset(width * 0.855, height - math.min(64.0, lens * 0.5));

              Widget at(Offset centre, double diameter, Widget child) => Positioned(
                    left: centre.dx - diameter / 2,
                    top: centre.dy - diameter / 2,
                    width: diameter,
                    height: diameter,
                    child: child,
                  );

              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  _TopBar(onBack: () => Navigator.maybePop(context)),
                  at(
                    Offset(width * 0.20, height * 0.155),
                    lens,
                    _LensControl(
                      number: 1,
                      title: 'تسبیح',
                      subtitle: 'تسبیح و ذکر',
                      icon: Icons.fingerprint_rounded,
                      accent: const Color(0xFFE9A05A),
                      feature: tasbeeh,
                    ),
                  ),
                  at(
                    Offset(width * 0.505, height * 0.335),
                    lens * 1.08,
                    _LensControl(
                      number: 2,
                      title: 'نماز',
                      subtitle: 'اوقات و قرات',
                      icon: Icons.access_time_filled_rounded,
                      accent: const Color(0xFF6FBDB8),
                      feature: prayer,
                    ),
                  ),
                  at(
                    Offset(width * 0.795, height * 0.505),
                    lens * 0.94,
                    _LensControl(
                      number: 3,
                      title: 'چاند کی رویت',
                      subtitle: 'رویتِ ہلال',
                      icon: Icons.nightlight_round,
                      accent: const Color(0xFFB5A7EC),
                      feature: crescent,
                    ),
                  ),
                  at(
                    Offset(width * 0.515, height * 0.675),
                    lens,
                    _LensControl(
                      number: 4,
                      title: 'اسلامی تقویم',
                      subtitle: 'ہجری تاریخیں',
                      icon: Icons.calendar_month_rounded,
                      accent: const Color(0xFF7FC7A7),
                      feature: calendar,
                    ),
                  ),
                  at(
                    Offset(width * 0.215, height * 0.838),
                    lens * 0.88,
                    _LensControl(
                      number: 5,
                      title: 'Xplore Xtra',
                      subtitle: 'روزانہ مطالعہ',
                      icon: Icons.auto_awesome_rounded,
                      accent: const Color(0xFFEBC06B),
                      feature: extra,
                    ),
                  ),
                  Positioned(
                    left: -lens * 0.16,
                    top: height * 0.435 - lens * 0.44,
                    width: lens * 0.92,
                    height: lens * 0.92,
                    child: _RedPlate(
                      icon: Icons.menu_book_rounded,
                      title: 'اثنا عشری انسائکلوپیڈیا',
                      subtitle: 'ائمہ، عقائد، تاریخ',
                      tint: const Color(0xFF7E2731),
                      feature: encyclopedia,
                    ),
                  ),
                  Positioned(
                    right: -lens * 0.12,
                    bottom: math.max(4.0, height * 0.012),
                    width: lens * 1.02,
                    height: lens * 0.78,
                    child: _LaunchPlate(
                      open: _menuOpen,
                      onTap: _toggleMenu,
                      width: width,
                    ),
                  ),
                  if (_menuOpen)
                    Positioned.fill(
                      child: _RadialMenu(
                        anchor: anchor,
                        onSelect: _selectDestination,
                        onDismiss: _toggleMenu,
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// The brand plate and the back button, painted over the top of the metal.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: SizedBox(
          height: 62,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 8,
                top: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: .06),
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0x66C9D4DA), width: 1),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onBack,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 21),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 9, 18, 11),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFFAA2B35), Color(0xFF5E1620)],
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
                    border: Border(
                      left: BorderSide(color: Color(0x88FF9B94), width: 1.2),
                      bottom: BorderSide(color: Color(0x88FF9B94), width: 1.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Xplore',
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 21,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by ShiaVerse',
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 10.5,
                          letterSpacing: 1.1,
                          color: Colors.white.withValues(alpha: .78),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// One camera lens: a knurled metal barrel, an amber glass element, and the
/// destination engraved on a dark disc at the centre.
class _LensControl extends StatelessWidget {
  const _LensControl({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.feature,
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final MoreFeature? feature;

  /// Whether [title] is painted on one line inside the engraving at [size].
  bool _fitsOneLine(BuildContext context, double size, double disc) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(fontSize: size * 0.098, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: disc * 0.80);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines <= 1;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title — $subtitle',
      child: LayoutBuilder(builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final glass = size * 0.74;
        final disc = size * 0.55;
        // A two-line title already fills the engraving; the subtitle would
        // collide with it, so it is dropped and only the title is shown.
        final singleLine = _fitsOneLine(context, size, disc);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: feature?.onOpen,
            child: Ink(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C7A83), Color(0xFF39454C), Color(0xFF171F25)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0xCC05090C), blurRadius: 22, offset: Offset(0, 10)),
                  BoxShadow(color: Color(0x33FFFFFF), blurRadius: 4, offset: Offset(-2, -3)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(painter: _BarrelPainter(accent: accent)),
                  ),
                  Container(
                    width: glass,
                    height: glass,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-.35, -.45),
                        radius: .95,
                        colors: <Color>[
                          const Color(0xFFE9A25A),
                          const Color(0xFFC67424),
                          const Color(0xFF6E3A10),
                          const Color(0xFF241109),
                          const Color(0xFF0A0D0F),
                        ],
                        stops: const <double>[0, .32, .58, .82, 1],
                      ),
                      border: Border.all(color: const Color(0x88707C83), width: size * 0.018),
                      boxShadow: const [
                        BoxShadow(color: Color(0xB3000000), blurRadius: 10, offset: Offset(0, 4)),
                        BoxShadow(color: Color(0x66FFC071), blurRadius: 16, spreadRadius: 1),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(painter: _GlassPainter(accent: accent, discRatio: disc / size)),
                  ),
                  SizedBox(
                    width: disc,
                    height: disc,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, color: accent, size: size * 0.145),
                        SizedBox(height: size * 0.035),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: disc * 0.10),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: size * 0.098,
                              height: 1.22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
                            ),
                          ),
                        ),
                        if (size > 96 && singleLine) ...<Widget>[
                          SizedBox(height: size * 0.016),
                          SizedBox(
                            width: disc * 0.82,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: size * 0.07,
                                  color: const Color(0xFFDDCCC2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // An engraved control number on the barrel, as on the body.
                  Positioned(
                    top: size * 0.055,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: size * 0.05, vertical: size * 0.008),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size),
                        color: const Color(0x99121A20),
                        border: Border.all(color: const Color(0x55D9C3A6), width: .8),
                      ),
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: size * 0.085,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE7D8C4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A bevel plate in the body's red: same destinations as a lens, different
/// material. Used for the encyclopaedia at the left edge.
class _RedPlate extends StatelessWidget {
  const _RedPlate({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.feature,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final MoreFeature? feature;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title — $subtitle',
      child: Transform.rotate(
        angle: -0.07,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: feature?.onOpen,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color.lerp(tint, Colors.white, .22)!, tint, const Color(0xFF2A0D12)],
                ),
                border: Border.all(color: const Color(0x99FFA29A), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0xCC05090C), blurRadius: 18, offset: Offset(0, 9)),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(painter: _HatchPainter(color: const Color(0x33FFFFFF))),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, color: const Color(0xFFFFE1CE), size: 26),
                        const SizedBox(height: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontSize: 10, color: Color(0xFFFFD9C9)),
                          ),
                        ),
                      ],
                    ),
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

/// The bottom-right red plate. It holds the round radial-menu button, and is
/// the only place in the app where that button lives inside Xplore.
class _LaunchPlate extends StatelessWidget {
  const _LaunchPlate({required this.open, required this.onTap, required this.width});

  final bool open;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? 'مینو بند کریں' : 'مینو کھولیں',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30)),
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(30)),
              gradient: LinearGradient(
                begin: Alignment.bottomRight,
                end: Alignment.topLeft,
                colors: [Color(0xFF42121A), Color(0xFF8B2635), Color(0xFFB43643)],
              ),
              border: Border(
                top: BorderSide(color: Color(0x88FFA29A), width: 1.2),
                left: BorderSide(color: Color(0x88FFA29A), width: 1.2),
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(painter: _HatchPainter(color: const Color(0x22FFFFFF))),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _RadialButton(open: open, size: math.min(66.0, width * 0.17)),
                      const SizedBox(height: 7),
                      Text(
                        open ? 'مینو بند کریں' : 'Radial menu',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFE3D6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The logo button that opens the radial menu — the same affordance as the
/// app-wide hub, redrawn in this plate's language.
class _RadialButton extends StatefulWidget {
  const _RadialButton({required this.open, required this.size});

  final bool open;
  final double size;

  @override
  State<_RadialButton> createState() => _RadialButtonState();
}

class _RadialButtonState extends State<_RadialButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant _RadialButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) {
      if (widget.open) {
        _spin.forward();
      } else {
        _spin.reverse();
      }
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, child) {
        final turn = Curves.easeOutCubic.transform(_spin.value);
        return Transform.rotate(
          angle: turn * math.pi * 0.25,
          child: Opacity(opacity: 1 - turn * 0.05, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-.35, -.4),
            colors: [Color(0xFF5FD0A6), Color(0xFF1B6B52), Color(0xFF0B2D23)],
            stops: [0, .62, 1],
          ),
          border: Border.all(color: const Color(0xFFD9FFEF), width: 1.6),
          boxShadow: const [
            BoxShadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 4)),
            BoxShadow(color: Color(0x5534D39B), blurRadius: 16, spreadRadius: 2),
          ],
        ),
        child: Icon(
          Icons.apps_rounded,
          size: widget.size * 0.46,
          color: const Color(0xFFF2FFF9),
        ),
      ),
    );
  }
}

/// The five destinations, fanned along an arc out of the launch plate. The fan
/// opens on the same page: nothing underneath moves, and tapping the scrim
/// closes it again.
class _RadialMenu extends StatefulWidget {
  const _RadialMenu({required this.anchor, required this.onSelect, required this.onDismiss});

  final Offset anchor;
  final ValueChanged<HubDestination> onSelect;
  final VoidCallback onDismiss;

  @override
  State<_RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<_RadialMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const destinations = HubDestination.values;
    final size = MediaQuery.sizeOf(context);
    final radius = math.min(size.width, size.height) * 0.40;
    final itemSize = math.min(74.0, size.width * 0.20);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: ColoredBox(color: Color.fromRGBO(6, 11, 15, .78 * t)),
              ),
            ),
            for (var index = 0; index < destinations.length; index++)
              _item(destinations[index], index, destinations.length, radius, itemSize, t),
            Positioned(
              left: widget.anchor.dx - itemSize * 0.5,
              top: widget.anchor.dy - itemSize * 0.5,
              width: itemSize,
              height: itemSize,
              child: Opacity(
                opacity: t,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(side: BorderSide(color: Color(0xAAE8F6FF), width: 1.4)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onDismiss,
                    child: const Center(
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _item(
    HubDestination destination,
    int index,
    int count,
    double radius,
    double itemSize,
    double t,
  ) {
    // 180° (left of the plate) to 272° (straight up), stepping evenly.
    final angle = math.pi * (1.0 + (index / (count - 1)) * 0.50);
    final dx = widget.anchor.dx + math.cos(angle) * radius * t;
    final dy = widget.anchor.dy + math.sin(angle) * radius * t;
    return Positioned(
      left: dx - itemSize / 2,
      top: dy - itemSize / 2,
      width: itemSize,
      height: itemSize + 20,
      child: Opacity(
        opacity: t,
        child: Transform.scale(
          scale: .7 + .3 * t,
          child: Column(
            children: <Widget>[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => widget.onSelect(destination),
                  child: Container(
                    width: itemSize,
                    height: itemSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-.3, -.4),
                        colors: <Color>[
                          Color.lerp(destination.color, Colors.white, .28)!,
                          destination.color,
                          const Color(0xFF0D1418),
                        ],
                        stops: const <double>[0, .58, 1],
                      ),
                      border: Border.all(color: const Color(0xCCE8F1F6), width: 1.3),
                      boxShadow: const [
                        BoxShadow(color: Color(0xAA000000), blurRadius: 12, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Icon(destination.icon, color: Colors.white, size: itemSize * 0.42),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                destination.label,
                style: const TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brushed metal with the diagonal seams and the hatched wedge marks of the
/// reference plate.
class _MachineBody extends StatelessWidget {
  const _MachineBody();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A464E), Color(0xFF1B252C), Color(0xFF0A1015)],
            stops: [0, .55, 1],
          ),
        ),
        child: CustomPaint(painter: _EtchPainter(), child: SizedBox.expand()),
      );
}

class _EtchPainter extends CustomPainter {
  const _EtchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final seam = Paint()
      ..color = const Color(0xFFAEB9BF).withValues(alpha: .10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final shade = Paint()
      ..color = const Color(0xFF05090C).withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    // Two long diagonal seams, as in the plate: top-left to middle, then a
    // step out to the right edge.
    final plate = Path()
      ..moveTo(-size.width * .05, size.height * .06)
      ..lineTo(size.width * .58, -size.height * .03)
      ..lineTo(size.width * 1.04, size.height * .15)
      ..lineTo(size.width * 1.02, size.height * .97)
      ..lineTo(size.width * .42, size.height * 1.03)
      ..lineTo(-size.width * .04, size.height * .86)
      ..close();
    canvas.drawPath(plate, shade);
    canvas.drawPath(plate, seam);

    final step = Path()
      ..moveTo(-size.width * .05, size.height * .34)
      ..lineTo(size.width * .44, size.height * .40)
      ..lineTo(size.width * .30, size.height * .72)
      ..lineTo(size.width * .06, size.height * .98);
    canvas.drawPath(step, seam);

    // Hatched wedges: little graticule triangles scattered between the lenses.
    void wedge(Offset origin, double scale, bool flip) {
      final hatch = Paint()
        ..color = const Color(0xFFC3CDD3).withValues(alpha: .075)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9;
      final triangle = Path()
        ..moveTo(0, 0)
        ..lineTo(flip ? -scale : scale, 0)
        ..lineTo(0, flip ? scale * .62 : scale * .62)
        ..close();
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.drawPath(triangle, hatch);
      for (var i = 1; i <= 5; i++) {
        final f = i / 6;
        canvas.drawLine(
          Offset((flip ? -scale : scale) * f, 0),
          Offset(0, scale * .62 * f),
          hatch,
        );
      }
      canvas.restore();
    }

    wedge(Offset(size.width * .50, size.height * .10), size.width * .17, false);
    wedge(Offset(size.width * .70, size.height * .26), size.width * .13, true);
    wedge(Offset(size.width * .10, size.height * .30), size.width * .12, true);
    wedge(Offset(size.width * .15, size.height * .62), size.width * .14, false);
    wedge(Offset(size.width * .64, size.height * .80), size.width * .12, true);
  }

  @override
  bool shouldRepaint(covariant _EtchPainter oldDelegate) => false;
}

/// Knurled barrel around the glass: fine radially-combed teeth plus a highlight
/// on the side the light comes from.
class _BarrelPainter extends CustomPainter {
  const _BarrelPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final centre = Offset(radius, radius);
    final comb = Paint()
      ..color = const Color(0xFFB9C4CA).withValues(alpha: .20)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final count = 90;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2;
      final inner = radius * 0.945;
      final outer = radius * 0.995;
      canvas.drawLine(
        centre + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        centre + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        comb,
      );
    }
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .16);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius * .90),
      math.pi * 1.05,
      math.pi * .5,
      false,
      highlight,
    );
    final tint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: .35);
    canvas.drawCircle(centre, radius * .885, tint);
  }

  @override
  bool shouldRepaint(covariant _BarrelPainter oldDelegate) => oldDelegate.accent != accent;
}

/// The glass itself: concentric coatings, a crescent of light, and the dark
/// disc the destination is engraved on.
class _GlassPainter extends CustomPainter {
  const _GlassPainter({required this.accent, required this.discRatio});

  final Color accent;
  final double discRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final centre = Offset(radius, radius);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 5; i++) {
      ring.color = i.isEven
          ? const Color(0xFFF7BE83).withValues(alpha: .16)
          : accent.withValues(alpha: .22);
      canvas.drawCircle(centre, radius * (.30 + i * .083), ring);
    }
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFE3BE).withValues(alpha: .35);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius * .46),
      math.pi * 1.15,
      math.pi * .55,
      false,
      glow,
    );
    final disc = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-.3, -.35),
        colors: [Color(0xFF20272B), Color(0xFF0B0E10), Color(0xFF050708)],
        stops: [0, .7, 1],
      ).createShader(Rect.fromCircle(center: centre, radius: radius * discRatio));
    canvas.drawCircle(centre, radius * discRatio, disc);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: .5);
    canvas.drawCircle(centre, radius * discRatio, rim);
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.discRatio != discRatio;
}

/// Brushed diagonal lines on the red plates, so they read as the same material
/// family as the lenses.
class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .8;
    for (var offset = -size.height; offset < size.width; offset += 7) {
      canvas.drawLine(
        Offset(offset.toDouble(), size.height),
        Offset(offset + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) => oldDelegate.color != color;
}
