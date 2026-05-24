import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book_catalog.dart';
import '../models/calculator_definition.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../services/access_service.dart';
import '../config/freemium_config.dart';
import '../screens/reader_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/calculator_screen.dart';
import '../screens/unlock_screen.dart';
import '../screens/question_list_screen.dart';
import '../widgets/drawer/settings_drawer.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _bgIndex = 0;
  final Map<String, DateTime> _history = {};
  bool _historyLoaded = false;

  static const _backgrounds = [
    'assets/background/bg1.png',
    'assets/background/bg2.png',
    'assets/background/bg3.png',
    'assets/background/bg4.png',
    'assets/background/bg5.png',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    setState(() => _bgIndex = (_bgIndex + 1) % _backgrounds.length);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    if (!mounted) return;
    final storage = context.read<StorageService>();
    final map = storage.getBookHistory();
    setState(() {
      _history.addAll(map);
      _historyLoaded = true;
    });
  }

  Future<void> _recordOpen(String bookId) async {
    final storage = context.read<StorageService>();
    setState(() => _history[bookId] = DateTime.now());
    await storage.recordBookOpen(bookId);
  }

  List<CatalogBook> get _sortedBooks {
    final sorted = List<CatalogBook>.from(kBooks);
    sorted.sort((a, b) {
      final aTime = _history[a.id];
      final bTime = _history[b.id];
      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return 0;
    });
    return sorted;
  }

  bool _isRecent(String bookId) {
    final t = _history[bookId];
    return t != null && DateTime.now().difference(t).inDays < 7;
  }

  void _openBook(CatalogBook book) {
    if (!book.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${book.title} — content coming soon'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    _recordOpen(book.id);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderScreen(bookId: book.id, dataFile: book.dataFile),
    ));
  }

  void _showBookOptions(CatalogBook book) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text('Read ${book.title}'),
              onTap: () { Navigator.pop(context); _openBook(book); },
            ),
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text('${book.title} — Questions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => QuestionListScreen(bookId: book.id),
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    final settingsProvider = context.read<SettingsProvider>();
    final authProvider = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Settings',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SettingsPanel(
                  settings: settingsProvider.settings,
                  onUpdate: (s) {
                    settingsProvider.updateSettings(s);
                    setSheetState(() {});
                  },
                  onLogout: () async {
                    Navigator.pop(context);
                    await authProvider.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Faded background image
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: SizedBox.expand(
              key: ValueKey(_bgIndex),
              child: Image.asset(
                _backgrounds[_bgIndex],
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.18),
              ),
            ),
          ),
          // Theme surface overlay for readability
          Container(color: cs.surface.withValues(alpha: 0.82)),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
                  child: Row(
                    children: [
                      Image.asset('assets/icon/logo.png', width: 30, height: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Enchiridion',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_circle_outlined),
                        tooltip: 'Profile',
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen())),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Settings',
                        onPressed: _showSettings,
                      ),
                    ],
                  ),
                ),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.menu_book_outlined), text: 'Library'),
                    Tab(icon: Icon(Icons.medical_services_outlined), text: 'Tools'),
                  ],
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _LibraryTab(
                        books: _sortedBooks,
                        historyLoaded: _historyLoaded,
                        isRecent: _isRecent,
                        onTap: _openBook,
                        onLongPress: _showBookOptions,
                      ),
                      const _ToolsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Library tab ──────────────────────────────────────────────────────────────

class _LibraryTab extends StatefulWidget {
  final List<CatalogBook> books;
  final bool historyLoaded;
  final bool Function(String) isRecent;
  final void Function(CatalogBook) onTap;
  final void Function(CatalogBook) onLongPress;

  const _LibraryTab({
    required this.books,
    required this.historyLoaded,
    required this.isRecent,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) setState(() => _currentPage = page);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.historyLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final books = widget.books;

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: books.length,
          itemBuilder: (_, i) {
            final book = books[i];
            return _BookPage(
              book: book,
              isRecent: widget.isRecent(book.id),
              onTap: () => widget.onTap(book),
              onLongPress: () => widget.onLongPress(book),
            );
          },
        ),
        // Page indicator dots
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(books.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  width: 6,
                  height: active ? 18 : 6,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookPage extends StatelessWidget {
  final CatalogBook book;
  final bool isRecent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookPage({
    required this.book,
    required this.isRecent,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen cover image
          Image.asset(
            book.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: cs.primaryContainer,
              child: Icon(Icons.menu_book_rounded,
                size: 80, color: cs.onPrimaryContainer),
            ),
          ),
          // Gradient overlay so text is readable at the bottom
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.5, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
          // Coming-soon dim
          if (!book.hasContent)
            Container(color: Colors.black.withValues(alpha: 0.35)),
          // Bottom text
          Positioned(
            left: 20,
            right: 40,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRecent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Recent',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      )),
                  ),
                Text(book.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  )),
                const SizedBox(height: 6),
                Text(
                  book.hasContent ? book.specialty : 'Coming soon',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Tap-to-read hint icon
          if (book.hasContent)
            Positioned(
              right: 20,
              bottom: 28,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                ),
                child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 22),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Tools tab ────────────────────────────────────────────────────────────────

class _ToolsTab extends StatefulWidget {
  const _ToolsTab();

  @override
  State<_ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<_ToolsTab> {
  Set<String> _favorites = {};
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final access = await AccessService.instance.hasFullAccess();
    if (!mounted) return;
    final storage = context.read<StorageService>();
    setState(() {
      _favorites = storage.getFavorites();
      _hasAccess = access;
    });
  }

  bool _isLocked(CalculatorDefinition calc) {
    if (_hasAccess) return false;
    final categoryCalcs =
        kCalculators.where((c) => c.category == calc.category).toList();
    final index = categoryCalcs.indexWhere((c) => c.id == calc.id);
    return index >= kFreeCalculatorsPerCategory;
  }

  void _openCalc(CalculatorDefinition calc) {
    if (_isLocked(calc)) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => const UnlockScreen(),
      ));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CalculatorScreen(calculatorId: calc.id),
    ));
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Text(title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favCalcs =
        kCalculators.where((c) => _favorites.contains(c.id)).toList();
    final grouped = groupByCategory(kCalculators);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (favCalcs.isNotEmpty) ...[
          _sectionHeader('Favorites'),
          ...favCalcs.map((c) => _CalcTile(
            calc: c,
            isFavorite: true,
            isLocked: _isLocked(c),
            onTap: () => _openCalc(c),
          )),
          const Divider(height: 8),
        ],
        ...grouped.entries.expand((entry) => [
          _sectionHeader(entry.key),
          ...entry.value.map((c) => _CalcTile(
            calc: c,
            isFavorite: _favorites.contains(c.id),
            isLocked: _isLocked(c),
            onTap: () => _openCalc(c),
          )),
        ]),
      ],
    );
  }
}

class _CalcTile extends StatelessWidget {
  final CalculatorDefinition calc;
  final bool isFavorite;
  final bool isLocked;
  final VoidCallback onTap;

  const _CalcTile({
    required this.calc,
    required this.isFavorite,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.calculate_outlined,
          size: 20, color: cs.onPrimaryContainer),
      ),
      title: Text(calc.title,
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(calc.description,
        style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.55)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis),
      trailing: isLocked
          ? Icon(Icons.lock_outline, size: 18,
              color: cs.onSurface.withValues(alpha: 0.4))
          : isFavorite
              ? Icon(Icons.favorite, size: 18, color: cs.primary)
              : null,
      onTap: onTap,
    );
  }
}
