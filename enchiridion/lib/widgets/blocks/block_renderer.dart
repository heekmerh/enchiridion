import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../../models/chapter.dart';
import '../../models/clip_note.dart';
import '../../models/content_block.dart';
import '../../models/pinned_note.dart';
import '../../models/user_settings.dart';
import '../../providers/pinned_notes_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/bottom_inset.dart';
import 'algorithm_block.dart';
import 'checklist_block.dart';
import 'clinical_pearls_block.dart';
import 'key_value_block.dart';
import 'mnemonic_block.dart';
import 'red_flags_block.dart';
import 'table_block.dart';

/// Stable-enough id for a single content block within its chapter, used to
/// anchor margin notes to it. Positional at the block level (blocks have no
/// id of their own) but keyed off the surrounding section/subsection/group
/// ids so it survives unrelated edits elsewhere in the chapter.
String blockAnchorId(
  String sectionId,
  String subsectionId,
  String groupId,
  int blockIndex,
) =>
    '$sectionId/$subsectionId/$groupId/$blockIndex';

class BlockRenderer extends StatefulWidget {
  final Chapter chapter;
  final String bookId;
  final bool asSliver;
  final AutoScrollController? autoScrollController;
  final void Function(Map<String, int> itemIndexes)? onItemIndexesReady;
  final void Function(
    Map<String, GlobalKey> sectionKeys,
    Map<String, GlobalKey> subsectionKeys,
  )? onKeysReady;
  final void Function(Map<String, double> offsets)? onOffsetsReady;
  final void Function(Map<String, GlobalKey> anchorKeys)? onAnchorKeysReady;

  const BlockRenderer({
    super.key,
    required this.chapter,
    this.bookId = '',
    this.asSliver = false,
    this.autoScrollController,
    this.onItemIndexesReady,
    this.onKeysReady,
    this.onOffsetsReady,
    this.onAnchorKeysReady,
  });

  @override
  State<BlockRenderer> createState() => _BlockRendererState();
}

class _BlockRendererState extends State<BlockRenderer> {
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _subsectionKeys = {};
  final Map<String, GlobalKey> _anchorKeys = {};
  final Map<String, int> _itemIndexes = {};

  @override
  void initState() {
    super.initState();
    _buildKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());
  }

  @override
  void didUpdateWidget(BlockRenderer old) {
    super.didUpdateWidget(old);
    if (old.chapter.id != widget.chapter.id) {
      _buildKeys();
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());
    }
  }

  void _buildKeys() {
    _sectionKeys.clear();
    _subsectionKeys.clear();
    _anchorKeys.clear();
    _itemIndexes.clear();
    var index = 0;
    for (final section in widget.chapter.sections) {
      _sectionKeys[section.id] = GlobalKey();
      _itemIndexes[section.id] = index++;
      for (final subsection in section.subsections) {
        _subsectionKeys[subsection.id] = GlobalKey();
        _itemIndexes[subsection.id] = index++;
        for (final group in subsection.contentGroups) {
          if (group.title.isNotEmpty) index++;
          for (var i = 0; i < group.blocks.length; i++) {
            final anchorId =
                blockAnchorId(section.id, subsection.id, group.id, i);
            _anchorKeys[anchorId] = GlobalKey();
            _itemIndexes[anchorId] = index++;
          }
        }
      }
    }
    widget.onKeysReady?.call(_sectionKeys, _subsectionKeys);
    widget.onAnchorKeysReady?.call(_anchorKeys);
    widget.onItemIndexesReady?.call(_itemIndexes);
  }

  void _calculateOffsets() {
    // Use the enclosing Scrollable as the reference frame so that positions are
    // relative to the scroll viewport origin rather than the screen origin.
    // This makes stored offsets stable regardless of the current scroll position.
    final scrollable = Scrollable.maybeOf(context);
    final scrollRenderObject = scrollable?.context.findRenderObject();

    final offsets = <String, double>{};
    for (final entry in _sectionKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final localPos = box.localToGlobal(
            Offset.zero,
            ancestor: scrollRenderObject,
          );
          offsets[entry.key] = localPos.dy;
        }
      }
    }
    for (final entry in _subsectionKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final localPos = box.localToGlobal(
            Offset.zero,
            ancestor: scrollRenderObject,
          );
          offsets[entry.key] = localPos.dy;
        }
      }
    }
    widget.onOffsetsReady?.call(offsets);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final double fontSize = 16.0 * (settings.fontSize / 100.0);
    final double lineHeight = settings.lineHeight;
    final String fontFamily = switch (settings.fontFamily) {
      FontFamily.serif => 'serif',
      FontFamily.mono => 'monospace',
      FontFamily.sans => 'sans-serif',
    };

    return DefaultTextStyle.merge(
      style: TextStyle(fontFamily: fontFamily),
      child: _ChapterView(
        chapter: widget.chapter,
        bookId: widget.bookId,
        fontSize: fontSize,
        lineHeight: lineHeight,
        sectionKeys: _sectionKeys,
        subsectionKeys: _subsectionKeys,
        anchorKeys: _anchorKeys,
        asSliver: widget.asSliver,
        autoScrollController: widget.autoScrollController,
      ),
    );
  }
}

class _ChapterView extends StatelessWidget {
  final Chapter chapter;
  final String bookId;
  final double fontSize;
  final double lineHeight;
  final Map<String, GlobalKey> sectionKeys;
  final Map<String, GlobalKey> subsectionKeys;
  final Map<String, GlobalKey> anchorKeys;
  final bool asSliver;
  final AutoScrollController? autoScrollController;

  const _ChapterView({
    required this.chapter,
    required this.bookId,
    required this.fontSize,
    required this.lineHeight,
    required this.sectionKeys,
    required this.subsectionKeys,
    required this.anchorKeys,
    required this.asSliver,
    this.autoScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinnedNotes = context.watch<PinnedNotesProvider>();
    final children = <Widget>[];

    for (final section in chapter.sections) {
      final sectionTint = _headingTint(
        section.sectionColor ?? chapter.chapterColor,
        theme.brightness,
      );
      children.add(_SectionHeader(
        key: sectionKeys[section.id],
        title: section.title,
        fontSize: fontSize,
        bookId: bookId,
        chapterId: chapter.id,
        sectionId: section.id,
        tintColor: sectionTint,
      ));

      for (final subsection in section.subsections) {
        children.add(_SubsectionHeader(
          key: subsectionKeys[subsection.id],
          title: subsection.title,
          icon: subsection.icon,
          fontSize: fontSize,
          theme: theme,
          tintColor: _headingTint(
            subsection.subsectionColor ?? section.sectionColor ?? chapter.chapterColor,
            theme.brightness,
          ),
        ));

        for (final group in subsection.contentGroups) {
          if (group.title.isNotEmpty) {
            children.add(_GroupHeader(
              title: group.title,
              subtitle: group.subtitle,
              icon: group.icon,
              fontSize: fontSize,
              theme: theme,
            ));
          }

          for (var i = 0; i < group.blocks.length; i++) {
            final anchorId =
                blockAnchorId(section.id, subsection.id, group.id, i);
            children.add(_NotableBlock(
              key: anchorKeys[anchorId],
              bookId: bookId,
              chapterId: chapter.id,
              anchorId: anchorId,
              notes: pinnedNotes.forAnchor(bookId, chapter.id, anchorId),
              child: _buildBlock(
                  group.blocks[i], fontSize, lineHeight, theme.brightness),
            ));
          }
        }
      }
    }

    if (asSliver) {
      final controller = autoScrollController;
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => controller == null
              ? children[index]
              : AutoScrollTag(
                  key: ValueKey('${chapter.id}/$index'),
                  controller: controller,
                  index: index,
                  child: children[index],
                ),
          childCount: children.length,
          addAutomaticKeepAlives: false,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Color? _headingTint(String? colorStr, Brightness brightness) {
    if (colorStr == null || !RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(colorStr)) {
      return null;
    }
    final color = Color(0xFF000000 | int.parse(colorStr.replaceFirst('#', ''), radix: 16));
    final hsl = HSLColor.fromColor(color);
    final lightness = brightness == Brightness.dark
        ? hsl.lightness.clamp(0.65, 0.85)
        : hsl.lightness.clamp(0.20, 0.42);
    return hsl.withLightness(lightness.toDouble()).toColor();
  }

  Widget _buildBlock(ContentBlock block, double fontSize, double lineHeight,
      Brightness brightness) {
    if (block is ParagraphBlock) {
      return _ParagraphWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is MnemonicBlock) {
      return MnemonicBlockWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is TableBlock) {
      return TableBlockWidget(
          block: block,
          fontSize: fontSize,
          lineHeight: lineHeight,
          headerTintColor: _headingTint(chapter.chapterColor, brightness));
    } else if (block is ChecklistBlock) {
      return ChecklistBlockWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is ClinicalPearlsBlock) {
      return ClinicalPearlsBlockWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is RedFlagsBlock) {
      return RedFlagsBlockWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is AlgorithmBlock) {
      return AlgorithmBlockWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is KeyValueBlock) {
      return KeyValueBlockWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is ImageBlock) {
      return _ImageBlockWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is AgeReferenceBlock) {
      return _AgeReferenceWidget(
          block: block, fontSize: fontSize, lineHeight: lineHeight);
    }
    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final double fontSize;
  final String bookId;
  final String chapterId;
  final String sectionId;
  final Color? tintColor;

  const _SectionHeader({
    super.key,
    required this.title,
    required this.fontSize,
    this.bookId = '',
    this.chapterId = '',
    this.sectionId = '',
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: fontSize * 2.0, bottom: fontSize * 0.75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: theme.dividerColor, height: 1),
          SizedBox(height: fontSize * 0.75),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: fontSize * 1.8,
                decoration: BoxDecoration(
                  color: tintColor ?? AppColors.brandPink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: fontSize * 0.6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize * 1.6,
                    fontWeight: FontWeight.bold,
                    color: tintColor ?? theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
              ),
              if (bookId.isNotEmpty)
                _ClipPinButton(
                  bookId: bookId,
                  chapterId: chapterId,
                  sectionId: sectionId,
                  sectionTitle: title,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClipPinButton extends StatelessWidget {
  final String bookId;
  final String chapterId;
  final String sectionId;
  final String sectionTitle;

  const _ClipPinButton({
    required this.bookId,
    required this.chapterId,
    required this.sectionId,
    required this.sectionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return _ClipPinButtonBody(
      bookId: bookId,
      chapterId: chapterId,
      sectionId: sectionId,
      sectionTitle: sectionTitle,
    );
  }
}

class _ClipPinButtonBody extends StatefulWidget {
  final String bookId;
  final String chapterId;
  final String sectionId;
  final String sectionTitle;

  const _ClipPinButtonBody({
    required this.bookId,
    required this.chapterId,
    required this.sectionId,
    required this.sectionTitle,
  });

  @override
  State<_ClipPinButtonBody> createState() => _ClipPinButtonBodyState();
}

class _ClipPinButtonBodyState extends State<_ClipPinButtonBody> {
  Future<void> _openSheet() async {
    final storage = context.read<StorageService>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ClipsBottomSheet(
        bookId: widget.bookId,
        chapterId: widget.chapterId,
        sectionId: widget.sectionId,
        sectionTitle: widget.sectionTitle,
        storage: storage,
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final clips = storage.getClips(
      widget.bookId,
      widget.chapterId,
      widget.sectionId,
    );
    final hasClips = clips.isNotEmpty;
    final color =
        hasClips ? AppColors.brandPink : Theme.of(context).colorScheme.outline;

    return GestureDetector(
      onTap: _openSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              hasClips ? Icons.push_pin : Icons.push_pin_outlined,
              size: 18,
              color: color,
            ),
            if (hasClips)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.brandPink,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${clips.length}',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubsectionHeader extends StatelessWidget {
  final String title;
  final String? icon;
  final double fontSize;
  final ThemeData theme;
  final Color? tintColor;

  const _SubsectionHeader({
    super.key,
    required this.title,
    this.icon,
    required this.fontSize,
    required this.theme,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: fontSize * 1.25, bottom: fontSize * 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null && icon!.isNotEmpty) ...[
            Text(icon!, style: TextStyle(fontSize: fontSize * 1.2)),
            SizedBox(width: fontSize * 0.4),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: fontSize * 1.35,
                fontWeight: FontWeight.bold,
                color: tintColor ?? AppColors.brandPink,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? icon;
  final double fontSize;
  final ThemeData theme;

  const _GroupHeader({
    required this.title,
    this.subtitle,
    this.icon,
    required this.fontSize,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: fontSize * 0.75, bottom: fontSize * 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.brandPink.withValues(alpha: 0.06),
              border: const Border(
                left: BorderSide(color: AppColors.neonTeal, width: 2),
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: fontSize * 0.6,
              vertical: fontSize * 0.3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null && icon!.isNotEmpty) ...[
                  Text(icon!, style: TextStyle(fontSize: fontSize * 1.1)),
                  SizedBox(width: fontSize * 0.35),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: fontSize * 1.1,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 3, left: fontSize * 0.6 + 2),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: fontSize * 0.85,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Margin notes ───────────────────────────────────────────────────────────
//
// Long-press any block to pin a note to it. The marker docks to whichever
// edge of the screen the press landed in, and stays there — a small flag
// that a note exists at this exact spot, the way you'd scribble in a
// margin. Tapping the marker opens a balloon with the note(s) at that spot.

class _NotableBlock extends StatelessWidget {
  final String bookId;
  final String chapterId;
  final String anchorId;
  final List<PinnedNote> notes;
  final Widget child;

  const _NotableBlock({
    super.key,
    required this.bookId,
    required this.chapterId,
    required this.anchorId,
    required this.notes,
    required this.child,
  });

  Future<void> _handleLongPress(
    BuildContext context,
    LongPressStartDetails details,
  ) async {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final side =
        details.globalPosition.dx < screenWidth / 2 ? NoteSide.left : NoteSide.right;

    // A single entry today ("Pin note") — more actions (highlight, share…)
    // can be appended to this list as the app grows.
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: const [
        PopupMenuItem(value: 'pin', child: Text('Pin note')),
      ],
    );
    if (selected != 'pin' || !context.mounted) return;

    final text = await _promptForNoteText(context);
    if (text == null || text.trim().isEmpty || !context.mounted) return;

    await context.read<PinnedNotesProvider>().add(
          bookId: bookId,
          chapterId: chapterId,
          anchorId: anchorId,
          side: side,
          content: text.trim(),
        );
  }

  Future<String?> _promptForNoteText(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pin a note here'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Write your note…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            child: const Text('Pin'),
          ),
        ],
      ),
    );
  }

  void _openBalloon(BuildContext context, Offset anchor) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => _NoteBalloon(
        anchor: anchor,
        bookId: bookId,
        chapterId: chapterId,
        anchorId: anchorId,
      ),
    );
  }

  Widget _marker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: GestureDetector(
        onTapDown: (details) => _openBalloon(context, details.globalPosition),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: Icon(
            Icons.chat_bubble,
            size: 15,
            color: AppColors.brandPink,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A note marker sized via Positioned overflow paints fine but is never
    // hit-testable outside the Stack's own bounds (a Flutter constraint, not
    // a layout choice) — so it gets a real Row slot at the block's edge
    // instead, docked to the side the note was placed on.
    Widget content = child;
    if (notes.isNotEmpty) {
      final marker = _marker(context);
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: notes.first.side == NoteSide.left
            ? [marker, const SizedBox(width: 2), Expanded(child: child)]
            : [Expanded(child: child), const SizedBox(width: 2), marker],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => _handleLongPress(context, details),
      child: content,
    );
  }
}

class _NoteBalloon extends StatefulWidget {
  final Offset anchor;
  final String bookId;
  final String chapterId;
  final String anchorId;

  const _NoteBalloon({
    required this.anchor,
    required this.bookId,
    required this.chapterId,
    required this.anchorId,
  });

  @override
  State<_NoteBalloon> createState() => _NoteBalloonState();
}

class _NoteBalloonState extends State<_NoteBalloon> {
  String? _editingId;
  final _editCtrl = TextEditingController();

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  void _startEditing(PinnedNote note) {
    setState(() {
      _editingId = note.id;
      _editCtrl.text = note.content;
    });
  }

  Future<void> _saveEdit() async {
    final id = _editingId;
    if (id == null) return;
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    await context.read<PinnedNotesProvider>().update(id, text);
    if (mounted) setState(() => _editingId = null);
  }

  Future<void> _delete(String id) async {
    await context.read<PinnedNotesProvider>().delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final notes = context
        .watch<PinnedNotesProvider>()
        .forAnchor(widget.bookId, widget.chapterId, widget.anchorId);

    if (notes.isEmpty) {
      // The note this balloon was showing was just deleted — close it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    const balloonWidth = 240.0;
    // Open toward the centre of the screen, away from the edge the marker
    // is docked to, so the balloon has room and stays on-screen.
    final openRight = widget.anchor.dx < size.width / 2;
    var left = openRight
        ? widget.anchor.dx + 10
        : widget.anchor.dx - balloonWidth - 10;
    left = left.clamp(8.0, size.width - balloonWidth - 8);
    final top = (widget.anchor.dy - 12).clamp(8.0, size.height - 220);

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: balloonWidth,
            child: GestureDetector(
              onTap: () {}, // absorb taps so the balloon itself doesn't close
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: cs.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final note in notes) ...[
                            if (_editingId == note.id)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _editCtrl,
                                    autofocus: true,
                                    minLines: 2,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => _editingId = null),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: _saveEdit,
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      note.content,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 15),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _startEditing(note),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 15, color: cs.error),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _delete(note.id),
                                  ),
                                ],
                              ),
                            if (note != notes.last) const Divider(height: 14),
                          ],
                        ],
                      ),
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

class _ParagraphWidget extends StatelessWidget {
  final ParagraphBlock block;
  final double fontSize;
  final double lineHeight;

  const _ParagraphWidget({
    required this.block,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: fontSize),
      child: Text(
        block.text,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ImageBlockWidget extends StatelessWidget {
  final ImageBlock block;
  final double fontSize;
  final double lineHeight;

  const _ImageBlockWidget({
    required this.block,
    required this.fontSize,
    required this.lineHeight,
  });

  void _showImageViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.asset(
                  block.assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: fontSize * 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showImageViewer(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: theme.colorScheme.surfaceContainerHigh,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 180),
                  child: Image.asset(
                    block.assetPath,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image unavailable',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (block.caption != null && block.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                block.caption!,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: lineHeight,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AgeReferenceWidget extends StatelessWidget {
  final AgeReferenceBlock block;
  final double fontSize;
  final double lineHeight;

  const _AgeReferenceWidget({
    required this.block,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Derive column count from the union of all row keys so that an empty
    // rows list (colCount would be 1) never mismatches rows that have more
    // keys, which would cause a Flutter Table assertion error.
    final allKeys = block.rows.expand((r) => r.keys).toSet();
    final nonAgeKeys = allKeys.where((k) => k != 'age').toList();
    // +1 for the 'age' column itself.
    final colCount = nonAgeKeys.isEmpty ? 1 : 1 + nonAgeKeys.length;

    // Derive header column labels from first row (or empty if no rows).
    final headerKeys = block.rows.isNotEmpty
        ? block.rows.first.keys.where((k) => k != 'age').toList()
        : <String>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = constraints.maxWidth / colCount;

        return Container(
          margin: EdgeInsets.only(bottom: fontSize * 1.5),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            columnWidths: {
              for (int i = 0; i < colCount; i++) i: FixedColumnWidth(colWidth)
            },
            border: TableBorder(
              horizontalInside: BorderSide(color: theme.dividerColor),
              verticalInside: BorderSide(color: theme.dividerColor),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.inkCharcoal
                      : AppColors.brandPink.withValues(alpha: 0.08),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Text(
                      block.ageUnit,
                      style: TextStyle(
                        fontSize: fontSize * 0.85,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  ...headerKeys.map((k) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Text(
                          k,
                          style: TextStyle(
                            fontSize: fontSize * 0.85,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      )),
                ],
              ),
              ...block.rows.map((row) => TableRow(
                    children: row.values
                        .map((v) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              child: Text(
                                v.toString(),
                                style: TextStyle(
                                  fontSize: fontSize * 0.9,
                                  height: lineHeight,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ))
                        .toList(),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ─── Clips bottom sheet ───────────────────────────────────────────────────────

class _ClipsBottomSheet extends StatefulWidget {
  final String bookId;
  final String chapterId;
  final String sectionId;
  final String sectionTitle;
  final StorageService storage;

  const _ClipsBottomSheet({
    required this.bookId,
    required this.chapterId,
    required this.sectionId,
    required this.sectionTitle,
    required this.storage,
  });

  @override
  State<_ClipsBottomSheet> createState() => _ClipsBottomSheetState();
}

class _ClipsBottomSheetState extends State<_ClipsBottomSheet> {
  late List<ClipNote> _clips;
  final _addCtrl = TextEditingController();
  String? _editingClipId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clips = widget.storage
        .getClips(widget.bookId, widget.chapterId, widget.sectionId);
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitClip() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    if (_editingClipId == null) {
      await widget.storage
          .addClip(widget.bookId, widget.chapterId, widget.sectionId, text);
    } else {
      await widget.storage.updateClip(
        widget.bookId,
        widget.chapterId,
        widget.sectionId,
        _editingClipId!,
        text,
      );
    }
    _addCtrl.clear();
    if (mounted) {
      setState(() {
        _saving = false;
        _editingClipId = null;
        _clips = widget.storage
            .getClips(widget.bookId, widget.chapterId, widget.sectionId);
      });
    }
  }

  void _startEditing(ClipNote clip) {
    setState(() {
      _editingClipId = clip.id;
      _addCtrl.text = clip.content;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingClipId = null;
      _addCtrl.clear();
    });
  }

  Future<void> _deleteClip(String clipId) async {
    await widget.storage
        .deleteClip(widget.bookId, widget.chapterId, widget.sectionId, clipId);
    if (mounted) {
      setState(() {
        _clips.removeWhere((c) => c.id == clipId);
        if (_editingClipId == clipId) {
          _editingClipId = null;
          _addCtrl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEditing = _editingClipId != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomViewportInset(
          context,
          includeKeyboard: true,
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.sectionTitle,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Editing clip note',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _cancelEditing,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addCtrl,
                          decoration: InputDecoration(
                            hintText: isEditing
                                ? 'Update this clip note…'
                                : 'Add a clip note…',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          minLines: 2,
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _submitClip,
                        child: Text(
                          _saving
                              ? 'Saving…'
                              : isEditing
                                  ? 'Update'
                                  : 'Save',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _clips.isEmpty
                  ? Center(
                      child: Text('No clips yet for this section.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5))),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: _clips.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final clip = _clips[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            clip.content,
                            style: theme.textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            'Saved ${clip.createdAt.toLocal()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _startEditing(clip),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                color: cs.error,
                                onPressed: () => _deleteClip(clip.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
