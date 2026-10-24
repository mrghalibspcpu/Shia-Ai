/// ShiaAi chat screen.
///
/// The flow mirrors Aalim 360's grounded-answer pattern entirely on top of
/// the app's own corpus: ask → local retrieval over the installed SQLite
/// books → optional synthesis through the self-hosted gateway → citations
/// generated from the verified retrieved records → tapping a citation opens
/// that exact record through the existing [pushReaderFor] navigation. The
/// reader is pushed ON TOP of this screen, so Back restores the conversation
/// and its scroll position unchanged.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../reader_navigation.dart';
import '../shia_ai/shia_ai_engine.dart';
import '../shia_ai/shia_ai_gateway.dart';
import '../shia_ai/shia_ai_models.dart';
import '../shia_ai/shia_ai_retriever.dart';
import '../shia_ai/shia_ai_settings.dart';
import '../shia_ai/shia_ai_store.dart';

/// Opens the reader behind one citation. Injectable so widget tests can
/// verify navigation and the return trip without opening a real corpus DB.
typedef ShiaAiReaderOpener = Future<void> Function(
  BuildContext context,
  LibraryRepository library,
  ShiaAiCitation citation,
);

/// Production opener: the same navigation every other screen uses.
Future<void> defaultShiaAiOpener(
  BuildContext context,
  LibraryRepository library,
  ShiaAiCitation citation,
) async {
  final book = citation.book;
  if (book == null || !citation.isValid) return;
  await pushReaderFor(
    context,
    library: library,
    book: book,
    recordId: citation.recordId,
    sectionId: citation.sectionId,
    title: citation.sectionTitle,
  );
}

class ShiaAiChatScreen extends StatefulWidget {
  const ShiaAiChatScreen({
    super.key,
    required this.library,
    this.engine,
    this.opener = defaultShiaAiOpener,
    this.store = const ShiaAiConversationStore(),
    this.preferencesLoader = ShiaAiPreferences.load,
  });

  final LibraryRepository library;
  final ShiaAiEngine? engine;
  final ShiaAiReaderOpener opener;
  final ShiaAiConversationStore store;
  final Future<ShiaAiPreferences> Function() preferencesLoader;

  @override
  State<ShiaAiChatScreen> createState() => _ShiaAiChatScreenState();
}

class _ShiaAiChatScreenState extends State<ShiaAiChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  late final ShiaAiEngine _engine = widget.engine ??
      ShiaAiEngine(
        retriever: ShiaAiRetriever(library: widget.library),
        gateway: ShiaAiGateway(),
      );

  final List<ShiaAiMessage> _messages = <ShiaAiMessage>[];
  bool _busy = false;
  bool _booting = true;
  ShiaAiPreferences _preferences = const ShiaAiPreferences();

  static const List<String> _exampleQuestions = <String>[
    'وضو کیسے کریں؟',
    'نمازوں کو جمع کرنے کا حکم کیا ہے؟',
    'غسلِ جنابت کا طریقہ بتائیں',
    'مسافر نماز میں قصر کب کرے؟',
    'خمس کس پر واجب ہے؟',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final stored = await widget.store.loadMessages();
    final preferences = await widget.preferencesLoader();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(stored);
      _preferences = preferences;
      _booting = false;
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final question = raw.trim();
    if (question.isEmpty || _busy) return;
    final userMessage = ShiaAiMessage.user(
      question,
      id: 'u${DateTime.now().microsecondsSinceEpoch}',
    );
    setState(() {
      _messages.add(userMessage);
      _busy = true;
      _input.clear();
    });
    await widget.store.saveMessages(_messages);
    _scrollToEnd();

    ShiaAiReply reply;
    try {
      reply = await _engine.ask(question);
    } catch (_) {
      reply = const ShiaAiReply(
        answer: ShiaAiWording.serviceError,
        delivery: ShiaAiDelivery.serviceError,
      );
    }
    if (!mounted) return;
    setState(() {
      _messages.add(ShiaAiMessage.assistant(
        reply.answer.isEmpty ? ShiaAiWording.serviceError : reply.answer,
        id: 'a${DateTime.now().microsecondsSinceEpoch}',
        delivery: reply.delivery,
        citations: reply.citations,
        evidenceIds: reply.evidence.map((item) => item.citationId).toList(),
      ));
      _busy = false;
    });
    await widget.store.saveMessages(_messages);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openSettings() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ShiaAiSettingsSheet(initial: _preferences),
    );
    if (saved == true) {
      final preferences = await widget.preferencesLoader();
      if (mounted) setState(() => _preferences = preferences);
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('گفتگو مٹائیں؟'),
        content: const Text(
          'سوال و جواب کی یہ گفتگو ڈیوائس سے حذف ہو جائے گی۔ کتب اور تلاش پر کوئی اثر نہیں ہوگا۔',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('نہیں'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ہاں، مٹائیں'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.clear();
    if (!mounted) return;
    setState(_messages.clear);
  }

  void _showPrivacy() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ShiaAi اور رازداری'),
        content: const SingleChildScrollView(
          child: Text(
            '${ShiaAiWording.privacyNotice}\n\n'
            '• تلاش اور حوالہ جات مکمل طور پر آپ کی ڈیوائس پر موجود کتب سے بنتے ہیں۔\n'
            '• پوری کتاب یا ڈیٹا بیس کبھی اپ لوڈ نہیں ہوتا؛ صرف چند منتخب اقتباسات بھیجے جاتے ہیں۔\n'
            '• Gemini API کلید ایپ میں نہیں ہوتی؛ وہ آپ کے اپنے سرور پر محفوظ رہتی ہے۔\n'
            '• جب آن لائن موڈ بند ہو تو کوئی تحریر انٹرنیٹ پر نہیں جاتی۔\n'
            '• نصب کتب کے اشاعتی حقوق ابھی تک مکمل طور پر واضح نہیں؛ تفصیل ترتیبات › ماخذ اور حقوق میں دیکھیں۔',
            style: TextStyle(height: 1.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ٹھیک ہے'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ShiaAi', textDirection: TextDirection.ltr),
            Text(
              'نصب شدہ کتب سے حوالہ جات کے ساتھ سوال و جواب',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'رازداری',
            onPressed: _showPrivacy,
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
          IconButton(
            tooltip: 'ترتیبات',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'گفتگو مٹائیں',
            onPressed: _messages.isEmpty ? null : _confirmClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ModeBanner(
              online: _preferences.isConfigured,
              onConfigure: _openSettings,
            ),
            Expanded(
              child: _booting
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _EmptyState(onPick: _send, questions: _exampleQuestions)
                      : ListView.builder(
                          key: const ValueKey<String>('shia-ai-message-list'),
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                          itemCount: _messages.length + (_busy ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return const _ThinkingBubble();
                            }
                            return _MessageBubble(
                              message: _messages[index],
                              library: widget.library,
                              opener: widget.opener,
                            );
                          },
                        ),
            ),
            _Composer(
              controller: _input,
              focusNode: _focus,
              busy: _busy,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.online, required this.onConfigure});

  final bool online;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final color = online ? kForest : const Color(0xFF8A6A2F);
    return Material(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off,
                size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                online
                    ? 'آن لائن موڈ: منتخب اقتباسات آپ کے سرور اور Gemini کو بھیجے جائیں گے۔'
                    : 'مقامی موڈ: جواب صرف آپ کی کتب سے، کوئی تحریر انٹرنیٹ پر نہیں جائے گی۔',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: color),
              ),
            ),
            TextButton(
              onPressed: onConfigure,
              child: Text(online ? 'تبدیلی' : 'فعال کریں'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick, required this.questions});

  final ValueChanged<String> onPick;
  final List<String> questions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 18),
        Icon(Icons.auto_awesome, size: 46,
            color: theme.colorScheme.primary.withValues(alpha: 0.55)),
        const SizedBox(height: 14),
        Text(
          'ShiaAi سے پوچھیں',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'جواب صرف آپ کی نصب شدہ کتب میں موجود عبارتوں سے بنتا ہے۔ حوالہ ٹیپ کریں تو اصل آیت، حدیث، فتویٰ یا دعا اسی ایپ میں کھل جائے گی۔',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.9, fontSize: 14),
        ),
        const SizedBox(height: 22),
        for (final question in questions)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(question),
              trailing: const Icon(Icons.send, size: 18),
              onTap: () => onPick(question),
            ),
          ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: busy ? null : onSend,
              decoration: InputDecoration(
                hintText: 'اپنا سوال اردو، عربی یا رومن اردو میں لکھیں…',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            elevation: 1,
            onPressed: busy ? null : () => onSend(controller.text),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: AlignmentDirectional.centerStart,
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              SizedBox(width: 10),
              Text('مقامی کتب تلاش کی جا رہی ہیں…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.library,
    required this.opener,
  });

  final ShiaAiMessage message;
  final LibraryRepository library;
  final ShiaAiReaderOpener opener;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (message.isUser) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(message.text, style: const TextStyle(height: 1.8)),
        ),
      );
    }

    const amber = Color(0xFF8A6A2F);
    final (Color accent, IconData icon) = switch (message.delivery) {
      ShiaAiDelivery.answered => (kForest, Icons.verified_outlined),
      ShiaAiDelivery.abstained => (amber, Icons.info_outline),
      ShiaAiDelivery.noEvidence => (amber, Icons.info_outline),
      ShiaAiDelivery.offlineSources =>
        (const Color(0xFF546E7A), Icons.cloud_off),
      _ => (const Color(0xFFB26A00), Icons.error_outline),
    };

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'ShiaAi',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.labelLarge?.copyWith(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(message.text, style: const TextStyle(height: 1.95)),
              if (message.hasCitations) ...[
                const SizedBox(height: 10),
                Text(
                  'حوالہ جات — ٹیپ کر کے اصل عبارت کھولیں',
                  style: theme.textTheme.labelMedium?.copyWith(color: accent),
                ),
                const SizedBox(height: 6),
                for (final citation in message.citations)
                  _CitationTile(
                    citation: citation,
                    library: library,
                    opener: opener,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CitationTile extends StatelessWidget {
  const _CitationTile({
    required this.citation,
    required this.library,
    required this.opener,
  });

  final ShiaAiCitation citation;
  final LibraryRepository library;
  final ShiaAiReaderOpener opener;

  @override
  Widget build(BuildContext context) {
    final locator = [
      if (citation.locator.isNotEmpty) citation.locator,
      if (citation.sourceRef.isNotEmpty) citation.sourceRef,
      if (citation.page != null) 'صفحہ ${citation.page}',
    ].join(' • ');
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.45),
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => opener(context, library, citation),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.menu_book, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      citation.shortLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    if (locator.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          locator,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              if (citation.hasWebSource)
                IconButton(
                  tooltip: 'سرکاری ماخذ',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => unawaited(launchUrl(
                    Uri.parse(citation.sourceUrl),
                    mode: LaunchMode.externalApplication,
                  )),
                ),
              const Icon(Icons.chevron_left, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Configuration sheet: gateway URL + explicit online-synthesis consent.
/// Reachable from the chat app bar and from Settings.
class ShiaAiSettingsSheet extends StatefulWidget {
  const ShiaAiSettingsSheet({super.key, required this.initial});

  final ShiaAiPreferences initial;

  @override
  State<ShiaAiSettingsSheet> createState() => _ShiaAiSettingsSheetState();
}

class _ShiaAiSettingsSheetState extends State<ShiaAiSettingsSheet> {
  late final TextEditingController _url =
      TextEditingController(text: widget.initial.gatewayUrl);
  late bool _enabled = widget.initial.onlineEnabled;
  bool _saving = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final preferences = ShiaAiPreferences(
      gatewayUrl: _url.text,
      onlineEnabled: _enabled,
    );
    setState(() => _saving = true);
    await preferences.save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text('ShiaAi کی ترتیبات',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            const Text(ShiaAiWording.privacyNotice,
                style: TextStyle(height: 1.9, fontSize: 13.5)),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: const Text('آن لائن خلاصہ فعال کریں'),
              subtitle: const Text(
                'بند رکھنے پر صرف مقامی تلاش اور حوالہ جات ملیں گے؛ کچھ بھی نہیں بھیجا جائے گا۔',
                style: TextStyle(height: 1.6),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _url,
              enabled: _enabled,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'آپ کے ShiaAi گیٹ وے کا HTTPS پتہ',
                hintText: 'https://shia-ai-gateway.example.workers.dev',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gemini کلید اس ایپ میں کبھی نہیں لکھی جاتی۔ سرور کی تنصیب کی ہدایت '
              'repository میں backend/shia-ai-gateway/README.md میں ہے۔',
              style: TextStyle(height: 1.7, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('محفوظ کریں'),
            ),
          ],
        ),
      ),
    );
  }
}
