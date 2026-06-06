import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmark_provider.dart';
import '../services/storage_service.dart';
import '../services/access_service.dart';
import '../widgets/drawer/custom_drawer.dart';
import '../widgets/drawer/toc_drawer.dart';
import '../widgets/drawer/settings_drawer.dart';
import '../widgets/reader/reader_app_bar.dart';
import '../widgets/reader/reader_content.dart';
import '../widgets/reader/reader_navigation.dart';
import '../widgets/reader/reader_progress_bar.dart';
import '../constants/app_strings.dart';
import '../config/freemium_config.dart';
import 'unlock_screen.dart';

class ReaderScreen extends StatelessWidget {
  final String bookId;
  final String dataFile;

  /// For widget tests only. When non-null, ReaderScreen skips asset loading
  /// and uses this pre-built provider directly.
  @visibleForTesting
  final BookProvider? testBookProvider;

  const ReaderScreen({
    super.key,
    this.bookId = 'paediatrics',
    this.dataFile = 'assets/data/book.json',
    this.testBookProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (testBookProvider != null) {
      return ChangeNotifierProvider<BookProvider>.value(
        value: testBookProvider!,
        child: _ReaderShell(bookId: bookId),
      );
    }
    final storageService = context.read<StorageService>();
    return ChangeNotifierProvider<BookProvider>(
      create: (_) => BookProvider(storageService, dataFile),
      child: _ReaderShell(bookId: bookId),
    );
  }
}

class _ReaderShell extends StatefulWidget {
  final String bookId;
  const _ReaderShell({required this.bookId});

  @override
  State<_ReaderShell> createState() => _ReaderShellState();
}

class _ReaderShellState extends State<_ReaderShell> {
  bool _isMenuOpen = false;
  bool _isSettingsOpen = false;
  bool _hasAccess = false;
  final ScrollController _scrollController = ScrollController();
  int _drawerOpenCount = 0;

  // D-11: Active-section scroll tracking state
  String? _currentSectionId;
  Map<String, GlobalKey> _sectionKeys = {};
  Map<String, GlobalKey> _subsectionKeys = {};
  Map<String, double> _sectionOffsets = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final access = await AccessService.instance.hasBookAccess(widget.bookId);
    if (mounted) setState(() => _hasAccess = access);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // D-05: No auto-hide timer. D-11: Only does active-section tracking.
  void _onScroll() {
    _updateActiveSection();
  }

  // D-11: Determine the section currently in view by comparing scroll offset
  // against known anchor offsets. The section whose offset is closest to but
  // not past the current scroll position (with a 100 px lookahead) is active.
  void _updateActiveSection() {
    if (_sectionOffsets.isEmpty) return;
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    String? activeId;
    double bestOffset = double.negativeInfinity;
    for (final entry in _sectionOffsets.entries) {
      if (entry.value <= scrollOffset + 100 && entry.value > bestOffset) {
        bestOffset = entry.value;
        activeId = entry.key;
      }
    }
    if (activeId != _currentSectionId) {
      setState(() => _currentSectionId = activeId);
    }
  }

  // D-11: Receives the GlobalKey maps built by BlockRenderer after layout.
  void _onKeysReady(
    Map<String, GlobalKey> sectionKeys,
    Map<String, GlobalKey> subsectionKeys,
  ) {
    _sectionKeys = sectionKeys;
    _subsectionKeys = subsectionKeys;
  }

  // D-11: Receives the offset map after BlockRenderer measures anchor positions.
  void _onOffsetsReady(Map<String, double> offsets) {
    setState(() => _sectionOffsets = offsets);
  }

  void _navigateToChapter(String chapterId) {
    context.read<BookProvider>().navigateToChapter(chapterId);
    setState(() {
      _sectionOffsets = {};
      _currentSectionId = null;
      // Drawer stays open — user can pick a section or tap the content to close
    });
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _navigateToSection(String sectionId, String subsectionId) {
    // Close drawer only when a subsection (leaf) is tapped.
    // Section-level taps (subsectionId == '') keep the drawer open so the user
    // can drill down further or tap the content area to dismiss.
    if (subsectionId.isNotEmpty) {
      setState(() => _isMenuOpen = false);
    }
    final key = _subsectionKeys[subsectionId] ?? _sectionKeys[sectionId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    }
  }

  void _showNotesSheet(String chapterId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NotesBottomSheet(
        bookId: widget.bookId,
        chapterId: chapterId,
        storage: context.read<StorageService>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookProvider>(
      builder: (context, bookProvider, _) {
        if (bookProvider.status == BookStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (bookProvider.status == BookStatus.error) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading book:',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(bookProvider.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: bookProvider.retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final chapter = bookProvider.currentChapter;
        final chapterId = bookProvider.currentChapterId;

        if (chapter == null || chapterId == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Consumer2<SettingsProvider, BookmarkProvider>(
          builder: (context, settingsProvider, bookmarkProvider, _) {
            return Scaffold(
              body: GestureDetector(
                onTap: () {
                  if (_isMenuOpen) setState(() => _isMenuOpen = false);
                },
                child: Stack(
                  children: [
                    CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        ReaderAppBar(
                          title: chapter.title,
                          currentChapterId: chapterId,
                          onSettingsPressed: () => setState(() {
                            _isSettingsOpen = !_isSettingsOpen;
                          }),
                          onNotesPressed: () =>
                              _showNotesSheet(chapterId),
                        ),
                        SliverToBoxAdapter(
                          child: _hasAccess ||
                                  bookProvider.currentIndex < kFreeChapterCount
                              ? ReaderContent(
                                  chapter: chapter,
                                  bookId: widget.bookId,
                                  onKeysReady: _onKeysReady,
                                  onOffsetsReady: _onOffsetsReady,
                                )
                              : _LockedChapterOverlay(
                                  bookId: widget.bookId,
                                  chapter: chapter,
                                ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),

                    // Back + TOC pill pinned to top-left — permanently visible (D-05).
                    Positioned(
                      top: 0,
                      left: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, top: 6),
                          child: Material(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                            elevation: 2,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  tooltip: 'Back',
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 10,
                                  endIndent: 10,
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.5),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.menu),
                                  tooltip: 'Table of contents',
                                  onPressed: () => setState(() {
                                    _isMenuOpen = !_isMenuOpen;
                                    if (_isMenuOpen) _drawerOpenCount += 1;
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    CustomDrawer(
                      isOpen: _isMenuOpen,
                      onClose: () => setState(() => _isMenuOpen = false),
                      title: AppStrings.indexTitle,
                      position: DrawerPosition.left,
                      headerLeading: Image.asset(
                        'assets/icon/logo.png',
                        width: 28,
                        height: 28,
                      ),
                      child: TocDrawerContent(
                        key: ValueKey(_drawerOpenCount),
                        chapters: bookProvider.chapters,
                        currentChapterId: chapterId,
                        bookmarks: bookmarkProvider.bookmarks,
                        visitedChapterIds: bookProvider.visitedChapterIds,
                        onChapterSelected: _navigateToChapter,
                        onSearchResults: (_) {},
                        currentSectionId: _currentSectionId,
                        onSectionSelected: _navigateToSection,
                      ),
                    ),

                    CustomDrawer(
                      isOpen: _isSettingsOpen,
                      onClose: () => setState(() => _isSettingsOpen = false),
                      title: AppStrings.settingsTitle,
                      position: DrawerPosition.right,
                      child: SettingsPanel(
                        settings: settingsProvider.settings,
                        onUpdate: settingsProvider.updateSettings,
                      ),
                    ),

                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: ReaderNavigation(
                          hasPrevious: bookProvider.hasPrevious,
                          hasNext: bookProvider.hasNext,
                          onPreviousPressed: () {
                            bookProvider.goToPrevious();
                            _scrollController.animateTo(0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          },
                          onNextPressed: () {
                            bookProvider.goToNext();
                            _scrollController.animateTo(0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          },
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ReaderProgressBar(progress: bookProvider.progress),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Notes bottom sheet (US-006) ─────────────────────────────────────────────

class _NotesBottomSheet extends StatefulWidget {
  final String bookId;
  final String chapterId;
  final StorageService storage;

  const _NotesBottomSheet({
    required this.bookId,
    required this.chapterId,
    required this.storage,
  });

  @override
  State<_NotesBottomSheet> createState() => _NotesBottomSheetState();
}

class _NotesBottomSheetState extends State<_NotesBottomSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text =
        widget.storage.getNote(widget.bookId, widget.chapterId) ?? '';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.storage
        .saveNote(widget.bookId, widget.chapterId, _ctrl.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _clear() async {
    await widget.storage.deleteNote(widget.bookId, widget.chapterId);
    if (mounted) setState(() => _ctrl.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, __) => Padding(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.edit_note_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Chapter Notes',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clear,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                        controller: _ctrl,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Write your notes for this chapter…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Note'),
              ),
            ],
          ),
        ),
    );
  }
}

// ─── Freemium gate overlay ────────────────────────────────────────────────────

class _LockedChapterOverlay extends StatelessWidget {
  final String bookId;
  final dynamic chapter;

  const _LockedChapterOverlay({required this.bookId, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screenHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ColorFilter.mode(
                  cs.surface.withValues(alpha: 0.85),
                  BlendMode.srcOver,
                ),
                child: IgnorePointer(
                  // Use a plain surface-coloured container instead of a full
                  // ReaderContent so that BlockRenderer is never instantiated here.
                  // A second BlockRenderer for the same chapter would register
                  // duplicate GlobalKeys and crash the app at runtime.
                  child: Container(color: theme.colorScheme.surface),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 40, color: cs.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Unlock full access to continue reading',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The free preview covers the first chapter. '
                        'Unlock this book to read everything.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UnlockScreen(bookId: bookId),
                          ),
                        ),
                        child: const Text('Unlock'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }
}
