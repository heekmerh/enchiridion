import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chapter.dart';
import '../../models/content_block.dart';
import '../../models/user_settings.dart';
import '../../providers/settings_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import 'algorithm_block.dart';
import 'checklist_block.dart';
import 'clinical_pearls_block.dart';
import 'key_value_block.dart';
import 'mnemonic_block.dart';
import 'red_flags_block.dart';
import 'table_block.dart';

class BlockRenderer extends StatelessWidget {
  final Chapter chapter;
  final String bookId;

  const BlockRenderer({super.key, required this.chapter, this.bookId = ''});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final double fontSize = 16.0 * (settings.fontSize / 100.0);
    final double lineHeight = settings.lineHeight;
    final String fontFamily = switch (settings.fontFamily) {
      FontFamily.serif => 'serif',
      FontFamily.mono  => 'monospace',
      FontFamily.sans  => 'sans-serif',
    };

    return DefaultTextStyle.merge(
      style: TextStyle(fontFamily: fontFamily),
      child: _ChapterView(
        chapter: chapter,
        bookId: bookId,
        fontSize: fontSize,
        lineHeight: lineHeight,
      ),
    );
  }
}

class _ChapterView extends StatelessWidget {
  final Chapter chapter;
  final String bookId;
  final double fontSize;
  final double lineHeight;

  const _ChapterView({
    required this.chapter,
    required this.bookId,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];

    for (final section in chapter.sections) {
      children.add(_SectionHeader(
        title: section.title,
        fontSize: fontSize,
        bookId: bookId,
        chapterId: chapter.id,
        sectionId: section.id,
      ));

      for (final subsection in section.subsections) {
        children.add(_SubsectionHeader(
          title: subsection.title,
          icon: subsection.icon,
          fontSize: fontSize,
          theme: theme,
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

          for (final block in group.blocks) {
            children.add(_buildBlock(block, fontSize, lineHeight));
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildBlock(ContentBlock block, double fontSize, double lineHeight) {
    if (block is ParagraphBlock) {
      return _ParagraphWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is MnemonicBlock) {
      return MnemonicBlockWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is TableBlock) {
      return TableBlockWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is ChecklistBlock) {
      return ChecklistBlockWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is ClinicalPearlsBlock) {
      return ClinicalPearlsBlockWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is RedFlagsBlock) {
      return RedFlagsBlockWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is AlgorithmBlock) {
      return AlgorithmBlockWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is KeyValueBlock) {
      return KeyValueBlockWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
    } else if (block is AgeReferenceBlock) {
      return _AgeReferenceWidget(block: block, fontSize: fontSize, lineHeight: lineHeight);
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

  const _SectionHeader({
    required this.title,
    required this.fontSize,
    this.bookId = '',
    this.chapterId = '',
    this.sectionId = '',
  });

  void _showClips(BuildContext context) {
    final storage = context.read<StorageService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ClipsBottomSheet(
        bookId: bookId,
        chapterId: chapterId,
        sectionId: sectionId,
        sectionTitle: title,
        storage: storage,
      ),
    );
  }

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
                  color: AppColors.brandPink,
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
                    color: theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
              ),
              if (bookId.isNotEmpty)
                _ClipPinButton(
                  bookId: bookId,
                  chapterId: chapterId,
                  sectionId: sectionId,
                  onTap: () => _showClips(context),
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
  final VoidCallback onTap;

  const _ClipPinButton({
    required this.bookId,
    required this.chapterId,
    required this.sectionId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final clips = storage.getClips(bookId, chapterId, sectionId);
    final hasClips = clips.isNotEmpty;
    final color = hasClips
        ? AppColors.brandPink
        : Theme.of(context).colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
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

  const _SubsectionHeader({
    required this.title,
    this.icon,
    required this.fontSize,
    required this.theme,
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
                color: AppColors.brandPink,
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
              padding: EdgeInsets.only(
                  top: 3, left: fontSize * 0.6 + 2),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth - 48;
    final colCount = block.rows.isNotEmpty
        ? 1 + block.rows.first.keys.where((k) => k != 'age').length
        : 1;
    final colWidth = contentWidth / colCount;

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  block.ageUnit,
                  style: TextStyle(
                    fontSize: fontSize * 0.85,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              ...block.rows.isNotEmpty
                  ? (block.rows.first.keys.where((k) => k != 'age').map((k) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(
                          k,
                          style: TextStyle(
                            fontSize: fontSize * 0.85,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      )))
                  : [],
            ],
          ),
          ...block.rows.map((row) => TableRow(
                children: row.values.map((v) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        v.toString(),
                        style: TextStyle(
                          fontSize: fontSize * 0.9,
                          height: lineHeight,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    )).toList(),
              )),
        ],
      ),
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
  late List<Map<String, dynamic>> _clips;
  final _addCtrl = TextEditingController();

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

  Future<void> _addClip() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    await widget.storage
        .addClip(widget.bookId, widget.chapterId, widget.sectionId, text);
    _addCtrl.clear();
    if (mounted) {
      setState(() => _clips = widget.storage
          .getClips(widget.bookId, widget.chapterId, widget.sectionId));
    }
  }

  Future<void> _deleteClip(String clipId) async {
    await widget.storage
        .deleteClip(widget.bookId, widget.chapterId, widget.sectionId, clipId);
    if (mounted) {
      setState(() => _clips.removeWhere((c) => c['id'] == clipId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Add a clip note…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addClip,
                    child: const Text('Save'),
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
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final clip = _clips[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                clip['content'] as String? ?? '',
                                style: theme.textTheme.bodyMedium,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18),
                                color: cs.error,
                                onPressed: () =>
                                    _deleteClip(clip['id'].toString()),
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
