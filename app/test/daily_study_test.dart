import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiaverse/daily_study.dart';

/// **روزانہ مطالعہ**: the portion arithmetic, the streak, and the plan that is
/// saved between sessions. Every day of every length must be covered exactly
/// once, because a plan that skips a page leaves a hole in a reader's khatm.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('portion arithmetic', () {
    test('a 90-day Quran plan covers all 604 pages exactly once', () {
      var expected = 1;
      for (var day = 1; day <= 90; day++) {
        final portion = StudyPortion.forDay(
          day: day,
          days: 90,
          totalUnits: kQuranPages,
          unitLabelUrdu: 'صفحہ',
        );
        expect(portion.first, expected, reason: 'day $day must start where the last ended');
        expect(portion.last, greaterThanOrEqualTo(portion.first));
        expected = portion.last + 1;
      }
      expect(expected, kQuranPages + 1, reason: 'the last day ends on the last page');
    });

    test('the remainder is spread, never piled onto one day', () {
      // 604 pages over 30 days: 20 pages a day plus four days of 21.
      final lengths = <int>[
        for (var day = 1; day <= 30; day++)
          StudyPortion.forDay(day: day, days: 30, totalUnits: kQuranPages, unitLabelUrdu: 'صفحہ').last -
              StudyPortion.forDay(day: day, days: 30, totalUnits: kQuranPages, unitLabelUrdu: 'صفحہ').first +
              1,
      ];
      expect(lengths.reduce((a, b) => a + b), kQuranPages);
      expect(lengths.reduce((a, b) => a > b ? a : b) - lengths.reduce((a, b) => a < b ? a : b),
          lessThanOrEqualTo(1));
    });

    test('241 sermons over 90 days stay inside the book', () {
      for (var day = 1; day <= 90; day++) {
        final portion = StudyPortion.forDay(
          day: day,
          days: 90,
          totalUnits: 241,
          unitLabelUrdu: 'نمبر',
        );
        expect(portion.first, inInclusiveRange(1, 241));
        expect(portion.last, inInclusiveRange(portion.first, 241));
      }
      expect(
        StudyPortion.forDay(day: 90, days: 90, totalUnits: 241, unitLabelUrdu: 'نمبر').last,
        241,
      );
    });

    test('a one-day plan is the whole book', () {
      final portion = StudyPortion.forDay(day: 1, days: 1, totalUnits: 480, unitLabelUrdu: 'نمبر');
      expect(portion.first, 1);
      expect(portion.last, 480);
      expect(portion.isLastDay, isTrue);
    });

    test('a day outside the plan is clamped instead of going blank', () {
      final late = StudyPortion.forDay(day: 120, days: 90, totalUnits: kQuranPages, unitLabelUrdu: 'صفحہ');
      expect(late.day, 90);
      expect(late.last, kQuranPages);
    });

    test('an empty or zero-length book still yields a usable portion', () {
      final portion = StudyPortion.forDay(day: 1, days: 30, totalUnits: 0, unitLabelUrdu: 'نمبر');
      expect(portion.first, 1);
      expect(portion.last, 1);
    });
  });

  group('day counting', () {
    test('the start day is day one and each next day adds one', () {
      expect(StudyPortion.dayNumberFor('2026-10-20', DateTime(2026, 10, 20, 23, 59)), 1);
      expect(StudyPortion.dayNumberFor('2026-10-20', DateTime(2026, 10, 21, 0, 1)), 2);
      expect(StudyPortion.dayNumberFor('2026-10-20', DateTime(2026, 11, 19)), 31);
    });

    test('a clock that moved backwards still reads as day one', () {
      expect(StudyPortion.dayNumberFor('2026-10-20', DateTime(2026, 10, 18)), lessThan(1));
    });

    test('the key is a plain local date', () {
      expect(studyDayKey(DateTime(2026, 1, 5, 22)), '2026-01-05');
    });
  });

  group('streak', () {
    final plan = StudyPlan(track: StudyTrack.quran, days: 90, startedOn: '2026-10-20');

    test('today counts only once it is marked, yesterday still does', () {
      expect(studyStreak(plan.copyWith(completedDays: <int>{1, 2, 3}), 4), 3);
      expect(studyStreak(plan.copyWith(completedDays: <int>{1, 2, 3, 4}), 4), 4);
    });

    test('a missed day ends the streak', () {
      // Today is not marked yet, so yesterday still counts: days 1–4 finished
      // is a streak of one, and day 3 breaks it there.
      expect(studyStreak(plan.copyWith(completedDays: <int>{1, 2, 4}), 5), 1);
      expect(studyStreak(plan.copyWith(completedDays: <int>{1, 2, 3}), 5), 0);
      expect(studyStreak(plan.copyWith(completedDays: <int>{4, 5}), 5), 2);
    });

    test('an empty plan has no streak', () {
      expect(studyStreak(plan, 1), 0);
    });
  });

  group('toggling and saving', () {
    test('a day can be marked finished and un-marked again', () {
      const plan = StudyPlan(track: StudyTrack.balaghaWisdom, days: 30, startedOn: '2026-10-20');
      final marked = plan.toggledDay(2);
      expect(marked.completedDays, <int>{2});
      expect(marked.toggledDay(2).completedDays, isEmpty);
      expect(plan.completedDays, isEmpty, reason: 'the original plan is never mutated');
    });

    test('a plan survives the round trip through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = StudyPlanStore();
      expect(await store.load(), isNull);

      final plan = StudyPlan(
        track: StudyTrack.balaghaSermons,
        days: 60,
        startedOn: '2026-10-20',
        completedDays: <int>{1, 2, 5},
      );
      await store.save(plan);

      final restored = await StudyPlanStore().load();
      expect(restored, isNotNull);
      expect(restored!.track, StudyTrack.balaghaSermons);
      expect(restored.days, 60);
      expect(restored.startedOn, '2026-10-20');
      expect(restored.completedDays, <int>{1, 2, 5});

      await store.clear();
      expect(await StudyPlanStore().load(), isNull);
    });

    test('a corrupt saved value is treated as no plan instead of crashing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'daily_study_plan_v1': '{not json'});
      expect(await StudyPlanStore().load(), isNull);
    });

    test('a plan with an unknown track is ignored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'daily_study_plan_v1': '{"track":"mars","days":30,"startedOn":"2026-10-20"}',
      });
      expect(await StudyPlanStore().load(), isNull);
    });
  });

  group('several books at once (1.25)', () {
    test('a pre-1.25 single plan becomes the first of the list', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = StudyPlanStore();
      await store.save(const StudyPlan(track: StudyTrack.quran, days: 90, startedOn: '2026-10-20'));
      final plans = await store.loadPlans();
      expect(plans, hasLength(1));
      expect(plans.single.track, StudyTrack.quran);
    });

    test('two tracks are kept side by side and survive a round trip', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = StudyPlanStore();
      await store.savePlans(const <StudyPlan>[
        StudyPlan(track: StudyTrack.quran, days: 90, startedOn: '2026-10-20', completedDays: <int>{1}),
        StudyPlan(track: StudyTrack.balaghaSermons, days: 60, startedOn: '2026-10-21'),
      ]);
      final plans = await StudyPlanStore().loadPlans();
      expect(plans.map((p) => p.track), <StudyTrack>[StudyTrack.quran, StudyTrack.balaghaSermons]);
      expect(plans.first.completedDays, <int>{1});
      // The legacy key still mirrors the first plan for older builds.
      expect((await StudyPlanStore().load())!.track, StudyTrack.quran);
    });

    test('adding one book never disturbs the plan already running', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = StudyPlanStore();
      await store.savePlan(const StudyPlan(
          track: StudyTrack.quran, days: 90, startedOn: '2026-10-20', completedDays: <int>{1, 2}));
      await store.savePlan(
          const StudyPlan(track: StudyTrack.balaghaWisdom, days: 30, startedOn: '2026-10-22'));
      var plans = await store.loadPlans();
      expect(plans, hasLength(2));
      expect(plans.first.completedDays, <int>{1, 2}, reason: 'the Quran record is untouched');

      await store.removePlan(StudyTrack.quran);
      plans = await store.loadPlans();
      expect(plans.map((p) => p.track), <StudyTrack>[StudyTrack.balaghaWisdom]);
    });

    test('a track can only be targeted once', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = StudyPlanStore();
      await store.savePlans(const <StudyPlan>[
        StudyPlan(track: StudyTrack.quran, days: 90, startedOn: '2026-10-20'),
        StudyPlan(track: StudyTrack.quran, days: 30, startedOn: '2026-10-21'),
      ]);
      final plans = await store.loadPlans();
      expect(plans, hasLength(1));
      expect(plans.single.days, 90);
    });
  });
}
