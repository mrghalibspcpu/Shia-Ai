import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alerts.dart';

/// One zikr and how many times it is said.
class TasbeehStep {
  const TasbeehStep({
    required this.key,
    required this.arabic,
    required this.urdu,
    required this.target,
  });

  final String key;

  /// The dhikr itself, to be printed with the app's Arabic font.
  final String arabic;

  /// Its meaning, in one short Urdu line.
  final String urdu;

  /// How many repetitions finish this step. `0` means "no target".
  final int target;
}

/// A named sequence of steps: Tasbeeh-e-Zahra (s.a.) is the three-step one.
class TasbeehPreset {
  const TasbeehPreset({
    required this.key,
    required this.titleUrdu,
    required this.noteUrdu,
    required this.steps,
    this.custom = false,
  });

  final String key;
  final String titleUrdu;
  final String noteUrdu;
  final List<TasbeehStep> steps;

  /// True for the "my own dhikr" entry, whose target the reader sets.
  final bool custom;

  /// The three steps the Prophet (ص) taught Fatima al-Zahra (س).
  static const TasbeehPreset zahra = TasbeehPreset(
    key: 'zahra',
    titleUrdu: 'تسبیحِ زہرا (س)',
    noteUrdu: '۳۴ بار اللہ اکبر، ۳۳ بار الحمد للہ، ۳۳ بار سبحان اللہ — خودکار منتقلی',
    steps: <TasbeehStep>[
      TasbeehStep(
        key: 'takbir',
        arabic: 'اللّٰهُ أَكْبَر',
        urdu: 'اللہ سب سے بڑا ہے',
        target: 34,
      ),
      TasbeehStep(
        key: 'tahmeed',
        arabic: 'الْحَمْدُ لِلّٰه',
        urdu: 'تمام تعریف اللہ کے لیے ہے',
        target: 33,
      ),
      TasbeehStep(
        key: 'tasbeeh',
        arabic: 'سُبْحَانَ اللّٰه',
        urdu: 'اللہ پاک ہے',
        target: 33,
      ),
    ],
  );

  static const TasbeehPreset salawat = TasbeehPreset(
    key: 'salawat',
    titleUrdu: 'صلوات',
    noteUrdu: '۱۰۰ بار صلوات — ہر دعا سے پہلے',
    steps: <TasbeehStep>[
      TasbeehStep(
        key: 'salawat',
        arabic: 'اللّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ وَآلِ مُحَمَّد',
        urdu: 'اے اللہ، محمد و آل محمد پر رحمت نازل فرما',
        target: 100,
      ),
    ],
  );

  static const TasbeehPreset istighfar = TasbeehPreset(
    key: 'istighfar',
    titleUrdu: 'استغفار',
    noteUrdu: '۱۰۰ بار استغفار — گناہوں کی بخشش',
    steps: <TasbeehStep>[
      TasbeehStep(
        key: 'istighfar',
        arabic: 'أَسْتَغْفِرُ اللّٰهَ رَبِّي وَأَتُوبُ إِلَيْه',
        urdu: 'میں اپنے رب اللہ سے بخشش مانگتا ہوں اور توبہ کرتا ہوں',
        target: 100,
      ),
    ],
  );

  static const TasbeehPreset tawheed = TasbeehPreset(
    key: 'tawheed',
    titleUrdu: 'توحید',
    noteUrdu: '۱۰۰ بار لا الٰہ الا اللہ — سب سے افضل ذکر',
    steps: <TasbeehStep>[
      TasbeehStep(
        key: 'tawheed',
        arabic: 'لَا إِلٰهَ إِلَّا اللّٰه',
        urdu: 'اللہ کے سوا کوئی معبود نہیں',
        target: 100,
      ),
    ],
  );

  static const TasbeehPreset customPreset = TasbeehPreset(
    key: 'custom',
    titleUrdu: 'اپنا ذکر',
    noteUrdu: 'جس ذکر کا دل چاہے — ہدف خود مقرر کریں',
    custom: true,
    steps: <TasbeehStep>[
      TasbeehStep(
        key: 'custom',
        arabic: 'سُبْحَانَ اللّٰهِ وَبِحَمْدِه',
        urdu: 'اللہ پاک ہے اور اسی کی تعریف ہے',
        target: 33,
      ),
    ],
  );

  static const List<TasbeehPreset> all = <TasbeehPreset>[
    zahra,
    salawat,
    istighfar,
    tawheed,
    customPreset,
  ];

  static TasbeehPreset byKey(String? key) =>
      all.firstWhere((preset) => preset.key == key, orElse: () => zahra);
}

/// The counter's ledger — persisted as one small JSON blob.
class TasbeehSnapshot {
  const TasbeehSnapshot({
    this.presetKey = 'zahra',
    this.stepIndex = 0,
    this.count = 0,
    this.rounds = 0,
    this.customTarget = 33,
    this.dailyTotal = 0,
    this.lifetimeTotal = 0,
    this.dayStamp = '',
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final String presetKey;
  final int stepIndex;
  final int count;
  final int rounds;
  final int customTarget;
  final int dailyTotal;
  final int lifetimeTotal;
  final String dayStamp;
  final bool soundEnabled;
  final bool hapticsEnabled;

  TasbeehSnapshot copyWith({
    String? presetKey,
    int? stepIndex,
    int? count,
    int? rounds,
    int? customTarget,
    int? dailyTotal,
    int? lifetimeTotal,
    String? dayStamp,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) =>
      TasbeehSnapshot(
        presetKey: presetKey ?? this.presetKey,
        stepIndex: stepIndex ?? this.stepIndex,
        count: count ?? this.count,
        rounds: rounds ?? this.rounds,
        customTarget: customTarget ?? this.customTarget,
        dailyTotal: dailyTotal ?? this.dailyTotal,
        lifetimeTotal: lifetimeTotal ?? this.lifetimeTotal,
        dayStamp: dayStamp ?? this.dayStamp,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'preset': presetKey,
        'step': stepIndex,
        'count': count,
        'rounds': rounds,
        'custom_target': customTarget,
        'daily': dailyTotal,
        'lifetime': lifetimeTotal,
        'day': dayStamp,
        'sound': soundEnabled,
        'haptics': hapticsEnabled,
      };

  static TasbeehSnapshot fromJson(Map<String, dynamic> json) => TasbeehSnapshot(
        presetKey: json['preset'] as String? ?? 'zahra',
        stepIndex: _asInt(json['step']),
        count: _asInt(json['count']),
        rounds: _asInt(json['rounds']),
        customTarget: _asInt(json['custom_target'], fallback: 33),
        dailyTotal: _asInt(json['daily']),
        lifetimeTotal: _asInt(json['lifetime']),
        dayStamp: json['day'] as String? ?? '',
        soundEnabled: json['sound'] as bool? ?? true,
        hapticsEnabled: json['haptics'] as bool? ?? true,
      );

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

/// The digital tasbeeh: presets, auto-advancing Tasbeeh-e-Zahra (s.a.), a
/// custom target, haptics, a click sound, and progress that survives a kill.
class TasbeehController extends ChangeNotifier {
  TasbeehController({DateTime Function()? clock, FeedbackSink? feedback})
      : _clock = clock ?? DateTime.now,
        _feedback = feedback ?? Alerts.instance;

  static const String storageKey = 'tasbeeh_v2';

  /// The targets the custom counter offers. `0` is unlimited.
  static const List<int> targetChoices = <int>[33, 100, 1000, 0];

  final DateTime Function() _clock;
  final FeedbackSink _feedback;

  TasbeehSnapshot _state = const TasbeehSnapshot();
  bool _loaded = false;

  /// Set for one frame after a tap completes a step, so the UI can play the
  /// completion animation without the controller knowing about widgets.
  int _completionTick = 0;

  int get completionTick => _completionTick;

  bool get isLoaded => _loaded;
  TasbeehPreset get preset => TasbeehPreset.byKey(_state.presetKey);
  TasbeehStep get step {
    final steps = preset.steps;
    final index = _state.stepIndex.clamp(0, steps.length - 1);
    return steps[index];
  }

  int get stepIndex => _state.stepIndex.clamp(0, preset.steps.length - 1);
  int get count => _state.count;
  int get rounds => _state.rounds;
  int get dailyTotal => _state.dailyTotal;
  int get lifetimeTotal => _state.lifetimeTotal;
  int get customTarget => _state.customTarget;
  bool get soundEnabled => _state.soundEnabled;
  bool get hapticsEnabled => _state.hapticsEnabled;

  /// This step's target (0 = unlimited).
  int get target => preset.custom ? _state.customTarget : step.target;

  /// 0–1 for the progress ring; unlimited counters show a full turn per 100.
  double get progress {
    if (target == 0) return ((count % 100) / 100.0).clamp(0.0, 1.0);
    return (count / target).clamp(0.0, 1.0);
  }

  /// How many taps are left before this step ends (null when unlimited).
  int? get remaining => target == 0 ? null : (target - count).clamp(0, target);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _state = TasbeehSnapshot.fromJson(decoded.cast<String, dynamic>());
        }
      }
    } catch (_) {
      _state = const TasbeehSnapshot();
    }
    _state = _withFreshDay(_state);
    _loaded = true;
    notifyListeners();
  }

  /// One tap: increment, auto-advance when the step is full, and fire the
  /// completion feedback exactly once per completed step.
  ///
  /// Returns true when this tap finished a step.
  bool tap() {
    final rolled = _withFreshDay(_state);
    final goal = preset.custom ? rolled.customTarget : step.target;
    final nextCount = rolled.count + 1;
    final completes = goal > 0 && nextCount >= goal;
    final currentStep = preset.custom
        ? 0
        : rolled.stepIndex.clamp(0, preset.steps.length - 1);
    final lastStep = currentStep >= preset.steps.length - 1;
    final finishedSequence = completes && lastStep;

    _state = rolled.copyWith(
      count: completes ? 0 : nextCount,
      // A finished step either advances, or — when the whole sequence is done —
      // arms the first step again, which is how the reader starts the next
      // round of Tasbeeh-e-Zahra (s.a.) without touching the screen.
      stepIndex: completes ? (lastStep ? 0 : currentStep + 1) : currentStep,
      rounds: finishedSequence ? rolled.rounds + 1 : rolled.rounds,
      dailyTotal: rolled.dailyTotal + 1,
      lifetimeTotal: rolled.lifetimeTotal + 1,
      dayStamp: dayStamp,
    );
    if (completes) _completionTick++;

    if (hapticsEnabled) {
      unawaited(completes ? _feedback.completionHaptic() : _feedback.tapHaptic());
    }
    if (soundEnabled) {
      unawaited(completes ? _feedback.playCompleteChime() : _feedback.playTap());
    }
    unawaited(_persist());
    notifyListeners();
    return completes;
  }

  /// Clears the current count. The sequence itself restarts when [whole] is
  /// true; the daily and lifetime totals are never touched by a reset.
  void reset({bool whole = false}) {
    _state = _state.copyWith(
      count: 0,
      stepIndex: whole ? 0 : stepIndex,
      rounds: whole ? 0 : _state.rounds,
    );
    unawaited(_persist());
    notifyListeners();
  }

  void selectPreset(String key) {
    if (preset.key == key) return;
    _state = _state.copyWith(presetKey: key, stepIndex: 0, count: 0, rounds: 0);
    unawaited(_persist());
    notifyListeners();
  }

  /// Jumps to a step of the current sequence (the mode chips).
  void selectStep(int index) {
    final clamped = index.clamp(0, preset.steps.length - 1);
    if (clamped == stepIndex) return;
    _state = _state.copyWith(stepIndex: clamped, count: 0);
    unawaited(_persist());
    notifyListeners();
  }

  /// Sets the custom counter's target: 33, 100, 1000, or 0 for unlimited.
  void setTarget(int value) {
    _state = _state.copyWith(customTarget: value < 0 ? 0 : value, count: 0);
    unawaited(_persist());
    notifyListeners();
  }

  void toggleSound() {
    _state = _state.copyWith(soundEnabled: !_state.soundEnabled);
    unawaited(_persist());
    notifyListeners();
  }

  void toggleHaptics() {
    _state = _state.copyWith(hapticsEnabled: !_state.hapticsEnabled);
    unawaited(_persist());
    notifyListeners();
  }

  /// Called by the app when the reader taps "start Tasbeeh-e-Zahra" from a
  /// prayer alert: the sequence is armed from its first step.
  void startZahra() {
    _state = _state.copyWith(presetKey: TasbeehPreset.zahra.key, stepIndex: 0, count: 0);
    unawaited(_persist());
    notifyListeners();
  }

  String get dayStamp {
    final now = _clock();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Rolls the daily counter over at midnight.
  TasbeehSnapshot _withFreshDay(TasbeehSnapshot state) {
    final stamp = dayStamp;
    if (state.dayStamp == stamp) return state;
    return state.copyWith(dayStamp: stamp, dailyTotal: 0);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(_state.toJson()));
    } catch (_) {
      return;
    }
  }
}
