import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Full-screen reading and a smooth, speed-adjustable auto-scroll, shared by
/// every متن reader (Quran, hadiths, Mafatih, Nahj al-Balagha and the new
/// Wikipedia collection).
///
/// The readers all use `ScrollablePositionedList`.  Its own
/// [ScrollOffsetController] can move the underlying scroll position by pixels,
/// which is what makes the scroll continuous instead of jumping from one card
/// to the next.  A state that mixes this in calls [disposeReaderDisplay] from
/// `dispose`, passes [scrollOffsetController] to the list, and asks
/// [readerDisplayActions] / [readerDisplayOverlay] for the two controls.
mixin ReaderDisplayMode<T extends StatefulWidget> on State<T> {
  /// Pixel-level scroll handle for `ScrollablePositionedList`.
  final ScrollOffsetController scrollOffsetController = ScrollOffsetController();

  bool readerFullScreen = false;
  bool autoScrolling = false;

  /// Multiplier on the base reading pace (~80 px/s). 0.5 is slow, 4 is fast.
  double autoScrollSpeed = 1.0;

  Timer? _autoScrollTimer;

  static const int _tickMillis = 220;
  static const double _basePixelsPerTick = 18;

  /// Starts or stops the auto-scroll. Safe to call without a mounted list.
  void toggleAutoScroll() {
    if (autoScrolling) {
      stopAutoScroll();
    } else {
      startAutoScroll();
    }
  }

  void startAutoScroll() {
    _autoScrollTimer?.cancel();
    autoScrolling = true;
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: _tickMillis),
      (_) => _autoScrollTick(),
    );
    if (mounted) setState(() {});
  }

  void stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    autoScrolling = false;
    if (mounted) setState(() {});
  }

  void setAutoScrollSpeed(double value) {
    final next = value.clamp(0.5, 4.0).toDouble();
    if (next == autoScrollSpeed) return;
    setState(() => autoScrollSpeed = next);
  }

  void _autoScrollTick() {
    if (!autoScrolling || !mounted) return;
    final pixels = _basePixelsPerTick * autoScrollSpeed;
    // The controller asserts its list is attached. A reader that is still
    // loading, or already closed, simply skips this tick instead of throwing
    // out of a timer.
    unawaited(() async {
      try {
        await scrollOffsetController.animateScroll(
          offset: pixels,
          duration: const Duration(milliseconds: _tickMillis),
          curve: Curves.linear,
        );
      } catch (_) {
        // Not attached yet (or detached while closing): try again next tick.
      }
    }());
  }

  /// Hides the app bar and the status bar for a page of uninterrupted متن.
  void toggleReaderFullScreen() {
    setState(() => readerFullScreen = !readerFullScreen);
    unawaited(_applySystemUi());
  }

  Future<void> _applySystemUi() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        readerFullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } catch (_) {
      // A test binding has no platform channel; the layout still changes.
    }
  }

  /// Call from `State.dispose` BEFORE `super.dispose()`.
  void disposeReaderDisplay() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    autoScrolling = false;
    if (readerFullScreen) {
      readerFullScreen = false;
      unawaited(_applySystemUi());
    }
  }

  /// Two compact app-bar buttons: auto-scroll and full screen.
  Widget readerDisplayActions(BuildContext context, {Color? color}) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          key: const ValueKey<String>('reader-auto-scroll'),
          tooltip: autoScrolling ? 'خودکار اسکرول بند کریں' : 'خودکار اسکرول',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 40),
          color: autoScrolling ? _goldAccent : accent,
          onPressed: toggleAutoScroll,
          icon: Icon(autoScrolling ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded),
        ),
        IconButton(
          key: const ValueKey<String>('reader-full-screen'),
          tooltip: readerFullScreen ? 'پوری اسکرین سے باہر' : 'پوری اسکرین',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 40),
          color: accent,
          onPressed: toggleReaderFullScreen,
          icon: Icon(readerFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
        ),
      ],
    );
  }

  /// The floating speed strip, shown only while the feature is in use.
  ///
  /// It sits at the bottom-left so it never covers the circular hub at the
  /// bottom centre, and it stays out of the way of the متن itself.
  Widget readerDisplayOverlay(BuildContext context) {
    if (!autoScrolling && !readerFullScreen) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, bottom: 84),
        child: Material(
          key: const ValueKey<String>('reader-display-bar'),
          color: scheme.surface.withValues(alpha: 0.96),
          elevation: 6,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: autoScrolling ? 'روکیں' : 'چلائیں',
                  visualDensity: VisualDensity.compact,
                  color: scheme.primary,
                  onPressed: toggleAutoScroll,
                  icon: Icon(autoScrolling ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                IconButton(
                  tooltip: 'آہستہ',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setAutoScrollSpeed(autoScrollSpeed - 0.25),
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${autoScrollSpeed.toStringAsFixed(2)}×',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: _displayDigitFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'تیز',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setAutoScrollSpeed(autoScrollSpeed + 0.25),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                ),
                if (readerFullScreen)
                  IconButton(
                    tooltip: 'پوری اسکرین سے باہر',
                    visualDensity: VisualDensity.compact,
                    onPressed: toggleReaderFullScreen,
                    icon: const Icon(Icons.close_fullscreen_rounded, size: 19),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gold used by the app for an active reading control.
const Color _goldAccent = Color(0xFFC59A50);

/// A tiny sans digit face, repeated here so the display bar does not need to
/// import the whole theme file.
const String _displayDigitFont = 'sans-serif';
