import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/storage_service.dart';
import '../../utils/bottom_inset.dart';

Future<void> showChapterNotesSheet(
  BuildContext context, {
  required String bookId,
  required String chapterId,
  String noun = 'chapter',
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChapterNotesSheet(
      bookId: bookId,
      chapterId: chapterId,
      noun: noun,
      storage: context.read<StorageService>(),
    ),
  );
  if (!context.mounted || saved != true) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${_capitalize(noun)} note saved'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class ChapterNotesSheet extends StatefulWidget {
  final String bookId;
  final String chapterId;
  final String noun;
  final StorageService storage;

  const ChapterNotesSheet({
    super.key,
    required this.bookId,
    required this.chapterId,
    required this.storage,
    this.noun = 'chapter',
  });

  @override
  State<ChapterNotesSheet> createState() => _ChapterNotesSheetState();
}

class _ChapterNotesSheetState extends State<ChapterNotesSheet> {
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
        SnackBar(
          content: Text('Saved ${widget.noun} note removed'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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
    final noun = widget.noun;

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
                    '${_capitalize(noun)} Notes',
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
                    ? 'Your saved $noun note is loaded below. Edit it and save again, or start fresh.'
                    : 'Write a $noun note and save. The sheet will close once it is stored.',
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
                    hintText: 'Write your notes for this $noun…',
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
