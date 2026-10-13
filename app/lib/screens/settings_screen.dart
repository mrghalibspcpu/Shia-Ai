import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai_repository.dart';
import '../app_theme.dart';
import '../gemini_client.dart';
import '../text_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.ai,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final AiRepository ai;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _obscureKey = true;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String _model = kGeminiModelFallbacks.first;
  double _fontScale = 1.0;
  String? _status;
  bool _statusError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await widget.ai.configuredGeminiApiKey();
    final url = await widget.ai.configuredBaseUrl();
    final token = await widget.ai.configuredApiToken();
    final model = await widget.ai.configuredGeminiModel();
    if (!mounted) return;
    setState(() {
      _keyController.text = key;
      _urlController.text = looksLikeGeminiApiKey(url) ? '' : url;
      _tokenController.text = token;
      _model = model.isEmpty ? kGeminiModelFallbacks.first : model;
      _fontScale = (prefs.getDouble('reader_font_scale') ?? 1.0).clamp(0.85, 1.6);
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.ai.saveGeminiApiKey(_keyController.text);
      await widget.ai.saveGeminiModel(_model);
      await widget.ai.saveBaseUrl(_urlController.text);
      await widget.ai.saveApiToken(_tokenController.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('reader_font_scale', _fontScale);
      if (!mounted) return;
      setState(() {
        _status = 'ترتیبات محفوظ ہو گئیں۔';
        _statusError = false;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testKey() async {
    final key = _keyController.text.trim();
    if (!looksLikeGeminiApiKey(key)) {
      setState(() {
        _status = 'Google AI Studio کی کلید AIza سے شروع ہوتی ہے۔';
        _statusError = true;
      });
      return;
    }
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      await widget.ai.saveGeminiApiKey(key);
      await widget.ai.saveGeminiModel(_model);
      final message = await widget.ai.verifyGeminiApiKey(key);
      if (mounted) {
        setState(() {
          _status = message;
          _statusError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString();
          _statusError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('ترتیبات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                const JustifiedText('Google AI Studio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const JustifiedText(
                  'aistudio.google.com سے AIza سے شروع ہونے والی API کلید یہاں لگائیں۔ کلید صرف اسی فون کے محفوظ ذخیرے میں رہتی ہے، APK میں نہیں لکھی جاتی۔',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: _obscureKey,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Gemini API key (AIza…)',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: kGeminiModelFallbacks.contains(_model) ? _model : kGeminiModelFallbacks.first,
                  decoration: const InputDecoration(labelText: 'ماڈل'),
                  items: [
                    for (final model in kGeminiModelFallbacks)
                      DropdownMenuItem(value: model, child: Text(model, textDirection: TextDirection.ltr)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _model = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'محفوظ ہو رہا ہے…' : 'محفوظ کریں'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _testKey,
                        icon: _testing
                            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.verified_outlined),
                        label: const Text('کلید جانچیں'),
                      ),
                    ),
                  ],
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
                const SizedBox(height: 28),
                const JustifiedText('مطالعہ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('روشن'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('تاریک'), icon: Icon(Icons.dark_mode)),
                    ButtonSegment(value: ThemeMode.system, label: Text('نظام'), icon: Icon(Icons.phone_android)),
                  ],
                  selected: {widget.themeMode},
                  onSelectionChanged: (selection) => widget.onThemeModeChanged(selection.first),
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
                  onChangeEnd: (_) => _save(),
                ),
                const SizedBox(height: 18),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const JustifiedText('اعلیٰ اختیارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  children: [
                    const JustifiedText(
                      'اگر آپ خود سروس چلاتے ہیں تو HTTPS پتہ یہاں لکھیں۔ عام استعمال کے لیے صرف Gemini کلید کافی ہے۔',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      decoration: const InputDecoration(hintText: 'https://api.example.com'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tokenController,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      decoration: const InputDecoration(labelText: 'سروس access token'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
                const SizedBox(height: 24),
                const JustifiedText('شیعہ اے آئی', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const JustifiedText(
                  'چودہ کتب، 96 ہزار سے زائد روایات۔ تلاش فون پر ہوتی ہے؛ Gemini صرف آپ کی کلید سے جواب مرتب کرتا ہے۔',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
    );
  }
}
