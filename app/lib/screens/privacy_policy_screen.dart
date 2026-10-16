import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';

/// The privacy policy, read from the bundled `assets/privacy-policy.md`.
///
/// Bundled on purpose: the policy stays readable offline, and the copy the
/// reader sees is the same file the repository publishes at
/// `docs/privacy-policy.md`. A button opens the hosted page online.
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  /// The hosted copy of the policy, kept in step with `docs/privacy-policy.md`.
  static final Uri hostedPolicy =
      Uri.parse('https://github.com/mrghalibspcpu/Shia-Ai/blob/main/docs/privacy-policy.md');

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  String _text = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    String text;
    try {
      text = await rootBundle.loadString('assets/privacy-policy.md');
    } catch (_) {
      text = 'رازداری کی پالیسی فائل دستیاب نہیں — براہِ کرم ایپ اپ ڈیٹ کریں۔';
    }
    if (!mounted) return;
    setState(() => _text = text);
  }

  Future<void> _openHosted() async {
    await launchUrl(PrivacyPolicyScreen.hostedPolicy, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const JustifiedText('رازداری کی پالیسی'),
        actions: [
          IconButton(
            onPressed: _openHosted,
            icon: const Icon(Icons.open_in_new),
            tooltip: 'آن لائن ورژن کھولیں',
          ),
        ],
      ),
      body: _text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
              child: SelectableText(
                _text,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
    );
  }
}
