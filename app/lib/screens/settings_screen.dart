import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_installer.dart';
import '../data_packages.dart';
import '../library_repository.dart';
import '../services/community_stats.dart';
import '../widgets/reader_kit.dart';
import 'data_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.library,
    required this.installer,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final LibraryRepository library;
  final DataInstaller installer;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Local copy: the screen is pushed as a route, so it must show the choice
  /// the reader just made without waiting for the app to rebuild it.
  late ThemeMode _theme = widget.themeMode;
  double _fontScale = 1.0;
  String _script = 'both';
  bool _loading = true;
  bool _rebuilding = false;
  bool _verifying = false;
  String? _status;
  bool _statusError = false;
  CommunityStats _community = CommunityStats.empty;
  InstallRecord? _installRecord;
  bool _communityLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _loadCommunity() async {
    final service = CommunityStatsService();
    final record = await service.ensureInstallRecord();
    final cached = await service.cached();
    if (mounted) {
      setState(() {
        _installRecord = record;
        _community = cached;
        _communityLoaded = true;
      });
    }
    final fresh = await service.refresh();
    if (mounted) setState(() => _community = fresh);
  }

  Future<void> _load() async {
    unawaited(_loadCommunity());
    final preferences = await ReaderPreferences.load();
    if (!mounted) return;
    setState(() {
      _fontScale = preferences.fontScale;
      _script = preferences.script;
      _loading = false;
    });
  }

  Future<void> _saveFont(double value) async {
    setState(() => _fontScale = value);
    await ReaderPreferences().saveFontScale(value);
  }

  Future<void> _saveScript(String value) async {
    setState(() => _script = value);
    await ReaderPreferences().saveScript(value);
  }

  Future<void> _rebuildIndex() async {
    if (_rebuilding) return;
    setState(() {
      _rebuilding = true;
      _status = null;
    });
    try {
      await widget.library.rebuildSearchIndex(onProgress: (_, __) {});
      if (!mounted) return;
      setState(() {
        _status = 'تلاش کی فہرست دوبارہ بن گئی۔';
        _statusError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error.toString();
        _statusError = true;
      });
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  Future<void> _verifyData() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _status = 'فائلوں کی تصدیق ہو رہی ہے…';
      _statusError = false;
    });
    try {
      await widget.installer.loadCatalog(allowNetwork: false);
      final results = await widget.installer.verifyInstalled();
      final broken = results.where((entry) => !entry.$2).toList();
      if (!mounted) return;
      setState(() {
        _status = broken.isEmpty
            ? '${results.length} فائلیں درست ہیں۔'
            : 'خراب فائلیں: ${broken.map((entry) => entry.$1.titleUrdu).join('، ')} — دوبارہ ڈاؤن لوڈ کریں۔';
        _statusError = broken.isNotEmpty;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error.toString();
        _statusError = true;
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _openDataScreen() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DataScreen(library: widget.library, installer: widget.installer),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final installed = widget.library.installedBooks;
    final installedBytes = widget.installer.installedBytes();
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('ترتیبات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
              children: [
                const _SectionTitle('ڈیٹا'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: const JustifiedText(
                      'ڈاؤن لوڈ اور انسٹال',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const JustifiedText(
                      'کتابیں ڈاؤن لوڈ اور انسٹال کریں، یا انسٹال شدہ ڈیٹا دیکھیں',
                      maxLines: 2,
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(
                            builder: (_) => DataScreen(
                              library: widget.library,
                              installer: widget.installer,
                            ),
                          ))
                          .then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const _SectionTitle('مطالعہ'),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('روشن'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('تاریک'), icon: Icon(Icons.dark_mode)),
                    ButtonSegment(value: ThemeMode.system, label: Text('نظام'), icon: Icon(Icons.phone_android)),
                  ],
                  selected: {_theme},
                  onSelectionChanged: (selection) {
                    setState(() => _theme = selection.first);
                    widget.onThemeModeChanged(selection.first);
                  },
                ),
                const SizedBox(height: 16),
                JustifiedText('حروف کا سائز (${(_fontScale * 100).round()}٪)'),
                Slider(
                  value: _fontScale,
                  min: 0.85,
                  max: 1.6,
                  divisions: 15,
                  label: '${(_fontScale * 100).round()}%',
                  onChanged: (value) => setState(() => _fontScale = value),
                  onChangeEnd: _saveFont,
                ),
                const SizedBox(height: 8),
                JustifiedText('ڈیفالٹ متن'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'both', label: Text('عربی و اردو')),
                    ButtonSegment(value: 'arabic', label: Text('صرف عربی')),
                    ButtonSegment(value: 'urdu', label: Text('صرف اردو')),
                  ],
                  selected: {_script},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => _saveScript(selection.first),
                ),
                const SizedBox(height: 26),
                const _SectionTitle('ڈیٹا'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JustifiedText(
                          '${installed.length} کتب نصب ہیں • ${formatBytes(installedBytes)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        JustifiedText(
                          widget.library.hasFastSearch
                              ? 'تلاش کا مقامی انجن تیار ہے۔'
                              : 'تلاش بنیادی طریقے پر چل رہی ہے؛ فہرست دوبارہ بنائیں۔',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _openDataScreen,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('ڈیٹا کا انتظام'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _verifying ? null : _verifyData,
                              icon: _verifying
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.verified_outlined),
                              label: const Text('فائلیں جانچیں'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _rebuilding ? null : _rebuildIndex,
                              icon: _rebuilding
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh),
                              label: const Text('تلاش فہرست دوبارہ'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 10),
                  JustifiedText(
                    _status!,
                    style: TextStyle(
                      color: _statusError ? Theme.of(context).colorScheme.error : kForest,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                const _SectionTitle('About ShiaVerse — شیعہ ورس کے بارے میں'),
                const JustifiedText(
                  'ShiaVerse محض ایک ایپ نہیں، ایک مکمل ڈیجیٹل دینی لائبریری اور روحانی رفیق ہے: '
                  'قرآنِ کریم اردو ترجمہ و تفسیری حواشی کے ساتھ، مفاتیح الجنان کی دعائیں و اعمال، '
                  'صحیفہ سجادیہ، نہج البلاغہ کے خطبات، خطوط اور حکمت بھرے اقوال، چودہ معتبر کتبِ احادیث، '
                  'فقہی مسائل و فتاویٰ، شیعہ (جعفری) اوقاتِ نماز چھ متحرک آسمانی وال پیپرز کے ساتھ، '
                  'لائیو قبلہ نما، اور تسبیحِ زہرا (س) سمیت مکمل ڈیجیٹل تسبیح۔ '
                  'کمال یہ ہے کہ تقریباً تمام لائبریری مکمل آف لائن آپ کے فون میں محفوظ رہتی ہے اور تلاش بھی مقامی طور پر چلتی ہے — '
                  'نہ انتظار، نہ انٹرنیٹ کی محتاجی۔ خوب صورت تھیمز، واضح اردو و عربی خط، بک مارکس، نوٹس اور '
                  '「جہاں چھوڑا تھا وہیں سے آغاز」 جیسی سہولتیں اسے ہر مؤمن کے لیے روزمرہ کا ساتھی بناتی ہیں۔',
                  style: TextStyle(fontSize: 14, height: 1.8),
                ),
                const SizedBox(height: 14),
                const _SectionTitle('کریڈٹس (Credits)'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JustifiedText('HashTech', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        JustifiedText('کمپنی (Company)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        SizedBox(height: 10),
                        JustifiedText('Syed Sakhir Hashmi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        JustifiedText(
                          'مالک و ماسٹر مائنڈ (Owner & Mastermind) • ڈویلپر (Developer) • محقق (Researcher) • مؤلف (Author) • شاعر (Poet)',
                          style: TextStyle(fontSize: 13, height: 1.6),
                        ),
                        SizedBox(height: 8),
                        JustifiedText(
                          'ShiaVerse کا تصور، تحقیق، تحریر، ڈیزائن اور ترقی انہی کی کاوش ہے — HashTech کے تحت۔',
                          style: TextStyle(fontSize: 13.5, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                JustifiedText(
                  'نصب شدہ کتب: ${installed.map((book) => book.titleUrdu).join('، ')}',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 26),
                const _SectionTitle('ShiaVerse کمیونٹی (آخری ریکارڈ)'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CommunityRow(icon: Icons.install_mobile, label: 'کل انسٹالز (تمام صارفین)', value: _communityLoaded ? '${_community.totalInstalls}' : '…'),
                        _CommunityRow(icon: Icons.people_alt_outlined, label: 'ایکٹو صارفین (ابھی ایپ موجود)', value: _communityLoaded ? '${_community.activeUsers}' : '…'),
                        _CommunityRow(icon: Icons.touch_app_outlined, label: 'تمام صارفین کا مجموعی ذکر (تسبیح)', value: _communityLoaded ? '${_community.globalZikrTotal}' : '…'),
                        if (_community.updatedAt.isNotEmpty)
                          JustifiedText('آخری تجدید: ${_community.updatedAt}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const Divider(height: 22),
                        if (_installRecord != null) ...[
                          JustifiedText('اس ڈیوائس کا گمنام ریکارڈ: ${_installRecord!.anonymousId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          JustifiedText('انسٹال: ${_installRecord!.installedOn} • آخری فعالیت: ${_installRecord!.lastActiveOn}', style: const TextStyle(fontSize: 12.5)),
                        ],
                        const SizedBox(height: 6),
                        const JustifiedText(
                          'پرائیویسی: صرف ایک گمنام نمبر (ID)، انسٹال اور آخری فعالیت کی تاریخ محفوظ ہوتی ہے — نام، نمبر، مقام یا ڈیوائس کی کوئی ذاتی معلومات کبھی ریکارڈ نہیں کی جاتی۔ یہ عوامی اعداد پروجیکٹ کی مرکزی (main) برانچ کے فولڈر community_stats میں محفوظ ہوتے ہیں اور ہر صارف یہی ریکارڈ دیکھ سکتا ہے۔ انٹرنیٹ آن ہونے پر (مثلاً کتب ڈاؤن لوڈ کرتے وقت) یہ تازہ ہو جاتے ہیں۔',
                          style: TextStyle(fontSize: 12.5, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: JustifiedText(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      );
}

class _CommunityRow extends StatelessWidget {
  const _CommunityRow({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: kForest),
          const SizedBox(width: 8),
          Expanded(child: JustifiedText(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
      );
}
