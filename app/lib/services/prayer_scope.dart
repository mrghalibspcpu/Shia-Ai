import 'package:flutter/widgets.dart';

import 'prayer_controller.dart';
import 'tasbeeh_controller.dart';

/// Hands the app's single [PrayerController] to any screen that needs it.
///
/// Passing it through the widget tree would mean changing the constructor of
/// every screen between `main.dart` and the timings card; instead the one
/// instance is published here. `InheritedNotifier` also means a widget that
/// calls [PrayerScope.of] rebuilds when the location or the settings change,
/// but *not* once a second — the ticking clock is a separate `ValueNotifier`
/// (`PrayerController.now`) that only the countdowns listen to.
class PrayerScope extends InheritedNotifier<PrayerController> {
  const PrayerScope({
    super.key,
    required PrayerController controller,
    required super.child,
  }) : super(notifier: controller);

  static PrayerController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PrayerScope>();
    assert(scope != null, 'PrayerScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Like [of], but null when no scope is installed, and without subscribing
  /// to updates — for callbacks that run outside build (a sensor stream must
  /// not turn its screen into a dependent).
  static PrayerController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PrayerScope>()?.notifier;

  /// Read without subscribing to updates — for callbacks and initState.
  static PrayerController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PrayerScope>();
    assert(scope != null, 'PrayerScope is missing above this widget');
    return scope!.notifier!;
  }
}

/// The same thing for the tasbeeh counter, which is shared by the counter
/// screen, the home shortcut, and the post-prayer prompt.
class TasbeehScope extends InheritedNotifier<TasbeehController> {
  const TasbeehScope({
    super.key,
    required TasbeehController controller,
    required super.child,
  }) : super(notifier: controller);

  static TasbeehController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TasbeehScope>();
    assert(scope != null, 'TasbeehScope is missing above this widget');
    return scope!.notifier!;
  }

  static TasbeehController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<TasbeehScope>();
    assert(scope != null, 'TasbeehScope is missing above this widget');
    return scope!.notifier!;
  }
}
