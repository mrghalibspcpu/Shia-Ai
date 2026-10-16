import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../data_installer.dart';
import '../data_packages.dart';
import '../library_repository.dart';
import '../services/backup_service.dart';
import '../widgets/reader_kit.dart';
import 'data_screen.dart';
import 'privacy_policy_screen.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
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

  bool _backupBusy = false;

  /// The reader's own data — the exact set `BackupService` serialises.
  Future<BackupService> _backupService() async =>
      BackupService(await SharedPreferences.getInstance());

  List<String> _installedDatabaseNames() => widget.installer.catalog.packages
      .where(widget.installer.isInstalled)
      .map((package) => package.fileName)
      .toList();

  void _report(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _statusError = error;
    });
  }

  /// Saves the complete user state as a JSON file, wherever the reader
  /// chooses (Downloads, Drive, WhatsApp…). Books are re-downloadable and
  /// stay out of the file.
  Future<void> _exportBackup() async {
    if (_backupBusy) return;
    setState(() {
      _backupBusy = true;
      _status = null;
      _statusError = false;
    });
    try {
      final json = (await _backupService()).exportJson(
        installedDatabases: _installedDatabaseNames(),
      );
      final stamp = DateTime.now().toUtc().toIso8601String().split('.').first.replaceAll(':', '-');
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'بیک اپ محفوظ کریں',
        fileName: 'shiaverse-backup-$stamp.json',
        bytes: BackupService.encodeFileBytes(json),
      );
      _report(saved == null
          ? 'بیک اپ محفوظ نہیں ہوا (عمل منسوخ یا فائل نہیں بنی)۔'
          : 'بیک اپ محفوظ ہو گیا — فائل کو محفوظ جگہ پر رکھیں۔');
    } catch (error) {
      _report('بیک اپ محفوظ نہیں ہوا: $error', error: true);
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  /// The clipboard fallback: same JSON, copy-pasteable anywhere.
  Future<void> _exportBackupToClipboard() async {
    if (_backupBusy) return;
    setState(() {
      _backupBusy = true;
      _status = null;
      _statusError = false;
    });
    try {
      final json = (await _backupService()).exportJson(
        installedDatabases: _installedDatabaseNames(),
      );
      await Clipboard.setData(ClipboardData(text: json));
      _report('بیک اپ کاپی ہو گیا — کسی محفوظ جگہ (نوٹس/WhatsApp/ای میل) میں چسپاں کریں۔');
    } catch (error) {
      _report('بیک اپ کاپی نہیں ہوا: $error', error: true);
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importBackup() async {
    if (_backupBusy) return;
    setState(() {
      _backupBusy = true;
      _status = null;
      _statusError = false;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(withData: true);
      if (picked == null || picked.files.isEmpty) {
        _report('کوئی فائل منتخب نہیں ہوئی۔');
        return;
      }
      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        _report('فائل نہیں پڑھی جا سکی — دوبارہ کوشش کریں۔', error: true);
        return;
      }
      await _restoreBackup(BackupService.decodeFileBytes(bytes));
    } catch (error) {
      _report('بیک اپ بحال نہیں ہوا: $error', error: true);
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importBackupFromClipboard() async {
    if (_backupBusy) return;
    setState(() {
      _backupBusy = true;
      _status = null;
      _statusError = false;
    });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.trim().isEmpty) {
        _report('کلپ بورڈ خالی ہے — پہلے بیک اپ کاپی کریں۔', error: true);
        return;
      }
      await _restoreBackup(text);
    } catch (error) {
      _report('بیک اپ بحال نہیں ہوا: $error', error: true);
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  /// Validates, confirms, then replaces the device state with the backup.
  Future<void> _restoreBackup(String text) async {
    final backup = BackupService.parse(text);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const JustifiedText('بیک اپ بحال کریں؟'),
        content: JustifiedText(
          'اس فائل میں ${backup.bookmarkCount} بک مارکس، ${backup.noteCount} نوٹ اور دیگر ترتیبات ہیں۔ '
          'اس ڈیوائس کا موجودہ ذاتی ڈیٹا اس سے بدل جائے گا۔ کتابیں اپنے آپ دوبارہ '
          'ڈاؤن لوڈ کرنی پڑیں گی۔ جاری رکھیں؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('منسوخ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('بحال کریں')),
        ],
      ),
    );
    if (confirmed != true) {
      _report('بیک اپ بحال نہیں کیا گیا۔');
      return;
    }
    final summary = await (await _backupService()).restore(backup);
    widget.library.invalidateUserStateCache();
    final books = summary.installedDatabases.length;
    _report(
      'بیک اپ بحال ہو گیا: ${summary.restored} اشیاء۔ '
      '${books > 0 ? 'پہلے $books کتابیں نصب تھیں — انہیں ڈاؤن لوڈ صفحے سے دوبارہ انسٹال کریں۔ ' : ''}'
      'مکمل اثر کے لیے ایپ بند کر کے دوبارہ کھولیں۔',
    );
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
                const _SectionTitle('بیک اپ و منتقلی'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JustifiedText(
                          'محفوظات، نوٹ، آخری مقامات، تسبیح اور ترتیبات کا ذاتی ڈیٹا فائل میں محفوظ کریں — '
                          'نئے فون یا نئی ایپ پر بحالی کے لیے۔ کتابیں اس فائل میں نہیں جاتیں؛ وہ ڈاؤن لوڈ '
                          'صفحے سے دوبارہ انسٹال ہو جاتی ہیں۔',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _backupBusy ? null : _exportBackup,
                              icon: const Icon(Icons.save_alt),
                              label: const Text('بیک اپ محفوظ کریں'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _backupBusy ? null : _importBackup,
                              icon: const Icon(Icons.settings_backup_restore),
                              label: const Text('بیک اپ بحال کریں'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _backupBusy ? null : _exportBackupToClipboard,
                              icon: const Icon(Icons.copy),
                              label: const Text('کلپ بورڈ پر کاپی'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _backupBusy ? null : _importBackupFromClipboard,
                              icon: const Icon(Icons.paste),
                              label: const Text('کلپ بورڈ سے بحالی'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionTitle('ایپ کے بارے میں'),
                JustifiedText(
                  'ShiaVerse ایک مکمل آف لائن مطالعہ گاہ ہے: قرآنِ کریم اردو ترجمہ اور تفسیری حواشی کے ساتھ، '
                  'مفاتیح الجنان کی دعائیں و اعمال، نہج البلاغہ کے خطبات و خطوط و حکمت، اور چودہ کتبِ احادیث۔ '
                  'تمام متن فون پر محفوظ رہتا ہے اور تلاش مقامی طور پر چلتی ہے۔',
                  style: TextStyle(fontSize: 14, height: 1.7),
                ),
                const SizedBox(height: 12),
                JustifiedText(
                  'نصب شدہ کتب: ${installed.map((book) => book.titleUrdu).join('، ')}',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const JustifiedText(
                      'رازداری کی پالیسی',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const JustifiedText(
                      'یہ ایپ کیا ڈیٹا محفوظ کرتی ہے اور کیا کہیں نہیں بھیجتی',
                      maxLines: 2,
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ));
                    },
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
