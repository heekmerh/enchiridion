import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/clip_note.dart';
import '../services/storage_service.dart';
import '../utils/bottom_inset.dart';

/// Free-standing notes, not tied to any book/chapter/section — reachable
/// from the Library screen rather than only from within a reading session
/// (see [StorageService.getPinnedNotes] and friends). Mirrors the add/edit/
/// delete UX already used for per-section clip notes
/// (`_ClipsBottomSheet` in block_renderer.dart), just as a full screen
/// instead of a bottom sheet since it isn't anchored to a reading position.
class PinnedNotesScreen extends StatefulWidget {
  const PinnedNotesScreen({super.key});

  @override
  State<PinnedNotesScreen> createState() => _PinnedNotesScreenState();
}

class _PinnedNotesScreenState extends State<PinnedNotesScreen> {
  late StorageService _storage;
  late List<ClipNote> _notes;
  final _addCtrl = TextEditingController();
  String? _editingNoteId;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = context.read<StorageService>();
    _notes = _storage.getPinnedNotes();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);

    if (_editingNoteId == null) {
      await _storage.addPinnedNote(text);
    } else {
      await _storage.updatePinnedNote(_editingNoteId!, text);
    }

    _addCtrl.clear();
    if (mounted) {
      setState(() {
        _saving = false;
        _editingNoteId = null;
        _notes = _storage.getPinnedNotes();
      });
    }
  }

  void _startEditing(ClipNote note) {
    setState(() {
      _editingNoteId = note.id;
      _addCtrl.text = note.content;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingNoteId = null;
      _addCtrl.clear();
    });
  }

  Future<void> _delete(String id) async {
    await _storage.deletePinnedNote(id);
    if (mounted) {
      setState(() {
        _notes.removeWhere((n) => n.id == id);
        if (_editingNoteId == id) {
          _editingNoteId = null;
          _addCtrl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEditing = _editingNoteId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Pinned Notes')),
      body: Padding(
        padding: EdgeInsets.only(
          bottom: bottomViewportInset(context, includeKeyboard: true),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Editing note',
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
                                ? 'Update this note…'
                                : 'Pin a quick note…',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          minLines: 2,
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _submit,
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
            const Divider(height: 1),
            Expanded(
              child: _notes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No pinned notes yet. Anything you pin here stays '
                          'handy no matter what you\'re reading.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _notes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return ListTile(
                          title: Text(note.content,
                              style: theme.textTheme.bodyMedium),
                          subtitle: Text(
                            'Pinned ${note.createdAt.toLocal()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18),
                                onPressed: () => _startEditing(note),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18),
                                color: cs.error,
                                onPressed: () => _delete(note.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
