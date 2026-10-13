import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai_repository.dart';
import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import 'library_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.library, required this.ai, this.onOpenSettings});

  final LibraryRepository library;
  final AiRepository ai;
  final VoidCallback? onOpenSettings;

  @override
  AiChatScreenState createState() => AiChatScreenState();
}

class AiChatScreenState extends State<AiChatScreen> {
  static const String _historyKey = 'shia_ai_chat_messages';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _restoring = true;
  bool _sending = false;
  String? _error;
  String? _readerContext;
  ReaderTarget? _readerTarget;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreMessages());
  }

  Future<void> _restoreMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_historyKey);
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          _messages.addAll(decoded.whereType<Map>().map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item))));
        }
      }
    } catch (_) {
      // Ignore an older/corrupt local transcript rather than blocking the library.
    }
    if (mounted) {
      setState(() => _restoring = false);
      _scrollToBottom(jump: true);
    }
  }

  Future<void> _persistMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_messages.map((message) => message.toJson()).toList()));
  }

  void setReaderContext(BookDefinition book, Passage passage) {
    _readerTarget = ReaderTarget(
      book: book.key,
      recordId: passage.recordId,
      sectionId: passage.sectionId,
      page: passage.page,
    );
    _readerContext = [
      'کتاب: ${book.titleUrdu}',
      if (passage.chapterTitle.isNotEmpty) 'باب: ${passage.chapterTitle}',
      if (passage.sectionTitle.isNotEmpty) 'فصل: ${passage.sectionTitle}',
      'حدیث نمبر: ${passage.recordId}${passage.page == null ? '' : '، صفحہ: ${passage.page}'}',
    ].join('\n');
    if (mounted) setState(() {});
  }

  Future<void> _sendQuestion(String value, {bool retry = false}) async {
    final question = value.trim();
    if (question.isEmpty || _sending) return;

    int userIndex;
    if (retry) {
      userIndex = _messages.lastIndexWhere((message) => message.isUser);
      if (userIndex < 0) return;
    } else {
      userIndex = _messages.length;
      setState(() {
        _messages.add(ChatMessage(isUser: true, text: question, createdAt: DateTime.now()));
        _error = null;
        _sending = true;
      });
      _inputController.clear();
      await _persistMessages();
      _scrollToBottom();
    }

    if (retry) setState(() { _error = null; _sending = true; });
    final contextText = _readerContext;
    final target = _readerTarget;
    try {
      final answer = await widget.ai.ask(
        question,
        _messages.take(userIndex).toList(),
        readerContext: contextText,
        readerTarget: target,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(answer);
        _readerContext = null;
        _readerTarget = null;
        _error = null;
      });
      await _persistMessages();
      _scrollToBottom();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      }
    });
  }

  void _openSettings() {
    final opener = widget.onOpenSettings;
    if (opener != null) {
      opener();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ترتیبات والے صفحے پر Google AI Studio کی کلید درج کریں۔')),
    );
  }

  Future<void> _clearConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const JustifiedText('گفتگو صاف کریں؟'),
        content: const JustifiedText('یہ گفتگو اس آلے سے حذف ہو جائے گی۔'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('منسوخ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('صاف کریں')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _messages.clear(); _error = null; _readerContext = null; _readerTarget = null; });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await widget.ai.resetSession();
  }

  void _openCitation(AiSource source) {
    final book = BookDefinition.byKey(source.target.book);
    if (book == null || source.target.recordId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اس حوالہ کا مطالعہ پتہ دستیاب نہیں۔')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderScreen(
        library: widget.library,
        book: book,
        recordId: source.target.recordId,
        sectionId: source.target.sectionId,
        sectionTitle: source.citation,
        cameFromAi: true,
      ),
    ));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [Icon(Icons.auto_awesome, color: kGold, size: 21), SizedBox(width: 8), Text('شیعہ اے آئی')],
        ),
        actions: [
          IconButton(tooltip: 'API کلید', onPressed: _openSettings, icon: const Icon(Icons.settings_outlined)),
          IconButton(tooltip: 'گفتگو صاف کریں', onPressed: _clearConversation, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _restoring ? const Center(child: CircularProgressIndicator()) : _buildConversation()),
          if (_readerContext != null) _ContextBanner(text: _readerContext!, onClose: () => setState(() { _readerContext = null; _readerTarget = null; })),
          if (_error != null) _ErrorBanner(message: _error!, onRetry: _retryLast),
          _Composer(
            controller: _inputController,
            sending: _sending,
            onSend: () => _sendQuestion(_inputController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    if (_messages.isEmpty) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        children: [
          const SizedBox(height: 32),
          CircleAvatar(radius: 34, backgroundColor: kForest.withValues(alpha: 0.10), child: const Icon(Icons.auto_awesome, color: kForest, size: 34)),
          const SizedBox(height: 18),
          const Center(child: JustifiedText('السلام علیکم', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          const Center(child: JustifiedText('شیعہ روایات کے بارے میں سوال کریں۔ تلاش فون پر ہوتی ہے؛ مکمل جواب کے لیے ترتیبات میں Google AI Studio کی AIza کلید لگائیں۔', style: TextStyle(fontSize: 17))),
          const SizedBox(height: 22),
          for (final prompt in const [
            'امیرالمومنینؑ کے فضائل پر روایات دکھائیں',
            'نماز کے بارے میں الکافی کی روایت تلاش کریں',
            'عربی متن کے ساتھ اردو ترجمہ سمجھائیں',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: ActionChip(
                avatar: const Icon(Icons.arrow_back, size: 16),
                label: JustifiedText(prompt, style: const TextStyle(fontSize: 14)),
                onPressed: _sending ? null : () => _sendQuestion(prompt),
              ),
            ),
        ],
      );
    }
    return ListView.builder(
      key: const PageStorageKey('shia-ai-chat-scroll'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (_sending && index == _messages.length) return const _ThinkingBubble();
        final message = _messages[index];
        return _ChatBubble(message: message, onCheckSource: _openCitation);
      },
    );
  }

  void _retryLast() {
    final index = _messages.lastIndexWhere((message) => message.isUser);
    if (index < 0) return;
    _sendQuestion(_messages[index].text, retry: true);
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onCheckSource});

  final ChatMessage message;
  final ValueChanged<AiSource> onCheckSource;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colors = Theme.of(context).colorScheme;
    final bubbleColor = isUser ? colors.primary : Theme.of(context).cardTheme.color;
    final textColor = isUser ? Colors.white : colors.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.88),
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(19),
            topRight: const Radius.circular(19),
            bottomLeft: Radius.circular(isUser ? 5 : 19),
            bottomRight: Radius.circular(isUser ? 19 : 5),
          ),
          boxShadow: [if (!isUser) BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MessageText(message.text, color: textColor),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: textColor.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 9),
              for (final source in message.sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isUser ? Colors.white : colors.primary,
                      side: BorderSide(color: textColor.withValues(alpha: 0.35)),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    ),
                    onPressed: () => onCheckSource(source),
                    icon: const Icon(Icons.menu_book_outlined, size: 17),
                    label: JustifiedText(
                      '${source.marker.isEmpty ? '[R]' : source.marker}  چیک کریں  ·  ${source.citation}',
                      style: TextStyle(color: isUser ? Colors.white : colors.primary, fontSize: 13),
                      maxLines: 2,
                    ),
                  ),
                ),
            ],
            if (message.createdAt != null) ...[
              const SizedBox(height: 3),
              Text(_formatTime(message.createdAt!), textAlign: TextAlign.left, style: TextStyle(fontFamily: 'sans-serif', color: textColor.withValues(alpha: 0.55), fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rtl = directionFor(text) == TextDirection.rtl;
    final hasUrduLetters = RegExp(r'[پچژگٹڈڑںےھکیہۍ]').hasMatch(text);
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: SelectableText(
        text,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontFamily: rtl ? (hasUrduLetters ? kUrduFont : kArabicFont) : 'sans-serif',
          fontSize: 17,
          height: rtl && !hasUrduLetters ? 1.7 : 1.55,
          letterSpacing: 0,
          color: color,
        ),
      ),
    );
  }
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: kGold.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined, color: kForest, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: text,
              child: JustifiedText('مطالعے کا حوالہ گفتگو میں شامل ہے', maxLines: 1, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
            ),
          ),
          IconButton(visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: JustifiedText(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 13))),
              TextButton(onPressed: onRetry, child: const Text('دوبارہ')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 5,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.start,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(hintText: 'اپنا سوال لکھیں…', isDense: true),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              width: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder()),
                onPressed: sending ? null : onSend,
                child: sending ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 6, height: 6, child: CircularProgressIndicator(strokeWidth: 1.5)), SizedBox(width: 10), Text('حوالہ تلاش ہو رہے ہیں…')]),
        ),
      );
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}
