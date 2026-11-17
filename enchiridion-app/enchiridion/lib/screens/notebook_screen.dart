import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/notebook_entry.dart';
import '../services/storage_service.dart';
import '../utils/bottom_inset.dart';

typedef NotebookImagePicker = Future<Uint8List?> Function(ImageSource source);

Document notebookDocument(String content) {
  if (content.isEmpty) return Document();
  try {
    return Document.fromJson(jsonDecode(content) as List<dynamic>);
  } catch (_) {
    return Document()..insert(0, content);
  }
}

Future<Uint8List?> _pickWithImagePicker(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 75,
  );
  return picked?.readAsBytes();
}

enum _EntryAction { edit, moveUp, moveDown, delete }

class NotebookScreen extends StatefulWidget {
  final NotebookImagePicker pickImage;

  const NotebookScreen({super.key, this.pickImage = _pickWithImagePicker});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  late final StorageService _storage = context.read<StorageService>();
  late List<NotebookEntry> _entries = _storage.getNotebookEntries();

  void _reload() => setState(() => _entries = _storage.getNotebookEntries());

  Future<void> _addText() async {
    final content = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const NotebookTextEditorScreen()),
    );
    if (content == null) return;
    await _storage.addNotebookText(content);
    _reload();
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final bytes = await widget.pickImage(source);
    if (bytes == null) return;
    await _storage.addNotebookImage(bytes);
    _reload();
  }

  Future<void> _edit(NotebookEntry entry) async {
    final content = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => NotebookTextEditorScreen(initialContent: entry.content),
      ),
    );
    if (content == null) return;
    await _storage.updateNotebookEntry(entry.id, content);
    _reload();
  }

  Future<void> _delete(NotebookEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.kind == NotebookEntryKind.image
            ? 'Delete this photo?'
            : 'Delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.deleteNotebookEntry(entry.id);
    _reload();
  }

  Future<void> _handle(_EntryAction action, NotebookEntry entry, int index) {
    switch (action) {
      case _EntryAction.edit:
        return _edit(entry);
      case _EntryAction.moveUp:
        return _storage
            .moveNotebookEntry(entry.id, index - 1)
            .then((_) => _reload());
      case _EntryAction.moveDown:
        return _storage
            .moveNotebookEntry(entry.id, index + 1)
            .then((_) => _reload());
      case _EntryAction.delete:
        return _delete(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your notes')),
      body: _entries.isEmpty
          ? const _EmptyNotebook()
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, bottomViewportInset(context, extra: 96)),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return _NotebookEntryCard(
                  key: ValueKey(entry.id),
                  entry: entry,
                  storage: _storage,
                  canMoveUp: index > 0,
                  canMoveDown: index < _entries.length - 1,
                  onAction: (action) => _handle(action, entry, index),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'notebook_add_photo',
            tooltip: 'Add a photo',
            onPressed: _addPhoto,
            child: const Icon(Icons.add_a_photo_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'notebook_add_text',
            onPressed: _addText,
            icon: const Icon(Icons.edit_note),
            label: const Text('Add note'),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotebook extends StatelessWidget {
  const _EmptyNotebook();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('Your notebook is empty', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add notes and photos in the order you want to revise them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotebookEntryCard extends StatefulWidget {
  final NotebookEntry entry;
  final StorageService storage;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<_EntryAction> onAction;

  const _NotebookEntryCard({
    super.key,
    required this.entry,
    required this.storage,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onAction,
  });

  @override
  State<_NotebookEntryCard> createState() => _NotebookEntryCardState();
}

class _NotebookEntryCardState extends State<_NotebookEntryCard> {
  QuillController? _controller;
  Future<Uint8List?>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _NotebookEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.updatedAt != widget.entry.updatedAt) {
      _controller?.dispose();
      _load();
    }
  }

  void _load() {
    if (widget.entry.kind == NotebookEntryKind.image) {
      _image = widget.storage.notebookImages.read(widget.entry.id);
      _controller = null;
    } else {
      _controller = QuillController(
        document: notebookDocument(widget.entry.content),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.entry.kind == NotebookEntryKind.image;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: isImage
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(16, 12, 40, 12),
            child: isImage
                ? FutureBuilder<Uint8List?>(
                    future: _image,
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return SizedBox(
                          height: 160,
                          child: Center(
                            child:
                                snapshot.connectionState == ConnectionState.done
                                    ? const Text('Photo not on this device yet')
                                    : const CircularProgressIndicator(),
                          ),
                        );
                      }
                      return Image.memory(bytes,
                          width: double.infinity, fit: BoxFit.fitWidth);
                    },
                  )
                : QuillEditor.basic(
                    controller: _controller!,
                    config: const QuillEditorConfig(
                      showCursor: false,
                      scrollable: false,
                      expands: false,
                    ),
                  ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: PopupMenuButton<_EntryAction>(
              tooltip: 'Note options',
              onSelected: widget.onAction,
              itemBuilder: (_) => [
                if (!isImage)
                  const PopupMenuItem(
                      value: _EntryAction.edit, child: Text('Edit')),
                if (widget.canMoveUp)
                  const PopupMenuItem(
                      value: _EntryAction.moveUp, child: Text('Move up')),
                if (widget.canMoveDown)
                  const PopupMenuItem(
                      value: _EntryAction.moveDown, child: Text('Move down')),
                const PopupMenuItem(
                    value: _EntryAction.delete, child: Text('Delete')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotebookTextEditorScreen extends StatefulWidget {
  final String initialContent;

  const NotebookTextEditorScreen({super.key, this.initialContent = ''});

  @override
  State<NotebookTextEditorScreen> createState() =>
      _NotebookTextEditorScreenState();
}

class _NotebookTextEditorScreenState extends State<NotebookTextEditorScreen> {
  static const _highlight = BackgroundAttribute('#FFF176');

  late final QuillController _controller = QuillController(
    document: notebookDocument(widget.initialContent),
    selection: const TextSelection.collapsed(offset: 0),
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isHighlighted =>
      _controller.getSelectionStyle().attributes[Attribute.background.key] !=
      null;

  void _toggleHighlight() {
    _controller.formatSelection(_isHighlighted
        ? Attribute.clone(Attribute.background, null)
        : _highlight);
  }

  void _save() {
    final hasText = _controller.document.toPlainText().trim().isNotEmpty;
    Navigator.of(context).pop(
        hasText ? jsonEncode(_controller.document.toDelta().toJson()) : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialContent.isEmpty ? 'New note' : 'Edit note'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Column(
        children: [
          Material(
            elevation: 1,
            child: Row(
              children: [
                QuillToolbarToggleStyleButton(
                    controller: _controller, attribute: Attribute.bold),
                QuillToolbarToggleStyleButton(
                    controller: _controller, attribute: Attribute.italic),
                IconButton(
                  tooltip: 'Highlight',
                  isSelected: _isHighlighted,
                  onPressed: _toggleHighlight,
                  icon: const Icon(Icons.format_color_fill),
                  selectedIcon: const Icon(Icons.format_color_fill,
                      color: Color(0xFFF9A825)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16,
                  bottomViewportInset(context, includeKeyboard: true)),
              child: QuillEditor.basic(
                controller: _controller,
                focusNode: _focusNode,
                config: const QuillEditorConfig(
                  autoFocus: true,
                  placeholder: 'Write your note',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
