import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../providers/book_provider.dart';
import '../models/chapter.dart';
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
import '../utils/bottom_inset.dart';
import 'unlock_screen.dart';

class ReaderScreen extends StatelessWidget {
  final String bookId;
  final String dataFile;

  /// When set, the reader jumps to this chapter on open instead of the
  /// last-read one — used when navigating in from a margin note.
  final String? initialChapterId;

  /// When set (with [initialChapterId]), scrolls to this block once the
  /// target chapter has laid out — see `PinnedNotesScreen`.
  final String? initialAnchorId;

  /// For widget tests only. When non-null, ReaderScreen skips asset loading
  /// and uses this pre-built provider directly.
  @visibleForTesting
  final BookProvider? testBookProvider;

  const ReaderScreen({
    super.key,
    this.bookId = 'paediatrics',
    this.dataFile = 'assets/data/paediatrics.json',
    this.initialChapterId,
    this.initialAnchorId,
    this.testBookProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (testBookProvider != null) {
      return ChangeNotifierProvider<BookProvider>.value(
        value: testBookProvider!,
        child: _ReaderShell(
          bookId: bookId,
          initialChapterId: initialChapterId,
          initialAnchorId: initialAnchorId,
        ),
      );
    }
    final storageService = context.read<StorageService>();
    return ChangeNotifierProvider<BookProvider>(
      create: (_) => BookProvider(storageService, dataFile),
      child: _ReaderShell(
        bookId: bookId,
        initialChapterId: initialChapterId,
        initialAnchorId: initialAnchorId,
      ),
    );
  }
}

class _ReaderShell extends StatefulWidget {
  final String bookId;
  final String? initialChapterId;
  final String? initialAnchorId;
  const _ReaderShell({
    required this.bookId,
    this.initialChapterId,
    this.initialAnchorId,
  });

  @override
  State<_ReaderShell> createState() => _ReaderShellState();
}

class _ReaderShellState extends State<_ReaderShell> {
  bool _isMenuOpen = false;
  bool _isSettingsOpen = false;
  bool _hasAccess = false;
  final AutoScrollController _scrollController = AutoScrollController();
  int _drawerOpenCount = 0;

  // D-11: Active-section scroll tracking state
  String? _currentSectionId;
  Map<String, GlobalKey> _sectionKeys = {};
  Map<String, GlobalKey> _subsectionKeys = {};

  // Margin-note deep link: jump to a specific chapter/block on open.
  Map<String, GlobalKey> _anchorKeys = {};
  Map<String, int> _itemIndexes = {};
  bool _appliedInitialChapter = false;
  String? _pendingAnchorId;

  @override
  void initState() {
    super.initState();
    _pendingAnchorId = widget.initialAnchorId;
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

  // Lazy children have no stable offsets until built. Use the visible indexed
  // child instead, then map its index back to the enclosing section.
  void _updateActiveSection() {
    if (!_scrollController.hasClients || _itemIndexes.isEmpty) return;
    int? visibleIndex;
    double nearestBelow = double.infinity;
    for (final entry in _scrollController.tagMap.entries) {
      final renderObject = entry.value.context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (top <= 100 && bottom > 100) {
        visibleIndex = entry.key;
        break;
      }
      if (top > 100 && top < nearestBelow) {
        nearestBelow = top;
        visibleIndex = entry.key;
      }
    }
    if (visibleIndex == null) return;
    String? activeId;
    var activeIndex = -1;
    for (final section in context.read<BookProvider>().currentChapter?.sections ??
        const <ChapterSection>[]) {
      final index = _itemIndexes[section.id];
      if (index != null && index <= visibleIndex && index > activeIndex) {
        activeIndex = index;
        activeId = section.id;
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

  void _onItemIndexesReady(Map<String, int> indexes) {
    _itemIndexes = indexes;
  }

  // Margin notes: receives per-block keys once BlockRenderer builds them for
  // the current chapter, and scrolls to a pending target anchor if one is
  // waiting (set by opening the reader from a note in PinnedNotesScreen).
  void _onAnchorKeysReady(Map<String, GlobalKey> keys) {
    _anchorKeys = keys;
    final target = _pendingAnchorId;
    if (target == null || !_anchorKeys.containsKey(target)) return;
    _pendingAnchorId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _anchorKeys[target]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      } else if (mounted && _scrollController.hasClients) {
        final index = _itemIndexes[target];
        if (index != null) {
          _scrollController.scrollToIndex(index,
              preferPosition: AutoScrollPosition.begin);
        }
      }
    });
  }

  void _navigateToChapter(String chapterId) {
    context.read<BookProvider>().navigateToChapter(chapterId);
    setState(() {
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
    } else {
      final index = _itemIndexes[subsectionId] ?? _itemIndexes[sectionId];
      if (index != null && _scrollController.hasClients) {
        _scrollController.scrollToIndex(index,
            preferPosition: AutoScrollPosition.begin);
      }
    }
  }

  Future<void> _showNotesSheet(String chapterId) async {
    final saved = await showModalBottomSheet<bool>(
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
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chapter note saved'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
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

        if (!_appliedInitialChapter && widget.initialChapterId != null) {
          _appliedInitialChapter = true;
          final target = widget.initialChapterId!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) bookProvider.navigateToChapter(target);
          });
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
            final safeBottomInset = bottomViewportInset(context);
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
                          onNotesPressed: () => _showNotesSheet(chapterId),
                        ),
                        _hasAccess ||
                                  bookProvider.currentIndex < kFreeChapterCount
                              ? ReaderContent(
                                  chapter: chapter,
                                  bookId: widget.bookId,
                                  asSliver: true,
                                  autoScrollController: _scrollController,
                                  onItemIndexesReady: _onItemIndexesReady,
                                  onKeysReady: _onKeysReady,
                                  onAnchorKeysReady: _onAnchorKeysReady,
                                )
                              : SliverToBoxAdapter(child: _LockedChapterOverlay(
                                  bookId: widget.bookId,
                                  chapter: chapter,
                                )),
                        SliverToBoxAdapter(
                          child: SizedBox(height: 96 + safeBottomInset),
                        ),
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
                      bottom: safeBottomInset + 4,
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
                      bottom: safeBottomInset,
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
  bool _hasExistingNote = false;

  @override
  void initState() {
    super.initState();
    final existingNote =
        widget.storage.getNote(widget.bookId, widget.chapterId) ?? '';
    _ctrl.text = existingNote;
    _hasExistingNote = existingNote.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final text = _ctrl.text.trim();
    await widget.storage.saveNote(widget.bookId, widget.chapterId, text);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _startFresh() async {
    if (_saving) return;
    setState(() => _ctrl.clear());
  }

  Future<void> _clearSavedNote() async {
    if (_saving) return;
    await widget.storage.deleteNote(widget.bookId, widget.chapterId);
    if (mounted) {
      setState(() {
        _ctrl.clear();
        _hasExistingNote = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved chapter note removed'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottomInset = bottomViewportInset(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, __) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + safeBottomInset,
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
                    onPressed: _startFresh,
                    child: const Text('Start Fresh'),
                  ),
                  TextButton(
                    onPressed: _hasExistingNote ? _clearSavedNote : null,
                    child: const Text('Delete Saved'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _hasExistingNote
                    ? 'Your saved chapter note is loaded below. Edit it and save again, or start fresh.'
                    : 'Write a chapter note and save. The sheet will close once it is stored.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  scrollPadding: const EdgeInsets.only(bottom: 96),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Note'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
