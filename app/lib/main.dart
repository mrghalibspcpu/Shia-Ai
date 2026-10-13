import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'ai_repository.dart';
import 'app_theme.dart';
import 'library_repository.dart';
import 'models.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShiaAiApp());
}

class ShiaAiApp extends StatefulWidget {
  const ShiaAiApp({super.key});

  @override
  State<ShiaAiApp> createState() => _ShiaAiAppState();
}

class _ShiaAiAppState extends State<ShiaAiApp> {
  final LibraryRepository _library = LibraryRepository();
  final AiRepository _ai = AiRepository();
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<HomeShellState> _homeShellKey = GlobalKey<HomeShellState>();
  StreamSubscription<Uri>? _linkSubscription;
  ReaderTarget? _pendingTarget;
  String? _lastHandledLink;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleIncomingLink, onError: (_) {});
    unawaited(_appLinks.getInitialLink().then(_handleIncomingLink, onError: (_) {}));
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel() ?? Future<void>.value());
    _ai.dispose();
    unawaited(_library.close());
    super.dispose();
  }

  void _handleIncomingLink(Uri? uri) {
    if (uri == null || uri.scheme != 'shiaai' || uri.host != 'reader') return;
    final now = DateTime.now();
    final link = uri.toString();
    if (_lastHandledLink == link && _lastHandledAt != null && now.difference(_lastHandledAt!).inSeconds < 3) return;
    _lastHandledLink = link;
    _lastHandledAt = now;
    final book = uri.queryParameters['book'];
    final recordId = int.tryParse(uri.queryParameters['record_id'] ?? '');
    if (BookDefinition.byKey(book) == null || recordId == null || recordId <= 0) return;
    final target = ReaderTarget(
      book: book!.toLowerCase(),
      recordId: recordId,
      sectionId: int.tryParse(uri.queryParameters['section_id'] ?? ''),
      page: int.tryParse(uri.queryParameters['page'] ?? ''),
    );
    if (_library.isInitialized) {
      _openReaderTarget(target);
    } else {
      _pendingTarget = target;
    }
  }

  void _openPendingReaderTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    if (target != null) _openReaderTarget(target);
  }

  void _openReaderTarget(ReaderTarget target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      final book = BookDefinition.byKey(target.book);
      if (!mounted || navigator == null || book == null) {
        _pendingTarget = target;
        return;
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => ReaderScreen(
          library: _library,
          book: book,
          recordId: target.recordId,
          sectionId: target.sectionId,
          onOpenAi: (book, passage) => _homeShellKey.currentState?.openAiWithContext(book, passage),
        ),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shia AI',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: LibraryBootstrap(
        library: _library,
        ai: _ai,
        onReady: _openPendingReaderTarget,
        homeShellKey: _homeShellKey,
      ),
    );
  }
}

class LibraryBootstrap extends StatefulWidget {
  const LibraryBootstrap({
    super.key,
    required this.library,
    required this.ai,
    required this.onReady,
    required this.homeShellKey,
  });

  final LibraryRepository library;
  final AiRepository ai;
  final VoidCallback onReady;
  final GlobalKey<HomeShellState> homeShellKey;

  @override
  State<LibraryBootstrap> createState() => _LibraryBootstrapState();
}

class _LibraryBootstrapState extends State<LibraryBootstrap> {
  double _progress = 0;
  String _status = 'کتب کی تیاری ہو رہی ہے';
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    setState(() => _error = null);
    try {
      await widget.library.initialize(onProgress: (progress, message) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          _status = message;
        });
      });
      if (mounted) widget.onReady();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.library.isInitialized) {
      return HomeShell(key: widget.homeShellKey, library: widget.library, ai: widget.ai);
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset('assets/images/tasneemlogo.png', width: 116, height: 116, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 22),
                  const Text('شیعہ اے آئی', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  JustifiedText(_error == null ? _status : 'کتب تیار کرتے ہوئے مسئلہ پیش آیا: $_error'),
                  const SizedBox(height: 18),
                  if (_error == null) ...[
                    LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                    const SizedBox(height: 10),
                    Text('${(_progress * 100).round()}%'),
                  ] else
                    FilledButton.icon(
                      onPressed: _starting ? null : _start,
                      icon: const Icon(Icons.refresh),
                      label: const Text('دوبارہ کوشش کریں'),
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.library, required this.ai});

  final LibraryRepository library;
  final AiRepository ai;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  final GlobalKey<AiChatScreenState> _aiChatKey = GlobalKey<AiChatScreenState>();
  late final List<Widget> _pages = [
    LibraryHomeScreen(library: widget.library, onOpenAi: openAiWithContext),
    SearchScreen(library: widget.library, onOpenAi: openAiWithContext),
    AiChatScreen(key: _aiChatKey, library: widget.library, ai: widget.ai),
  ];

  void openAiWithContext(BookDefinition book, Passage passage) {
    _aiChatKey.currentState?.setReaderContext(book, passage);
    if (mounted) setState(() => _selectedIndex = 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'کتب'),
          NavigationDestination(icon: Icon(Icons.search), label: 'تلاش'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'شیعہ اے آئی'),
        ],
      ),
    );
  }
}
