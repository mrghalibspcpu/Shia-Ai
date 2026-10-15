import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'data_installer.dart';
import 'library_repository.dart';
import 'models.dart';
import 'reader_navigation.dart';
import 'screens/data_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'services/prayer_controller.dart';
import 'services/prayer_scope.dart';
import 'services/tasbeeh_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShiaLibraryApp());
}

class ShiaLibraryApp extends StatefulWidget {
  const ShiaLibraryApp({super.key});

  @override
  State<ShiaLibraryApp> createState() => _ShiaLibraryAppState();
}

class _ShiaLibraryAppState extends State<ShiaLibraryApp> {
  final LibraryRepository _library = LibraryRepository();
  late final DataInstaller _installer =
      DataInstaller(directory: () => _library.dataDirectoryHandle);
  // The prayer/tasbeeh state lives above the navigator for the whole session:
  // the timings screen, the home banner and the Qibla compass all read the
  // same coordinates and preferences, and the tasbeeh keeps counting while the
  // reader moves between screens.
  final PrayerController _prayer = PrayerController();
  final TasbeehController _tasbeeh = TasbeehController();
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<HomeShellState> _homeShellKey = GlobalKey<HomeShellState>();
  StreamSubscription<Uri>? _linkSubscription;
  ReaderTarget? _pendingTarget;
  String? _lastHandledLink;
  DateTime? _lastHandledAt;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTheme());
    // Both start from what is already on the phone, so the home screen paints
    // correct times and a correct count on the very first frame.
    unawaited(_prayer.start());
    unawaited(_tasbeeh.load());
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleIncomingLink, onError: (_) {});
    unawaited(_appLinks.getInitialLink().then(_handleIncomingLink, onError: (_) {}));
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    if (!mounted) return;
    setState(() {
      _themeMode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel() ?? Future<void>.value());
    unawaited(_installer.close());
    unawaited(_library.close());
    _prayer.dispose();
    _tasbeeh.dispose();
    super.dispose();
  }

  void _handleIncomingLink(Uri? uri) {
    if (uri == null || uri.scheme != 'shiaai' || uri.host != 'reader') return;
    final now = DateTime.now();
    final link = uri.toString();
    if (_lastHandledLink == link &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!).inSeconds < 3) {
      return;
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = _navigatorKey.currentState;
      final book = BookDefinition.byKey(target.book);
      if (!mounted || navigator == null || book == null || !_library.isInstalled(book)) {
        _pendingTarget = target;
        return;
      }
      await pushReaderFor(
        navigator.context,
        library: _library,
        book: book,
        recordId: target.recordId,
        sectionId: target.sectionId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShiaVerse',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
      builder: (context, child) => PrayerScope(
        controller: _prayer,
        child: TasbeehScope(
          controller: _tasbeeh,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      home: LibraryBootstrap(
        library: _library,
        installer: _installer,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
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
    required this.installer,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onReady,
    required this.homeShellKey,
  });

  final LibraryRepository library;
  final DataInstaller installer;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
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
      // Only the quick part happens here: unpack what is already on the phone
      // and open the books. The slow full-text index runs in the background so
      // the library opens straight away — even on a fresh install that has not
      // downloaded anything yet.
      await widget.library.initialize(
        onProgress: (progress, message) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _status = message;
          });
        },
        buildSearchIndex: false,
      );
      if (mounted) widget.onReady();
      unawaited(widget.library.ensureSearchIndex());
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
      // The home screen always wins, with or without data on disk: a missing
      // book is a download button on the library, never a blocked app.
      return HomeShell(
        key: widget.homeShellKey,
        library: widget.library,
        installer: widget.installer,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      );
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
                    child: Image.asset(
                      'assets/images/shiaverse_icon.png',
                      width: 116,
                      height: 116,
                      fit: BoxFit.cover,
                      // The asset is 512x512; decoding it at 240 px costs a
                      // fraction of a megabyte and paints without a stall.
                      cacheWidth: 240,
                      cacheHeight: 240,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('ShiaVerse', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
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
  const HomeShell({
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
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  late final Widget _libraryPage =
      LibraryHomeScreen(library: widget.library, onOpenData: openData);
  late final Widget _searchPage =
      SearchScreen(library: widget.library, onOpenData: openData);
  late final Widget _savedPage = SavedItemsScreen(library: widget.library);

  void openData() {
    if (!mounted) return;
    unawaited(Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DataScreen(library: widget.library, installer: widget.installer),
        ))
        .then((_) {
      if (mounted) setState(() {});
    }));
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the tabs when a download finishes so every page sees the new
    // book immediately instead of after a manual refresh.
    return ValueListenableBuilder<int>(
      valueListenable: widget.library.catalogVersion,
      builder: (context, _, __) => _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _libraryPage,
          _searchPage,
          _savedPage,
          SettingsScreen(
            library: widget.library,
            installer: widget.installer,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'کتب',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'تلاش'),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'محفوظات',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'ترتیبات',
          ),
        ],
      ),
    );
  }
}
