import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book_catalog.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../screens/reader_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/calculator_list_screen.dart';
import '../screens/exam_prep_home_screen.dart';
import '../screens/question_list_screen.dart';
import '../screens/resource_topic_list_screen.dart';
import '../screens/osce_screen.dart';
import '../screens/pinned_notes_screen.dart';
import '../models/resource_topic.dart';
import '../widgets/drawer/settings_drawer.dart';

// ─── Resource category data model ────────────────────────────────────────────

class _ResourceCategory {
  final String title;
  final String assetPath;
  final void Function(BuildContext) onTap;

  const _ResourceCategory({
    required this.title,
    required this.assetPath,
    required this.onTap,
  });
}

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

  List<CatalogBook> get _sortedBooks => booksInDisplayOrder(_history);

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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text('Read ${book.title}'),
              onTap: () {
                Navigator.pop(context);
                _openBook(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text('${book.title} — Questions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Settings',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
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
                      Image.asset('assets/icon/logo.png',
                          width: 30, height: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Enchiridion',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.push_pin_outlined),
                        tooltip: 'Pinned Notes',
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PinnedNotesScreen())),
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_circle_outlined),
                        tooltip: 'Profile',
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen())),
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
                    Tab(
                        icon: Icon(Icons.medical_services_outlined),
                        text: 'Resources'),
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
                      const _ResourcesTab(),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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

// ─── Resources tab ───────────────────────────────────────────────────────────

class _ResourcesTab extends StatefulWidget {
  const _ResourcesTab();

  @override
  State<_ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<_ResourcesTab> {
  late final PageController _pageController;
  int _currentPage = 0;

  late final List<_ResourceCategory> _categories;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) setState(() => _currentPage = page);
    });
    _categories = [
      _ResourceCategory(
        title: 'Calculators',
        assetPath: 'assets/resources/calculators.jpeg',
        onTap: (context) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const CalculatorListScreen(),
        )),
      ),
      _ResourceCategory(
        title: 'Exam Prep',
        assetPath: 'assets/resources/exam_prep.jpeg',
        onTap: (context) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ExamPrepHomeScreen(),
        )),
      ),
      _ResourceCategory(
        title: 'Surgical Instrumentation',
        assetPath: 'assets/resources/surgical instrumentation.jpeg',
        onTap: (context) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ResourceTopicListScreen(
            title: 'Surgical Instrumentation',
            topics: kSurgicalInstrumentationTopics,
          ),
        )),
      ),
      _ResourceCategory(
        title: 'Medical Instrumentation',
        assetPath: 'assets/resources/clinical instrumentation.jpeg',
        onTap: (context) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ResourceTopicListScreen(
            title: 'Medical Instrumentation',
            topics: kMedicalInstrumentationTopics,
          ),
        )),
      ),
      _ResourceCategory(
        title: 'OSCE',
        assetPath: 'assets/resources/osce.jpeg',
        onTap: (context) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const OsceScreen(),
        )),
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _categories.length,
          itemBuilder: (_, i) => _ResourceCard(
            category: _categories[i],
            onTap: () => _categories[i].onTap(context),
          ),
        ),
        // Page indicator dots — right side, vertical column
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_categories.length, (i) {
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

class _ResourceCard extends StatelessWidget {
  final _ResourceCategory category;
  final VoidCallback onTap;

  const _ResourceCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen cover image
          Image.asset(
            category.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: cs.primaryContainer,
              child: Icon(Icons.category_outlined,
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
          // Bottom label
          Positioned(
            left: 20,
            right: 40,
            bottom: 28,
            child: Text(
              category.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
