import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/more_features.dart';
import '../widgets/reading_hub.dart';

/// Full-screen Xplore dashboard. The seven large, numbered controls mirror the
/// requested camera-lens layout: six destinations and a radial-menu control.
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

  @override
  Widget build(BuildContext context) {
    final tasbeeh = _feature('تسبیح و ذکر');
    final prayer = _feature('نماز کے اوقات');
    final crescent = _feature('چاند کی رویت');
    final calendar = _feature('اسلامی تقویم');
    final extra = _feature('Xplore Xtra');
    final encyclopedia = _feature('اثنا عشری انسائکلوپیڈیا');

    return Scaffold(
      backgroundColor: const Color(0xFF111B23),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _MachineBackdrop(),
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              return Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(18, compact ? 4 : 10, 18, compact ? 8 : 14),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'واپس',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Xplore', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: .6)),
                              SizedBox(height: 2),
                              Text('عبادت، وقت اور علم — ایک جگہ', style: TextStyle(fontSize: 12, color: Color(0xFFBAC9D0))),
                            ],
                          ),
                        ),
                        const Icon(Icons.travel_explore_rounded, color: Color(0xFFE3A46D), size: 27),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Expanded(child: _LensTile(number: 1, title: 'تسبیح', subtitle: 'تسبیح و ذکر', icon: Icons.fingerprint_rounded, colors: const [Color(0xFFCB7D35), Color(0xFF663819)], feature: tasbeeh)),
                                const SizedBox(width: 12),
                                Expanded(child: _LensTile(number: 2, title: 'نماز', subtitle: 'اوقاتِ نماز', icon: Icons.access_time_filled_rounded, colors: const [Color(0xFF4F9B9A), Color(0xFF164D55)], feature: prayer)),
                              ],
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 12),
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Expanded(child: _LensTile(number: 3, title: 'چاند کی رویت', subtitle: 'رویتِ ہلال', icon: Icons.nightlight_round, colors: const [Color(0xFF7D72B1), Color(0xFF37345F)], feature: crescent)),
                                const SizedBox(width: 12),
                                Expanded(child: _LensTile(number: 4, title: 'اسلامی تقویم', subtitle: 'ہجری تاریخیں', icon: Icons.calendar_month_rounded, colors: const [Color(0xFF56A18A), Color(0xFF1B584B)], feature: calendar)),
                              ],
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 12),
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Expanded(child: _LensTile(number: 5, title: 'Xplore Xtra', subtitle: 'روزانہ مطالعہ اور مزید', icon: Icons.auto_awesome_rounded, colors: const [Color(0xFFD79C45), Color(0xFF805127)], feature: extra)),
                                const SizedBox(width: 12),
                                Expanded(child: _LensTile(number: 6, title: 'اثنا عشری\nانسائکلوپیڈیا', subtitle: 'ائمہ، عقائد، تاریخ', icon: Icons.menu_book_rounded, colors: const [Color(0xFF718EAD), Color(0xFF324B68)], feature: encyclopedia)),
                              ],
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 12),
                          _RadialLens(
                            number: 7,
                            open: _menuOpen,
                            onTap: _toggleMenu,
                          ),
                          SizedBox(height: compact ? 5 : 10),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          if (_menuOpen) _RadialMenuOverlay(onSelect: _selectDestination, onDismiss: _toggleMenu),
        ],
      ),
    );
  }

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  void _selectDestination(HubDestination destination) {
    setState(() => _menuOpen = false);
    widget.onAction(destination);
  }
}

class _LensTile extends StatelessWidget {
  const _LensTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.feature,
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final MoreFeature? feature;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title، $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: feature?.onOpen ?? () {},
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color.lerp(colors.first, Colors.white, .12)!, const Color(0xFF19252E), Color.lerp(colors.last, Colors.black, .16)!]),
              border: Border.all(color: colors.first.withValues(alpha: .62), width: 1.2),
              boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: .38), blurRadius: 14, offset: const Offset(0, 7))],
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: CustomPaint(painter: _LensGrooves(color: colors.first.withValues(alpha: .24)))),
                Positioned(top: 10, right: 12, child: _NumberTag(number: number)),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 22, 9, 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-.32, -.4),
                                colors: <Color>[
                                  Color.lerp(colors.first, Colors.white, .25)!,
                                  colors.first,
                                  colors.last,
                                  const Color(0xFF10171D),
                                ],
                                stops: const <double>[0, .44, .72, 1],
                              ),
                              border: Border.all(color: const Color(0xFFB7C1C7).withValues(alpha: .7), width: 3),
                              boxShadow: <BoxShadow>[
                                BoxShadow(color: colors.first.withValues(alpha: .37), blurRadius: 16, spreadRadius: 2),
                                const BoxShadow(color: Colors.black54, blurRadius: 7, offset: Offset(0, 5)),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.last.withValues(alpha: .76),
                                border: Border.all(color: Colors.white.withValues(alpha: .17), width: 2),
                              ),
                              child: Icon(icon, color: const Color(0xFFFFD9A0), size: 31),
                            ),
                          ),
                          const SizedBox(height: 11),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 16, height: 1.28, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFFC1CFD4)),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _NumberTag extends StatelessWidget {
  const _NumberTag({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) => Container(
        width: 23,
        height: 23,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF111920).withValues(alpha: .9), border: Border.all(color: const Color(0xFFD3A267).withValues(alpha: .75))),
        child: Text('$number', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFFE1B7))),
      );
}

class _RadialLens extends StatelessWidget {
  const _RadialLens({required this.number, required this.open, required this.onTap});
  final int number;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 58,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF79343A), Color(0xFF3C2027)]), border: Border.all(color: const Color(0xFFD9766D), width: 1.2), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 5))]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _NumberTag(number: number),
                  const SizedBox(width: 12),
                  Icon(open ? Icons.close_rounded : Icons.apps_rounded, color: const Color(0xFFFFE5C9), size: 25),
                  const SizedBox(width: 10),
                  Text(open ? 'مینو بند کریں' : 'Radial menu کھولیں', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _RadialMenuOverlay extends StatelessWidget {
  const _RadialMenuOverlay({required this.onSelect, required this.onDismiss});
  final ValueChanged<HubDestination> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Material(
          color: const Color(0xD90A1118),
          child: SafeArea(
            child: Stack(
              children: <Widget>[
                Positioned(top: 10, left: 12, child: IconButton(onPressed: onDismiss, icon: const Icon(Icons.close_rounded, color: Colors.white))),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 14,
                    children: <Widget>[
                      for (final destination in HubDestination.values)
                        SizedBox(
                          width: 124,
                          height: 116,
                          child: Material(
                            color: destination.color.withValues(alpha: .22),
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => onSelect(destination),
                              child: Container(
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: destination.color.withValues(alpha: .8))),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[Icon(destination.icon, color: Colors.white, size: 30), const SizedBox(height: 8), Text(destination.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MachineBackdrop extends StatelessWidget {
  const _MachineBackdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF34434D), Color(0xFF18232C), Color(0xFF0D151D)])),
        child: CustomPaint(painter: _BackdropPainter(), child: const SizedBox.expand()),
      );
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF8E9AA1).withValues(alpha: .075)..style = PaintingStyle.stroke..strokeWidth = 1;
    final path = Path()..moveTo(size.width * .02, size.height * .08)..lineTo(size.width * .52, size.height * .02)..lineTo(size.width * .98, size.height * .16)..lineTo(size.width * .96, size.height * .92)..lineTo(size.width * .39, size.height * .98)..lineTo(size.width * .02, size.height * .83)..close();
    canvas.drawPath(path, paint);
    for (var index = 0; index < 6; index++) {
      final center = Offset(size.width * (index.isEven ? .12 : .88), size.height * (.16 + index * .14));
      canvas.drawCircle(center, 34 + index * 7, paint..color = const Color(0xFFB4C0C5).withValues(alpha: .018));
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}

class _LensGrooves extends CustomPainter {
  const _LensGrooves({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(size.width * .55, -size.height * .2, size.width * .7, size.height * .7);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(rect.deflate(i * 7), math.pi * .05, math.pi * .72, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LensGrooves oldDelegate) => oldDelegate.color != color;
}
