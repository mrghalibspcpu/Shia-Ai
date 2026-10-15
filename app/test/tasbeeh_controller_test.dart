import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_ai/services/alerts.dart';
import 'package:shia_ai/services/tasbeeh_controller.dart';

/// The digital tasbeeh's engine: the Tasbeeh-e-Zahra (s.a.) sequence that
/// advances by itself, the custom targets, the unlimited mode, the daily
/// rollover, and the persistence that must never lose a count.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A counter with a clock the test controls, so "today" never rolls over
  /// mid-test, and with the sound/vibration switched off.
  TasbeehController counter({DateTime? now}) {
    var clock = now ?? DateTime(2026, 10, 15, 9);
    final controller = TasbeehController(
      clock: () => clock,
      feedback: const SilentFeedback(),
    );
    controller.selectPreset('custom');
    return controller;
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('presets', () {
    test('Tasbeeh-e-Zahra is 34 + 33 + 33, in the right order', () {
      const zahra = TasbeehPreset.zahra;
      expect(zahra.steps.map((step) => step.target), <int>[34, 33, 33]);
      expect(zahra.steps.first.arabic, contains('أَكْبَر'));
      expect(zahra.steps[1].arabic, contains('الْحَمْدُ'));
      expect(zahra.steps.last.arabic, contains('سُبْحَانَ'));
      expect(zahra.steps.map((step) => step.target).reduce((a, b) => a + b), 100);
    });

    test('the catalogue is complete and every entry is addressable', () {
      expect(TasbeehPreset.all.map((preset) => preset.key),
          containsAll(<String>['zahra', 'salawat', 'istighfar', 'tawheed', 'custom']));
      expect(TasbeehPreset.byKey('tawheed').titleUrdu, 'توحید');
      expect(TasbeehPreset.byKey('nonsense').key, 'zahra');
      expect(TasbeehPreset.all.where((preset) => preset.custom).length, 1);
    });
  });

  group('tap counting', () {
    test('a plain tap increments the count and the totals', () {
      final controller = counter();
      expect(controller.count, 0);
      expect(controller.tap(), isFalse);
      expect(controller.count, 1);
      expect(controller.dailyTotal, 1);
      expect(controller.lifetimeTotal, 1);
    });

    test('the progress ring fills towards the target, and never past it', () {
      final controller = counter();
      controller.setTarget(33);
      for (int index = 0; index < 16; index++) {
        controller.tap();
      }
      expect(controller.progress, closeTo(16 / 33, 1e-9));
      expect(controller.remaining, 17);
      for (int index = 0; index < 40; index++) {
        controller.tap();
      }
      // 33 fills the step: the count resets and a round is recorded.
      expect(controller.count, 23); // 56 taps = one full round + 23
      expect(controller.rounds, 1);
      expect(controller.progress, closeTo(23 / 33, 1e-9));
    });

    test('an unlimited counter never completes and wraps its ring every 100', () {
      final controller = counter();
      controller.setTarget(0);
      expect(controller.target, 0);
      expect(controller.remaining, isNull);
      for (int index = 0; index < 120; index++) {
        expect(controller.tap(), isFalse);
      }
      expect(controller.count, 120);
      expect(controller.progress, closeTo(0.2, 1e-9));
      expect(controller.rounds, 0);
      expect(controller.dailyTotal, 120);
    });

    test('the completion tick only moves when a step is completed', () {
      final controller = counter();
      controller.setTarget(33);
      final before = controller.completionTick;
      for (int index = 0; index < 32; index++) {
        controller.tap();
      }
      expect(controller.completionTick, before);
      controller.tap();
      expect(controller.completionTick, before + 1);
      controller.tap();
      expect(controller.completionTick, before + 1);
    });
  });

  group('Tasbeeh-e-Zahra auto-advance', () {
    test('34 Allahu Akbar rolls into 33 Alhamdulillah, then 33 Subhanallah', () {
      final controller = counter();
      controller.selectPreset('zahra');
      expect(controller.stepIndex, 0);
      expect(controller.target, 34);

      for (int index = 0; index < 34; index++) {
        controller.tap();
      }
      expect(controller.stepIndex, 1, reason: 'should have moved to Alhamdulillah');
      expect(controller.count, 0);
      expect(controller.target, 33);
      expect(controller.rounds, 0);
      expect(controller.dailyTotal, 34);

      for (int index = 0; index < 33; index++) {
        controller.tap();
      }
      expect(controller.stepIndex, 2, reason: 'should have moved to Subhanallah');
      expect(controller.target, 33);

      for (int index = 0; index < 33; index++) {
        controller.tap();
      }
      // The sequence is finished: the first step is armed again for the next
      // round, and the round counter has moved.
      expect(controller.stepIndex, 0);
      expect(controller.count, 0);
      expect(controller.rounds, 1);
      expect(controller.dailyTotal, 100);
      expect(controller.lifetimeTotal, 100);
    });

    test('the steps can be picked by hand without losing the totals', () {
      final controller = counter();
      controller.selectPreset('zahra');
      controller.tap();
      controller.tap();
      controller.selectStep(2);
      expect(controller.stepIndex, 2);
      expect(controller.count, 0);
      expect(controller.dailyTotal, 2);
      controller.selectStep(9); // clamped to the last step
      expect(controller.stepIndex, 2);
    });

    test('the post-prayer shortcut arms the first step', () {
      final controller = counter();
      controller.selectPreset('tawheed');
      controller.tap();
      controller.startZahra();
      expect(controller.preset.key, 'zahra');
      expect(controller.stepIndex, 0);
      expect(controller.count, 0);
      expect(controller.dailyTotal, 1);
    });
  });

  group('reset and settings', () {
    test('a reset clears the count, not the history', () {
      final controller = counter();
      controller.setTarget(100);
      for (int index = 0; index < 40; index++) {
        controller.tap();
      }
      controller.reset();
      expect(controller.count, 0);
      expect(controller.dailyTotal, 40);
      expect(controller.lifetimeTotal, 40);
      controller.reset(whole: true);
      expect(controller.rounds, 0);
      expect(controller.dailyTotal, 40);
    });

    test('changing the target re-arms the counter', () {
      final controller = counter();
      controller.tap();
      controller.setTarget(1000);
      expect(controller.count, 0);
      expect(controller.target, 1000);
      controller.setTarget(-5);
      expect(controller.customTarget, 0);
    });

    test('the preset switch keeps the daily total but starts the step fresh', () {
      final controller = counter();
      controller.tap();
      controller.tap();
      controller.selectPreset('salawat');
      expect(controller.preset.key, 'salawat');
      expect(controller.count, 0);
      expect(controller.dailyTotal, 2);
      // Re-selecting the same preset is a no-op, not a reset.
      controller.tap();
      controller.selectPreset('salawat');
      expect(controller.count, 1);
    });

    test('sound and haptics toggle and stick', () {
      final controller = counter();
      expect(controller.soundEnabled, isTrue);
      expect(controller.hapticsEnabled, isTrue);
      controller.toggleSound();
      controller.toggleHaptics();
      expect(controller.soundEnabled, isFalse);
      expect(controller.hapticsEnabled, isFalse);
    });
  });

  group('persistence', () {
    test('the count survives a restart', () async {
      final first = counter();
      first.selectPreset('zahra');
      for (int index = 0; index < 40; index++) {
        first.tap();
      }
      // 40 taps: 34 finish the first step, 6 are on the second.
      await Future<void>.delayed(Duration.zero);

      final second = TasbeehController(
        clock: () => DateTime(2026, 10, 15, 18),
        feedback: const SilentFeedback(),
      );
      await second.load();
      expect(second.isLoaded, isTrue);
      expect(second.preset.key, 'zahra');
      expect(second.stepIndex, 1);
      expect(second.count, 6);
      expect(second.dailyTotal, 40);
      expect(second.lifetimeTotal, 40);
    });

    test('a new day zeroes today, never the lifetime total', () async {
      final first = counter();
      for (int index = 0; index < 12; index++) {
        first.tap();
      }
      await Future<void>.delayed(Duration.zero);

      final tomorrow = TasbeehController(
        clock: () => DateTime(2026, 10, 16, 7),
        feedback: const SilentFeedback(),
      );
      await tomorrow.load();
      expect(tomorrow.dailyTotal, 0);
      expect(tomorrow.lifetimeTotal, 12);
      tomorrow.tap();
      expect(tomorrow.dailyTotal, 1);
      expect(tomorrow.lifetimeTotal, 13);
    });

    test('corrupt stored state falls back to a fresh counter', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        TasbeehController.storageKey: 'not json',
      });
      final controller = TasbeehController(feedback: const SilentFeedback());
      await controller.load();
      expect(controller.count, 0);
      expect(controller.preset.key, 'zahra');
      expect(controller.isLoaded, isTrue);
    });

    test('a stored snapshot with missing keys still loads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        TasbeehController.storageKey: jsonEncode(<String, dynamic>{'count': '7', 'daily': 9}),
      });
      final controller = TasbeehController(feedback: const SilentFeedback());
      await controller.load();
      expect(controller.count, 7);
      expect(controller.dailyTotal, 9);
      expect(controller.soundEnabled, isTrue);
    });
  });
}
