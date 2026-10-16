import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';

/// The five things the bottom panel can do. The order is the panel's order
/// (right to left, as an Urdu reader starts), and the radial menu uses it too.
enum HubDestination {
  books('کتب', Icons.menu_book_rounded, Color(0xFF145B45)),
  search('تلاش', Icons.search_rounded, Color(0xFF2F6FD6)),
  lastSeen('آخری مطالعہ', Icons.history_rounded, Color(0xFFE08A1E)),
  qibla('قبلہ نما', Icons.explore_rounded, Color(0xFF00897B)),
  download('ڈاؤن لوڈ', Icons.download_rounded, Color(0xFF7B4FD0));

  const HubDestination(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Counts the pages pushed on top of the home screen (every book, reader,
/// list and utility screen). Dialogs and bottom sheets are not pages and do
/// not count, so the hub stays out of their way.
class ReadingDepthObserver extends NavigatorObserver {
  ReadingDepthObserver(this.depth);

  final ValueNotifier<int> depth;
  final Set<Route<dynamic>> _pages = <Route<dynamic>>{};

  /// Publishes after the frame: route changes can arrive while the navigator
  /// is itself building, and listeners must not be rebuilt in the middle of that.
  void _publish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      depth.value = _pages.length;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The home route is the first one and has no previous route.
    if (route is PageRoute<dynamic> && previousRoute != null) {
      _pages.add(route);
      _publish();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pages.remove(route)) _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pages.remove(route)) _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _pages.remove(oldRoute);
    if (newRoute is PageRoute<dynamic>) _pages.add(newRoute);
    _publish();
  }
}

/// The bottom panel on the home screen: five buttons on a white bar.
class HomeDock extends StatelessWidget {
  const HomeDock({super.key, required this.selected, required this.onSelected});

  /// The tab in front (books or search); the other three are actions.
  final HubDestination selected;
  final ValueChanged<HubDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Row(
            children: <Widget>[
              for (final destination in HubDestination.values)
                Expanded(
                  child: _DockButton(
                    destination: destination,
                    selected: destination == selected,
                    onTap: () => onSelected(destination),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final HubDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = destination.color;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : color.withValues(alpha: 0.13),
                ),
                child: Icon(
                  destination.icon,
                  size: 22,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? color : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circular hub over every page: a round logo button at the bottom centre
/// (where the bottom panel was). Tapping it opens the five buttons as a radial
/// menu over the page; the page underneath is never moved, so closing the menu
/// (or choosing "back" by tapping the centre again) leaves the reader exactly
/// where it was.
class ReadingHub extends StatefulWidget {
  const ReadingHub({
    super.key,
    required this.depth,
    required this.onAction,
    required this.child,
  });

  /// Pages on top of the home screen; the hub is shown while it is above 0.
  final ValueListenable<int> depth;

  /// Runs the chosen destination (the caller decides how to open it).
  final ValueChanged<HubDestination> onAction;

  final Widget child;

  @override
  State<ReadingHub> createState() => _ReadingHubState();
}

class _ReadingHubState extends State<ReadingHub> with SingleTickerProviderStateMixin {
  static const double _buttonSize = 62;
  static const double _itemWidth = 92;
  static const double _itemIconSize = 52;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _open = false;

  @override
  void initState() {
    super.initState();
    widget.depth.addListener(_onDepthChanged);
  }

  @override
  void didUpdateWidget(covariant ReadingHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.depth != widget.depth) {
      oldWidget.depth.removeListener(_onDepthChanged);
      widget.depth.addListener(_onDepthChanged);
    }
  }

  @override
  void dispose() {
    widget.depth.removeListener(_onDepthChanged);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Back on the home screen the hub goes away, and a closed menu stays closed.
  void _onDepthChanged() {
    if (widget.depth.value > 0) return;
    _open = false;
    _controller.value = 0;
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      setState(() => _open = true);
      _controller.forward();
    }
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _controller.reverse();
  }

  void _choose(HubDestination destination) {
    _close();
    widget.onAction(destination);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        ValueListenableBuilder<int>(
          valueListenable: widget.depth,
          builder: (context, depth, _) {
            if (depth <= 0) return const SizedBox.shrink();
            return _buildHub(context);
          },
        ),
      ],
    );
  }

  Widget _buildHub(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final hubCentre = Offset(
      size.width / 2,
      size.height - media.padding.bottom - 14 - _buttonSize / 2,
    );
    final radius = math.min(132.0, size.width * 0.34);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _curve.value;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (v > 0)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.42 * v)),
                ),
              ),
            if (v > 0)
              for (var index = 0; index < HubDestination.values.length; index++)
                _radialItem(index, hubCentre, radius, v),
            Positioned(
              left: hubCentre.dx - _buttonSize / 2,
              top: hubCentre.dy - _buttonSize / 2,
              child: _HubButton(
                open: _open,
                size: _buttonSize,
                onTap: _toggle,
              ),
            ),
          ],
        );
      },
    );
  }

  /// One destination on the arc above the hub. Index 0 sits at the right (the
  /// start of an Urdu reading order) and the last one at the left.
  Widget _radialItem(int index, Offset hubCentre, double radius, double v) {
    final destination = HubDestination.values[index];
    final angle = (15 + index * 37.5) * math.pi / 180;
    final target = hubCentre + Offset(math.cos(angle) * radius, -math.sin(angle) * radius);
    // Each item leaves the hub a little after the one before it.
    final progress = math.min(1.0, math.max(0.0, (v - index * 0.06) / 0.7));
    final centre = hubCentre + (target - hubCentre) * progress;
    return Positioned(
      left: centre.dx - _itemWidth / 2,
      top: centre.dy - _itemIconSize / 2,
      child: Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: 0.7 + 0.3 * progress,
          child: _HubItem(
            destination: destination,
            width: _itemWidth,
            iconSize: _itemIconSize,
            onTap: () => _choose(destination),
          ),
        ),
      ),
    );
  }
}

/// The round centre button: the ShiaVerse logo, turning into a close mark
/// while the menu is open.
class _HubButton extends StatelessWidget {
  const _HubButton({required this.open, required this.size, required this.onTap});

  final bool open;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? 'مینو بند کریں' : 'بوٹم مینو کھولیں',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: open
                  ? const <Color>[kGold, Color(0xFFA67C35)]
                  : const <Color>[kForest, kForestDark],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: open
                  ? const Icon(
                      Icons.close_rounded,
                      key: ValueKey<String>('close'),
                      color: Colors.white,
                      size: 30,
                    )
                  : SizedBox(
                      key: const ValueKey<String>('logo'),
                      width: size - 12,
                      height: size - 12,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/shiaverse_icon.png',
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          cacheHeight: 160,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One radial menu entry: a coloured disc with its icon, and its name in a
/// white pill underneath.
class _HubItem extends StatelessWidget {
  const _HubItem({
    required this.destination,
    required this.width,
    required this.iconSize,
    required this.onTap,
  });

  final HubDestination destination;
  final double width;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = destination.color;
    return Semantics(
      button: true,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: iconSize + 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(destination.icon, color: Colors.white, size: 25),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D2925),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
