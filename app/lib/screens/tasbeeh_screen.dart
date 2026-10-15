import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../astro/prayer_format.dart' show formatCount;
import '../services/prayer_scope.dart';
import '../services/tasbeeh_controller.dart';
import '../widgets/glass_panel.dart';

/// The digital tasbeeh: a big tap zone that feels like a bead, the
/// Tasbeeh-e-Zahra (s.a.) workflow that advances by itself, the reader's own
/// wirds with their own counts, haptics, a click sound, and progress that is
/// never lost.
class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key, this.startWithZahra = false});

  /// Set by the post-prayer prompt: open with Tasbeeh-e-Zahra (s.a.) armed
  /// from its first step.
  final bool startWithZahra;

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> with TickerProviderStateMixin {
  final List<_Ripple> _ripples = <_Ripple>[];
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _seenCompletion = 0;
  String? _justCompleted;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    if (widget.startWithZahra) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        TasbeehScope.read(context).startZahra();
      });
    }
  }

  @override
  void dispose() {
    for (final ripple in _ripples) {
      ripple.controller.dispose();
    }
    _completionTimer?.cancel();
    _flash.dispose();
    super.dispose();
  }

  void _addRipple(Offset centre) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final ripple = _Ripple(controller, centre);
    _ripples.add(ripple);
    if (_ripples.length > 6) {
      _ripples.removeAt(0).controller.dispose();
    }
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _ripples.remove(ripple));
      controller.dispose();
    });
    controller.forward();
    setState(() {});
  }

  void _onCount(TasbeehController controller, Offset local) {
    _addRipple(local);
    controller.tap();
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = TasbeehScope.of(context);

    // A completed step flashes the ring, names the dhikr that finished, and
    // clears itself after a few seconds — the counter must not keep a stale
    // banner on screen while the reader continues with the next step.
    if (controller.completionTick != _seenCompletion) {
      _seenCompletion = controller.completionTick;
      _justCompleted = controller.preset.custom
          ? controller.preset.titleUrdu
          : controller.preset.steps[(controller.stepIndex - 1) % controller.preset.steps.length].urdu;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flash.forward(from: 0);
      });
      _completionTimer?.cancel();
      _completionTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _justCompleted = null);
      });
    }

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('تسبیح', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        actions: <Widget>[
          IconButton(
            tooltip: 'نیا ورد لکھیں',
            onPressed: () => unawaited(showWirdEditor(context)),
            icon: const Icon(Icons.edit_note),
          ),
          IconButton(
            tooltip: 'صفر کریں (دبا کر رکھیں)',
            onPressed: () => unawaited(confirmTasbeehReset(context, controller)),
            onLongPress: () {
              controller.reset(whole: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('گنتی صفر کر دی گئی'), duration: Duration(seconds: 2)),
              );
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
        children: <Widget>[
          if (widget.startWithZahra) ...<Widget>[
            _PostPrayerNote(palette: palette),
            const SizedBox(height: 10),
          ],
          _ModeSelector(controller: controller),
          const SizedBox(height: 12),
          _ZikrCard(controller: controller),
          const SizedBox(height: 14),
          _TapZone(
            controller: controller,
            ripples: _ripples,
            flash: _flash,
            onTap: (local) => _onCount(controller, local),
          ),
          const SizedBox(height: 10),
          _QuickActions(controller: controller),
          const SizedBox(height: 14),
          _StepTracker(controller: controller, justCompleted: _justCompleted),
          const SizedBox(height: 12),
          if (controller.canSetTarget) ...<Widget>[
            _TargetSelector(controller: controller),
            const SizedBox(height: 12),
          ],
          _Totals(controller: controller),
          const SizedBox(height: 12),
          _FeedbackControls(controller: controller),
          const SizedBox(height: 12),
          _ResetRow(
            controller: controller,
            onConfirm: () => unawaited(confirmTasbeehReset(context, controller)),
          ),
        ],
      ),
    );
  }
}

/// True when [text] is written in Arabic (it carries harakat or Arabic-only
/// letters), so it is printed in the Arabic face rather than Nastaliq.
bool looksArabic(String text) =>
    RegExp('[\u064B-\u0652\u0670\u0629\u0643\u064A]').hasMatch(text);

/// "Reset the count?" — shared by the full screen and the home card.
Future<void> confirmTasbeehReset(BuildContext context, TasbeehController controller) async {
  final palette = GlassPalette.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: palette.solid,
      title: const Text('گنتی صفر کریں؟', style: TextStyle(fontSize: 18)),
      content: const Text(
        'موجودہ گنتی صفر ہو جائے گی۔ آج کا کل اور مجموعی گنتی محفوظ رہے گی۔\n'
        '(فوری ری سیٹ کے لیے بٹن کو دبا کر رکھیں)',
        style: TextStyle(fontSize: 14, height: 1.6),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('نہیں'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('ری سیٹ'),
        ),
      ],
    ),
  );
  if (confirmed == true) controller.reset(whole: true);
}

/// The list of every zikr — the built-in ones, the reader's saved wirds, and
/// "write a new wird" — as a bottom sheet. Used by the home card's switch
/// button and the full screen.
Future<void> showWirdPicker(BuildContext context) async {
  final controller = TasbeehScope.read(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final palette = GlassPalette.of(sheetContext);
      final current = controller.preset.key;
      Widget row({
        required String key,
        required String title,
        required String subtitle,
        required IconData icon,
        bool arabic = false,
        VoidCallback? onEdit,
      }) {
        final selected = key == current;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(sheetContext).pop(key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? palette.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? palette.accent.withValues(alpha: 0.45) : palette.track,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 20, color: selected ? palette.accent : palette.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: arabic ? kArabicFont : null,
                            fontSize: 13,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'ورد میں ترمیم',
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, size: 19, color: palette.muted),
                    )
                  else if (selected)
                    Icon(Icons.check_circle, size: 20, color: palette.accent),
                ],
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
            child: GlassPanel(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const GlassSectionHeader(title: 'ذکر یا ورد منتخب کریں'),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final preset in TasbeehPreset.all)
                          row(
                            key: preset.key,
                            title: preset.titleUrdu,
                            subtitle: preset.custom
                                ? (controller.customText.isEmpty ? preset.noteUrdu : controller.customText)
                                : preset.steps.first.arabic,
                            icon: preset.custom ? Icons.edit_outlined : Icons.blur_circular,
                            arabic: !preset.custom,
                          ),
                        if (controller.wirds.isNotEmpty) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                            child: Text(
                              'میرے اوراد',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: palette.gold,
                              ),
                            ),
                          ),
                          for (final wird in controller.wirds)
                            row(
                              key: '${TasbeehPreset.wirdPrefix}${wird.id}',
                              title: TasbeehPreset.shortTitle(wird.text),
                              subtitle: wird.target == 0
                                  ? 'لامحدود'
                                  : '${formatCount(wird.target)} بار'
                                      '${wird.note.isEmpty ? '' : ' — ${wird.note}'}',
                              icon: Icons.bookmark_outline,
                              onEdit: () => Navigator.of(sheetContext).pop('edit:${wird.id}'),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: palette.accent),
                    onPressed: () => Navigator.of(sheetContext).pop('new'),
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text('نیا ورد لکھیں', style: TextStyle(fontSize: 14.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  if (action == 'new') {
    await showWirdEditor(context);
  } else if (action.startsWith('edit:')) {
    final wird = controller.wirdById(action.substring(5));
    if (wird != null) await showWirdEditor(context, wird: wird);
  } else {
    controller.selectPreset(action);
  }
}

/// Write (or edit) a wird: its words, an optional meaning or intention, and
/// how many times to recite it. With [editCustomPreset] the sheet edits the
/// built-in "اپنا ذکر" instead of a saved wird.
Future<void> showWirdEditor(
  BuildContext context, {
  CustomWird? wird,
  bool editCustomPreset = false,
}) async {
  final controller = TasbeehScope.read(context);
  final result = await showModalBottomSheet<_WirdDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WirdEditorSheet(
      initialText: wird?.text ?? (editCustomPreset ? controller.customText : ''),
      initialNote: wird?.note ?? (editCustomPreset ? controller.customNote : ''),
      initialTarget: wird?.target ?? (editCustomPreset ? controller.customTarget : 33),
      canDelete: wird != null,
      title: wird != null
          ? 'ورد میں ترمیم'
          : (editCustomPreset ? 'اپنا ذکر لکھیں' : 'نیا ورد لکھیں'),
    ),
  );
  if (result == null || !context.mounted) return;
  if (result.delete && wird != null) {
    controller.deleteWird(wird.id);
    return;
  }
  if (editCustomPreset) {
    controller.setCustomZikr(text: result.text, note: result.note, target: result.target);
  } else {
    controller.saveWird(id: wird?.id, text: result.text, note: result.note, target: result.target);
  }
}

/// A number typed by the reader as the target (0 = unlimited).
Future<void> showCustomTargetDialog(BuildContext context, TasbeehController controller) async {
  final entered = await showDialog<int>(
    context: context,
    builder: (_) => _TargetDialog(initial: controller.target),
  );
  if (entered != null) controller.setTarget(entered);
}

class _WirdDraft {
  const _WirdDraft({required this.text, required this.note, required this.target, this.delete = false});

  final String text;
  final String note;
  final int target;
  final bool delete;
}

class _WirdEditorSheet extends StatefulWidget {
  const _WirdEditorSheet({
    required this.initialText,
    required this.initialNote,
    required this.initialTarget,
    required this.canDelete,
    required this.title,
  });

  final String initialText;
  final String initialNote;
  final int initialTarget;
  final bool canDelete;
  final String title;

  @override
  State<_WirdEditorSheet> createState() => _WirdEditorSheetState();
}

class _WirdEditorSheetState extends State<_WirdEditorSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText);
  late final TextEditingController _note = TextEditingController(text: widget.initialNote);
  late final TextEditingController _target = TextEditingController(
    text: widget.initialTarget == 0 ? '' : '${widget.initialTarget}',
  );
  late int _chosen = widget.initialTarget;

  @override
  void dispose() {
    _text.dispose();
    _note.dispose();
    _target.dispose();
    super.dispose();
  }

  void _pick(int value) {
    setState(() {
      _chosen = value;
      _target.text = value == 0 ? '' : '$value';
    });
  }

  void _save() {
    final words = _text.text.trim();
    if (words.isEmpty) return;
    Navigator.of(context).pop(
      _WirdDraft(text: words, note: _note.text.trim(), target: TasbeehController.clampTarget(_chosen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GlassPanel(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  GlassSectionHeader(
                    title: widget.title,
                    trailing: IconButton(
                      tooltip: 'بند کریں',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _text,
                    autofocus: widget.initialText.isEmpty,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 300,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 18, height: 1.6),
                    decoration: const InputDecoration(
                      labelText: 'ورد / ذکر کے الفاظ',
                      hintText: 'مثلاً: یا علی مدد  •  صلوات  •  یا حسین',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    maxLines: 1,
                    maxLength: 120,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      labelText: 'معنی یا نیت (اختیاری)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'کتنی بار پڑھنا ہے؟',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      for (final choice in TasbeehController.quickTargets)
                        GlassChip(
                          label: choice == 0 ? 'لامحدود' : '$choice',
                          selected: _chosen == choice,
                          onTap: () => _pick(choice),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _target,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    style: const TextStyle(fontFamily: kDigitFont, fontSize: 18, fontWeight: FontWeight.w700),
                    onChanged: (value) => setState(() => _chosen = int.tryParse(value) ?? 0),
                    decoration: const InputDecoration(
                      labelText: 'اپنی تعداد لکھیں (خالی = لامحدود)',
                      prefixIcon: Icon(Icons.pin_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      if (widget.canDelete) ...<Widget>[
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(
                            const _WirdDraft(text: '', note: '', target: 0, delete: true),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('حذف کریں'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _text.text.trim().isEmpty ? null : _save,
                          icon: const Icon(Icons.check, size: 19),
                          label: const Text('محفوظ کریں اور شروع کریں', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ],
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

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.initial});

  final int initial;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final TextEditingController _value =
      TextEditingController(text: widget.initial == 0 ? '' : '${widget.initial}');

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(int.tryParse(_value.text.trim()) ?? 0);

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return AlertDialog(
      backgroundColor: palette.solid,
      title: const Text('اپنی تعداد مقرر کریں', style: TextStyle(fontSize: 18)),
      content: TextField(
        controller: _value,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(7),
        ],
        onSubmitted: (_) => _submit(),
        style: const TextStyle(fontFamily: kDigitFont, fontSize: 22, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(hintText: 'مثلاً 313 (خالی = لامحدود)'),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('منسوخ')),
        FilledButton(onPressed: _submit, child: const Text('ٹھیک ہے')),
      ],
    );
  }
}

class _Ripple {
  _Ripple(this.controller, this.centre);

  final AnimationController controller;
  final Offset centre;
}

class _PostPrayerNote extends StatelessWidget {
  const _PostPrayerNote({required this.palette});

  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(12),
      shadow: false,
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 18, color: palette.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'نماز کے بعد کا معمول: تسبیحِ زہرا (س) شروع ہے — اللہ اکبر سے آغاز کریں',
              style: TextStyle(fontSize: 13.5, height: 1.5, color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preset picker: the Zahra sequence, the common single zikr, "my own
/// dhikr", and every wird the reader saved — plus a chip to write a new one.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'ذکر منتخب کریں'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final preset in TasbeehPreset.all)
                GlassChip(
                  label: preset.titleUrdu,
                  selected: preset.key == controller.preset.key,
                  icon: preset.custom ? Icons.edit_outlined : null,
                  onTap: () => controller.selectPreset(preset.key),
                ),
              for (final wird in controller.wirds)
                GestureDetector(
                  onLongPress: () => unawaited(showWirdEditor(context, wird: wird)),
                  child: GlassChip(
                    label: TasbeehPreset.shortTitle(wird.text),
                    icon: Icons.bookmark_outline,
                    tone: palette.gold,
                    selected: controller.activeWird?.id == wird.id,
                    onTap: () => controller.selectWird(wird.id),
                  ),
                ),
              GlassChip(
                label: 'نیا ورد',
                icon: Icons.add,
                tone: palette.gold,
                onTap: () => unawaited(showWirdEditor(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            controller.wirds.isEmpty
                ? controller.preset.noteUrdu
                : '${controller.preset.noteUrdu}  •  اپنے ورد میں ترمیم کے لیے اسے دبا کر رکھیں',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

/// The dhikr itself — in Arabic for the built-in ones, as the reader wrote it
/// for their own — with its meaning, and an edit button for "my own".
class _ZikrCard extends StatelessWidget {
  const _ZikrCard({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final preset = controller.preset;
    final wird = controller.activeWird;
    final own = preset.custom;
    final arabic = !own || looksArabic(controller.step.arabic);
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (own)
            Row(
              children: <Widget>[
                Icon(Icons.bookmark, size: 17, color: palette.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    wird != null ? 'میرا ورد' : 'اپنا ذکر',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.gold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(
                    wird != null
                        ? showWirdEditor(context, wird: wird)
                        : showWirdEditor(context, editCustomPreset: true),
                  ),
                  icon: const Icon(Icons.edit, size: 17),
                  label: Text(
                    wird != null || controller.customText.isNotEmpty ? 'ترمیم' : 'اپنا ورد لکھیں',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ],
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: Column(
              key: ValueKey<String>('${preset.key}-${controller.stepIndex}-${controller.step.arabic}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    controller.step.arabic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: arabic ? kArabicFont : null,
                      fontSize: arabic ? 30 : 27,
                      height: 1.6,
                      color: palette.isDark ? palette.accent : kForest,
                    ),
                  ),
                ),
                if (controller.step.urdu.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    controller.step.urdu,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5, color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The ring and the tap zone. Everything inside the circle is painted by the
/// ring painter, so nothing here can shift the layout when the count changes.
class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.controller,
    required this.ripples,
    required this.flash,
    required this.onTap,
  });

  static const double size = 268;
  static const double tapSize = 204;

  final TasbeehController controller;
  final List<_Ripple> ripples;
  final AnimationController flash;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final target = controller.target;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => onTap(details.localPosition),
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[flash, ...ripples.map((r) => r.controller)]),
            builder: (context, _) {
              final flashValue = 1 - flash.value;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  CustomPaint(
                    size: const Size(size, size),
                    painter: _RingPainter(
                      progress: controller.progress,
                      target: target,
                      palette: palette,
                      pulse: flashValue,
                    ),
                  ),
                  for (final ripple in ripples)
                    _RippleDot(ripple: ripple, palette: palette),
                  Container(
                    width: tapSize,
                    height: tapSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          palette.accent.withValues(alpha: 0.16 + 0.16 * (1 - flashValue)),
                          palette.accent.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'گنتی',
                          style: TextStyle(fontSize: 13, color: palette.muted),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatCount(controller.count),
                            style: TextStyle(
                              fontFamily: kDigitFont,
                              fontSize: 64,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              color: flashValue > 0.6 ? palette.gold : palette.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          target == 0
                              ? 'لامحدود — ہر 100 پر نیا دور'
                              : 'ہدف ${formatCount(target)}  •  باقی '
                                  '${formatCount(controller.remaining ?? 0)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: palette.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'دبائیں',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.accent.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RippleDot extends StatelessWidget {
  const _RippleDot({required this.ripple, required this.palette});

  final _Ripple ripple;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final value = ripple.controller.value;
    return Positioned(
      left: ripple.centre.dx - 90,
      top: ripple.centre.dy - 90,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - value).clamp(0.0, 1.0),
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  palette.accent.withValues(alpha: 0.0),
                  palette.accent.withValues(alpha: 0.18),
                  palette.accent.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.35, 0.72, 1.0],
              ),
            ),
            transform: Matrix4.identity()
              ..scaleByDouble(
                0.65 + 0.35 * value,
                0.65 + 0.35 * value,
                1,
                1,
              ),
            transformAlignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

/// Track, progress arc, and the tick marks of the target.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.target,
    required this.palette,
    required this.pulse,
  });

  final double progress;
  final int target;
  final GlassPalette palette;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 22) / 2;
    const stroke = 11.0;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = palette.track,
    );

    // Progress: starts at twelve o'clock and sweeps clockwise.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      math.max(0.001, progress) * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = palette.accent,
    );

    // A gold glow when a step has just been completed.
    if (pulse > 0.05) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * (0.6 + pulse)
          ..color = palette.gold.withValues(alpha: 0.16 * pulse),
      );
    }

    // Tick marks: one per repetition for the small targets, else 100.
    final ticks = target == 0 ? 100 : (target <= 100 ? target : 100);
    if (ticks > 0 && ticks <= 100) {
      final tickPaint = Paint()
        ..strokeWidth = 2
        ..color = palette.accent.withValues(alpha: 0.28);
      final completed = (progress * ticks).floor();
      for (int index = 0; index < ticks; index++) {
        final angle = -math.pi / 2 + (2 * math.pi * index / ticks);
        final inner = radius - stroke / 2 - 6;
        final outer = inner - 5;
        final paint = index < completed
            ? (Paint()
              ..strokeWidth = 2.4
              ..color = palette.accent)
            : tickPaint;
        canvas.drawLine(
          centre + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
          centre + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.target != target ||
      old.pulse != pulse ||
      old.palette.track != palette.track;
}

/// Under the ring: take back a bead counted by mistake, or switch the zikr.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GlassChip(
          label: 'ایک دانہ واپس',
          icon: Icons.undo,
          onTap: controller.count > 0 ? controller.undo : null,
        ),
        const SizedBox(width: 8),
        GlassChip(
          label: 'ذکر بدلیں',
          icon: Icons.swap_horiz,
          tone: palette.gold,
          onTap: () => unawaited(showWirdPicker(context)),
        ),
      ],
    );
  }
}

/// The three steps of Tasbeeh-e-Zahra (s.a.): which one is running and what
/// comes next. For single-zikr presets this shows the round count instead.
class _StepTracker extends StatelessWidget {
  const _StepTracker({required this.controller, required this.justCompleted});

  final TasbeehController controller;
  final String? justCompleted;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final steps = controller.preset.steps;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassSectionHeader(
            title: controller.preset.titleUrdu,
            trailing: Text(
              'دور: ${formatCount(controller.rounds)}',
              style: TextStyle(fontSize: 13.5, color: palette.muted),
            ),
          ),
          const SizedBox(height: 10),
          if (steps.length > 1)
            Row(
              children: <Widget>[
                for (int index = 0; index < steps.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _StepTile(
                        step: steps[index],
                        index: index,
                        done: index < controller.stepIndex,
                        active: index == controller.stepIndex,
                        count: index == controller.stepIndex ? controller.count : 0,
                        palette: palette,
                        onTap: () => controller.selectStep(index),
                      ),
                    ),
                  ),
              ],
            )
          else
            _ProgressLine(controller: controller, palette: palette),
          if (justCompleted != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.check_circle, size: 16, color: palette.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'مرحلہ مکمل ہو گیا — «$justCompleted» پوری ہوئی',
                    style: TextStyle(fontSize: 13, color: palette.ink),
                  ),
                ),
              ],
            ),
            if (steps.length > 1) ...<Widget>[
              const SizedBox(height: 4),
              _ProgressLine(controller: controller, palette: palette),
            ],
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.index,
    required this.done,
    required this.active,
    required this.count,
    required this.palette,
    required this.onTap,
  });

  final TasbeehStep step;
  final int index;
  final bool done;
  final bool active;
  final int count;
  final GlassPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = done
        ? palette.gold
        : (active ? palette.accent : palette.muted);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? palette.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? palette.accent.withValues(alpha: 0.45) : palette.track,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 18,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  step.arabic,
                  style: TextStyle(
                    fontFamily: kArabicFont,
                    fontSize: 16,
                    height: 1.1,
                    color: tint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count / ${step.target}',
              style: TextStyle(
                fontFamily: kDigitFont,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
            if (done)
              Icon(Icons.check, size: 13, color: palette.gold)
            else
              const SizedBox(height: 13),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.controller, required this.palette});

  final TasbeehController controller;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final target = controller.target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: controller.progress,
            minHeight: 6,
            backgroundColor: palette.track,
            valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          target == 0
              ? 'لامحدود — ${formatCount(controller.count)} بار'
              : '${formatCount(controller.count)} / ${formatCount(target)} بار مکمل',
          style: TextStyle(fontSize: 13, color: palette.muted),
        ),
      ],
    );
  }
}

/// The target of any one-step zikr: the quick choices, or a number the reader
/// types (313, 1100, 14000…).
class _TargetSelector extends StatelessWidget {
  const _TargetSelector({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final target = controller.target;
    final quick = TasbeehController.quickTargets;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassSectionHeader(
            title: 'تعداد (ہدف)',
            trailing: Text(
              target == 0 ? 'لامحدود' : formatCount(target),
              style: TextStyle(
                fontFamily: target == 0 ? null : kDigitFont,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: palette.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final choice in quick)
                GlassChip(
                  label: choice == 0 ? 'لامحدود' : '$choice',
                  selected: target == choice,
                  onTap: () => controller.setTarget(choice),
                ),
              GlassChip(
                label: quick.contains(target) ? 'اپنی تعداد' : 'اپنی تعداد: ${formatCount(target)}',
                icon: Icons.edit_outlined,
                tone: palette.gold,
                selected: !quick.contains(target),
                onTap: () => unawaited(showCustomTargetDialog(context, controller)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تعداد تبدیل کرنے سے موجودہ گنتی صفر ہو جاتی ہے؛ آج اور مجموعی گنتی محفوظ رہتی ہے۔',
            style: TextStyle(fontSize: 12, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

/// Today and lifetime totals — the part the reader must never lose.
class _Totals extends StatelessWidget {
  const _Totals({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return Row(
      children: <Widget>[
        _TotalTile(
          label: 'آج کا کل',
          value: formatCount(controller.dailyTotal),
          icon: Icons.today_outlined,
          palette: palette,
        ),
        const SizedBox(width: 10),
        _TotalTile(
          label: 'مجموعی گنتی',
          value: formatCount(controller.lifetimeTotal),
          icon: Icons.all_inclusive,
          palette: palette,
        ),
      ],
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.palette,
  });

  final String label;
  final String value;
  final IconData icon;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassPanel(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: palette.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: TextStyle(fontSize: 12.5, color: palette.muted)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontFamily: kDigitFont,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackControls extends StatelessWidget {
  const _FeedbackControls({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'آواز اور جھٹکا'),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: GlassChip(
                  label: 'ہر دانے پر ہلکا جھٹکا',
                  icon: controller.hapticsEnabled
                      ? Icons.vibration
                      : Icons.phonelink_erase,
                  selected: controller.hapticsEnabled,
                  onTap: controller.toggleHaptics,
                  dense: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassChip(
                  label: controller.soundEnabled ? 'کلک کی آواز: آن' : 'کلک کی آواز: آف',
                  icon: controller.soundEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                  selected: controller.soundEnabled,
                  tone: palette.gold,
                  onTap: controller.toggleSound,
                  dense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ہدف مکمل ہونے پر دوگنا جھٹکا اور نرم چائم بجتا ہے — نماز کے بعد تسبیحِ زہرا '
            'کے لیے بھی یہی ترتیب ہے۔',
            style: TextStyle(fontSize: 12, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ResetRow extends StatelessWidget {
  const _ResetRow({required this.controller, required this.onConfirm});

  final TasbeehController controller;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      shadow: false,
      child: Row(
        children: <Widget>[
          Expanded(
            child: GlassChip(
              label: 'ری سیٹ (تصدیق کے ساتھ)',
              icon: Icons.restart_alt,
              tone: palette.gold,
              onTap: onConfirm,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlassChip(
              label: 'فوری ری سیٹ',
              icon: Icons.timer_outlined,
              onTap: () {
                controller.reset(whole: true);
                unawaited(HapticFeedback.lightImpact());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('گنتی صفر کر دی گئی'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
