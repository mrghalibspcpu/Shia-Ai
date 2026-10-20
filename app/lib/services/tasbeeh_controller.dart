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

/// A wird the reader wrote: its words, an optional meaning or intention, and
/// how many times it is recited (0 = no limit).
@immutable
class CustomWird {
  const CustomWird({
    required this.id,
    required this.text,
    this.note = '',
    this.target = 33,
  });

  final String id;
  final String text;
  final String note;
  final int target;

  CustomWird copyWith({String? text, String? note, int? target}) => CustomWird(
        id: id,
        text: text ?? this.text,
        note: note ?? this.note,
        target: target ?? this.target,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'note': note,
        'target': target,
      };

  /// Null for anything that is not a usable wird (no id, no words).
  static CustomWird? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString().trim() ?? '';
    final text = raw['text']?.toString().trim() ?? '';
    if (id.isEmpty || text.isEmpty) return null;
    return CustomWird(
      id: id,
      text: text,
      note: raw['note']?.toString().trim() ?? '',
      target: TasbeehController.clampTarget(TasbeehSnapshot._asInt(raw['target'], fallback: 33)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CustomWird &&
      other.id == id &&
      other.text == text &&
      other.note == note &&
      other.target == target;

  @override
  int get hashCode => Object.hash(id, text, note, target);
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
    noteUrdu: '34 بار اللہ اکبر، 33 بار الحمد للہ، 33 بار سبحان اللہ — خودکار منتقلی',
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
    noteUrdu: '100 بار صلوات — ہر دعا سے پہلے',
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
    noteUrdu: '100 بار استغفار — گناہوں کی بخشش',
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
    noteUrdu: '100 بار لا الٰہ الا اللہ — سب سے افضل ذکر',
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
    noteUrdu: 'اپنا ورد خود لکھیں اور تعداد خود مقرر کریں',
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

  /// The preset key of a saved wird is this prefix plus the wird's id.
  static const String wirdPrefix = 'wird:';

  /// A saved wird as a one-step preset.
  static TasbeehPreset fromWird(CustomWird wird) => TasbeehPreset(
        key: '$wirdPrefix${wird.id}',
        titleUrdu: shortTitle(wird.text),
        noteUrdu: wird.note.isNotEmpty ? wird.note : 'میرا ورد',
        custom: true,
        steps: <TasbeehStep>[
          TasbeehStep(key: 'wird', arabic: wird.text, urdu: wird.note, target: wird.target),
        ],
      );

  /// A chip-sized title for a wird: its first few words.
  static String shortTitle(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    final title = words.take(3).join(' ');
    return words.length > 3 || title.length > 22
        ? '${title.length > 22 ? title.substring(0, 22) : title}…'
        : title;
  }

  /// This one-step preset with its own words and target ("اپنا ذکر"), or just
  /// a different target (a built-in zikr the reader recites 1000 times).
  TasbeehPreset customised({String text = '', String note = '', required int target}) {
    final base = steps.first;
    final words = text.trim();
    return TasbeehPreset(
      key: key,
      titleUrdu: titleUrdu,
      noteUrdu: noteUrdu,
      custom: custom,
      steps: <TasbeehStep>[
        TasbeehStep(
          key: base.key,
          arabic: words.isNotEmpty ? words : base.arabic,
          urdu: words.isNotEmpty ? note.trim() : base.urdu,
          target: target,
        ),
      ],
    );
  }
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
    this.customText = '',
    this.customNote = '',
    this.wirds = const <CustomWird>[],
    this.targetOverrides = const <String, int>{},
    this.dhikrTotals = const <String, int>{},
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

  /// The words of "اپنا ذکر" (empty = the default dhikr) and their meaning.
  final String customText;
  final String customNote;

  /// The reader's saved wirds, in the order they were added.
  final List<CustomWird> wirds;

  /// Targets the reader chose for the built-in one-step zikr (key → target).
  final Map<String, int> targetOverrides;

  /// Lifetime count per dhikr label (the Tasbeeh report).
  final Map<String, int> dhikrTotals;

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
    String? customText,
    String? customNote,
    List<CustomWird>? wirds,
    Map<String, int>? targetOverrides,
    Map<String, int>? dhikrTotals,
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
        customText: customText ?? this.customText,
        customNote: customNote ?? this.customNote,
        wirds: wirds ?? this.wirds,
        targetOverrides: targetOverrides ?? this.targetOverrides,
        dhikrTotals: dhikrTotals ?? this.dhikrTotals,
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
        'custom_text': customText,
        'custom_note': customNote,
        'wirds': <Map<String, dynamic>>[for (final wird in wirds) wird.toJson()],
        'targets': targetOverrides,
        'dhikr_totals': dhikrTotals,
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
        customText: json['custom_text'] is String ? (json['custom_text'] as String).trim() : '',
        customNote: json['custom_note'] is String ? (json['custom_note'] as String).trim() : '',
        wirds: _asWirds(json['wirds']),
        targetOverrides: _asTargets(json['targets']),
        dhikrTotals: _asTargets(json['dhikr_totals']),
      );

  static List<CustomWird> _asWirds(Object? value) {
    if (value is! List) return const <CustomWird>[];
    final seen = <String>{};
    return <CustomWird>[
      for (final raw in value)
        if (CustomWird.fromJson(raw) case final CustomWird wird when seen.add(wird.id)) wird,
    ];
  }

  static Map<String, int> _asTargets(Object? value) {
    if (value is! Map) return const <String, int>{};
    final targets = <String, int>{};
    for (final entry in value.entries) {
      final raw = entry.value;
      final parsed = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
      if (parsed != null) targets[entry.key.toString()] = TasbeehController.clampTarget(parsed);
    }
    return targets;
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

/// The digital tasbeeh: presets, auto-advancing Tasbeeh-e-Zahra (s.a.), the
/// reader's own wirds and targets, haptics, a click sound, and progress that
/// survives a kill.
class TasbeehController extends ChangeNotifier {
  TasbeehController({DateTime Function()? clock, FeedbackSink? feedback})
      : _clock = clock ?? DateTime.now,
        _feedback = feedback ?? Alerts.instance;

  static const String storageKey = 'tasbeeh_v2';

  /// The targets the custom counter offers. `0` is unlimited.
  static const List<int> targetChoices = <int>[33, 100, 1000, 0];

  /// The quick choices of the target editor (any other number can be typed).
  static const List<int> quickTargets = <int>[33, 72, 100, 110, 313, 1000, 0];

  /// The largest target the editor accepts.
  static const int maxTarget = 1000000;

  /// A target as stored: never negative, never absurd.
  static int clampTarget(int value) => value < 0 ? 0 : (value > maxTarget ? maxTarget : value);

  final DateTime Function() _clock;
  final FeedbackSink _feedback;

  TasbeehSnapshot _state = const TasbeehSnapshot();
  bool _loaded = false;

  /// Set for one frame after a tap completes a step, so the UI can play the
  /// completion animation without the controller knowing about widgets.
  int _completionTick = 0;

  int get completionTick => _completionTick;

  bool get isLoaded => _loaded;

  /// The running preset — a built-in one, "اپنا ذکر" with the reader's words,
  /// or one of the saved wirds.
  TasbeehPreset get preset {
    final key = _state.presetKey;
    if (key.startsWith(TasbeehPreset.wirdPrefix)) {
      final wird = wirdById(key.substring(TasbeehPreset.wirdPrefix.length));
      return wird == null ? TasbeehPreset.zahra : TasbeehPreset.fromWird(wird);
    }
    final base = TasbeehPreset.byKey(key);
    if (base.custom) {
      return base.customised(
        text: _state.customText,
        note: _state.customNote,
        target: _state.customTarget,
      );
    }
    final override = _state.targetOverrides[base.key];
    if (override != null && base.steps.length == 1) return base.customised(target: override);
    return base;
  }

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
  Map<String, int> get dhikrTotals => Map.unmodifiable(_state.dhikrTotals);
  bool get soundEnabled => _state.soundEnabled;
  bool get hapticsEnabled => _state.hapticsEnabled;

  /// The words and meaning of "اپنا ذکر" as the reader wrote them.
  String get customText => _state.customText;
  String get customNote => _state.customNote;

  /// The reader's saved wirds.
  List<CustomWird> get wirds => _state.wirds;

  CustomWird? wirdById(String id) {
    for (final wird in _state.wirds) {
      if (wird.id == id) return wird;
    }
    return null;
  }

  /// The saved wird that is running, if any.
  CustomWird? get activeWird {
    final key = _state.presetKey;
    if (!key.startsWith(TasbeehPreset.wirdPrefix)) return null;
    return wirdById(key.substring(TasbeehPreset.wirdPrefix.length));
  }

  /// Every preset except the three-step Tasbeeh-e-Zahra takes its own target.
  bool get canSetTarget => preset.steps.length == 1;

  /// This step's target (0 = unlimited).
  int get target => step.target;

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
    final goal = target;
    final nextCount = rolled.count + 1;
    final completes = goal > 0 && nextCount >= goal;
    final steps = preset.steps.length;
    final currentStep = rolled.stepIndex.clamp(0, steps - 1);
    final lastStep = currentStep >= steps - 1;
    final finishedSequence = completes && lastStep;

    final totals = Map<String, int>.of(rolled.dhikrTotals);
    final label = step.arabic.isNotEmpty ? step.arabic : preset.titleUrdu;
    totals[label] = (totals[label] ?? 0) + 1;
    _state = rolled.copyWith(
      dhikrTotals: totals,
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

  /// Takes back the last tap (a bead counted by mistake). The totals give it
  /// back too; nothing happens at the start of a step.
  void undo() {
    if (_state.count <= 0) return;
    final totals = Map<String, int>.of(_state.dhikrTotals);
    final label = step.arabic.isNotEmpty ? step.arabic : preset.titleUrdu;
    if ((totals[label] ?? 0) > 0) totals[label] = totals[label]! - 1;
    _state = _state.copyWith(
      dhikrTotals: totals,
      count: _state.count - 1,
      dailyTotal: _state.dailyTotal > 0 ? _state.dailyTotal - 1 : 0,
      lifetimeTotal: _state.lifetimeTotal > 0 ? _state.lifetimeTotal - 1 : 0,
    );
    unawaited(_persist());
    notifyListeners();
  }

  /// Deletes a stored total on the reader's explicit request: today's total,
  /// the lifetime total, or both. The running count is not touched — this is
  /// the one deliberate way to zero what an ordinary reset always preserves.
  void clearTotals({bool daily = false, bool lifetime = false}) {
    if (!daily && !lifetime) return;
    _state = _state.copyWith(
      dailyTotal: daily ? 0 : _state.dailyTotal,
      lifetimeTotal: lifetime ? 0 : _state.lifetimeTotal,
      dhikrTotals: lifetime ? const <String, int>{} : _state.dhikrTotals,
    );
    unawaited(_persist());
    notifyListeners();
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

  /// Runs one of the saved wirds.
  void selectWird(String id) => selectPreset('${TasbeehPreset.wirdPrefix}$id');

  /// Jumps to a step of the current sequence (the mode chips).
  void selectStep(int index) {
    final clamped = index.clamp(0, preset.steps.length - 1);
    if (clamped == stepIndex) return;
    _state = _state.copyWith(stepIndex: clamped, count: 0);
    unawaited(_persist());
    notifyListeners();
  }

  /// Sets the running zikr's target (0 = unlimited) and re-arms the count:
  /// "اپنا ذکر" keeps it as before, a saved wird stores it on the wird, and a
  /// built-in one-step zikr remembers it per zikr. Tasbeeh-e-Zahra's 34/33/33
  /// is fixed.
  void setTarget(int value) {
    final clamped = clampTarget(value);
    final key = _state.presetKey;
    final wird = activeWird;
    if (wird != null) {
      _state = _state.copyWith(
        wirds: <CustomWird>[
          for (final item in _state.wirds) item.id == wird.id ? item.copyWith(target: clamped) : item,
        ],
        count: 0,
      );
    } else if (TasbeehPreset.byKey(key).custom) {
      _state = _state.copyWith(customTarget: clamped, count: 0);
    } else if (canSetTarget) {
      _state = _state.copyWith(
        targetOverrides: <String, int>{..._state.targetOverrides, preset.key: clamped},
        count: 0,
      );
    } else {
      return;
    }
    unawaited(_persist());
    notifyListeners();
  }

  /// Writes the words of "اپنا ذکر" (and optionally its target) and runs it.
  void setCustomZikr({required String text, String note = '', int? target}) {
    final words = text.trim();
    final changed = words != _state.customText ||
        note.trim() != _state.customNote ||
        (target != null && clampTarget(target) != _state.customTarget);
    _state = _state.copyWith(
      presetKey: TasbeehPreset.customPreset.key,
      customText: words,
      customNote: note.trim(),
      customTarget: target == null ? null : clampTarget(target),
      count: changed || preset.key != TasbeehPreset.customPreset.key ? 0 : null,
      stepIndex: 0,
    );
    unawaited(_persist());
    notifyListeners();
  }

  /// Adds a wird (or updates the one with [id]) and runs it.
  CustomWird saveWird({String? id, required String text, String note = '', int target = 33}) {
    final wird = CustomWird(
      id: (id == null || id.isEmpty) ? _freshWirdId() : id,
      text: text.trim(),
      note: note.trim(),
      target: clampTarget(target),
    );
    final exists = wirdById(wird.id) != null;
    final previous = wirdById(wird.id);
    final wasActive = activeWird?.id == wird.id;
    _state = _state.copyWith(
      wirds: exists
          ? <CustomWird>[for (final item in _state.wirds) item.id == wird.id ? wird : item]
          : <CustomWird>[..._state.wirds, wird],
      presetKey: '${TasbeehPreset.wirdPrefix}${wird.id}',
      stepIndex: 0,
      count: wasActive && previous == wird ? null : 0,
      rounds: wasActive ? null : 0,
    );
    unawaited(_persist());
    notifyListeners();
    return wird;
  }

  /// A new wird id, unique even when two wirds are saved in the same tick.
  String _freshWirdId() {
    final stamp = _clock().microsecondsSinceEpoch;
    var candidate = 'w$stamp';
    var suffix = 1;
    while (wirdById(candidate) != null) {
      candidate = 'w${stamp}_${suffix++}';
    }
    return candidate;
  }

  /// Removes a saved wird; when it was running, Tasbeeh-e-Zahra takes over.
  void deleteWird(String id) {
    if (wirdById(id) == null) return;
    final wasActive = activeWird?.id == id;
    _state = _state.copyWith(
      wirds: <CustomWird>[for (final item in _state.wirds) if (item.id != id) item],
      presetKey: wasActive ? TasbeehPreset.zahra.key : null,
      stepIndex: wasActive ? 0 : null,
      count: wasActive ? 0 : null,
      rounds: wasActive ? 0 : null,
    );
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
