import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book_catalog.dart';
import '../models/pinned_note.dart';
import '../models/resource_topic.dart';
import '../providers/pinned_notes_provider.dart';
import '../utils/bottom_inset.dart';
import 'reader_screen.dart';

/// Notes stay linked to their source book while collections can span books.
class PinnedNotesScreen extends StatefulWidget {
  final String bookId;
  const PinnedNotesScreen({super.key, this.bookId = 'paediatrics'});

  @override
  State<PinnedNotesScreen> createState() => _PinnedNotesScreenState();
}

class _PinnedNotesScreenState extends State<PinnedNotesScreen> {
  static const _unfiled = '__unfiled__';
  static const _newCollection = '__new_collection__';
  String? _editingId;
  final _editCtrl = TextEditingController();

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  CatalogBook? _book(String id) {
    for (final book in kBooks) {
      if (book.id == id) return book;
    }
    return null;
  }

  String _bookTitle(String id) {
    final book = _book(id);
    if (book != null) return book.title;
    return topicTitleForNotesScope(id);
  }

  void _goToNote(PinnedNote note) {
    final book = _book(note.bookId);
    if (book == null || !book.hasContent) {
      if (note.bookId.startsWith('topic_')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Open ${topicTitleForNotesScope(note.bookId)} to see this note in context.'),
        ));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('${_bookTitle(note.bookId)} content is not available yet.'),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(
        bookId: note.bookId,
        dataFile: book.dataFile,
        initialChapterId: note.chapterId,
        initialAnchorId: note.anchorId,
      ),
    ));
  }

  void _startEditing(PinnedNote note) {
    setState(() {
      _editingId = note.id;
      _editCtrl.text = note.content;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingId = null;
      _editCtrl.clear();
    });
  }

  Future<void> _saveEdit(PinnedNotesProvider notes) async {
    final id = _editingId;
    final content = _editCtrl.text.trim();
    if (id == null || content.isEmpty) return;
    await notes.update(id, content);
    if (mounted) _cancelEditing();
  }

  Future<String?> _askName({String? current}) async {
    var value = current ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current == null ? 'New collection' : 'Rename collection'),
        content: TextFormField(
          initialValue: current,
          onChanged: (text) => value = text,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Collection name',
            hintText: 'e.g. Paediatrics exam',
          ),
          onFieldSubmitted: (text) {
            if (text.trim().isNotEmpty) {
              Navigator.pop(dialogContext, text.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
            },
            child: Text(current == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
    return name;
  }

  Future<NoteCollection?> _createCollection(PinnedNotesProvider notes) async {
    final name = await _askName();
    if (name == null || !mounted) return null;
    return notes.createCollection(name);
  }

  Future<void> _chooseCollection(
      PinnedNote note, PinnedNotesProvider notes) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const ListTile(title: Text('Study collection')),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Unfiled'),
              trailing:
                  note.collectionId == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetContext, _unfiled),
            ),
            for (final collection in notes.collections)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(collection.name),
                trailing: note.collectionId == collection.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, collection.id),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Create new collection'),
              onTap: () => Navigator.pop(sheetContext, _newCollection),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _newCollection) {
      final collection = await _createCollection(notes);
      if (collection != null) {
        await notes.assignToCollection(note.id, collection.id);
      }
    } else {
      await notes.assignToCollection(
          note.id, choice == _unfiled ? null : choice);
    }
  }

  Future<void> _collectionAction(String action, NoteCollection collection,
      PinnedNotesProvider notes) async {
    if (action == 'rename') {
      final name = await _askName(current: collection.name);
      if (name == null || !mounted) return;
      try {
        await notes.renameCollection(collection.id, name);
      } on ArgumentError {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A collection with that name already exists.'),
          ));
        }
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Delete ${collection.name}?'),
          content: const Text(
            'The collection will be removed. Its notes will remain under their books.',
          ),
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
      if (confirmed == true) await notes.deleteCollection(collection.id);
    }
  }

  Widget _noteTile(PinnedNote note, PinnedNotesProvider notes) {
    if (_editingId == note.id) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _editCtrl,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: _cancelEditing, child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => _saveEdit(notes),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final collectionName = notes.collections
        .where((collection) => collection.id == note.collectionId)
        .map((collection) => collection.name)
        .firstOrNull;
    final subtitle = [
      _bookTitle(note.bookId),
      note.chapterId.replaceAll('-', ' '),
      if (collectionName != null) collectionName,
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 20, right: 8),
      title: Text(note.content, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => _goToNote(note),
      trailing: PopupMenuButton<String>(
        tooltip: 'Note actions',
        onSelected: (action) {
          switch (action) {
            case 'open':
              _goToNote(note);
            case 'edit':
              _startEditing(note);
            case 'collection':
              _chooseCollection(note, notes);
            case 'delete':
              notes.delete(note.id);
              if (_editingId == note.id) _cancelEditing();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'open', child: Text('Jump to note')),
          PopupMenuItem(value: 'edit', child: Text('Edit note')),
          PopupMenuItem(value: 'collection', child: Text('Study collection')),
          PopupMenuItem(value: 'delete', child: Text('Delete note')),
        ],
      ),
    );
  }

  Widget _booksView(PinnedNotesProvider notes) {
    if (notes.all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No pinned notes yet. Long-press a passage in a book or topic to pin a note to that spot.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final byBook = <String, List<PinnedNote>>{};
    for (final note in notes.all) {
      byBook.putIfAbsent(note.bookId, () => []).add(note);
    }
    final bookIds = byBook.keys.toList()
      ..sort((a, b) => _bookTitle(a).compareTo(_bookTitle(b)));
    return ListView(
      padding: EdgeInsets.only(bottom: bottomViewportInset(context) + 16),
      children: [
        for (final id in bookIds)
          ExpansionTile(
            key: PageStorageKey('book-$id'),
            initiallyExpanded: true,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(_bookTitle(id)),
            subtitle: Text('${byBook[id]!.length} notes'),
            children: [for (final note in byBook[id]!) _noteTile(note, notes)],
          ),
      ],
    );
  }

  Widget _collectionsView(PinnedNotesProvider notes) {
    final unfiled = notes.forCollection(null);
    return ListView(
      padding: EdgeInsets.only(bottom: bottomViewportInset(context) + 16),
      children: [
        if (notes.collections.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Create a collection for an exam or study goal, then add notes from any book.',
              textAlign: TextAlign.center,
            ),
          ),
        if (unfiled.isNotEmpty)
          ExpansionTile(
            key: const PageStorageKey('collection-unfiled'),
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('Unfiled'),
            subtitle: Text('${unfiled.length} notes'),
            children: [for (final note in unfiled) _noteTile(note, notes)],
          ),
        for (final collection in notes.collections)
          ExpansionTile(
            key: PageStorageKey('collection-${collection.id}'),
            leading: const Icon(Icons.folder_outlined),
            title: Text(collection.name),
            subtitle:
                Text('${notes.forCollection(collection.id).length} notes'),
            trailing: PopupMenuButton<String>(
              tooltip: 'Collection actions',
              onSelected: (action) =>
                  _collectionAction(action, collection, notes),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(
                    value: 'delete', child: Text('Delete collection')),
              ],
            ),
            children: [
              for (final note in notes.forCollection(collection.id))
                _noteTile(note, notes),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<PinnedNotesProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pinned Notes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: 'New collection',
              onPressed: () => _createCollection(notes),
            ),
          ],
          bottom: const TabBar(
              tabs: [Tab(text: 'Books'), Tab(text: 'Collections')]),
        ),
        body:
            TabBarView(children: [_booksView(notes), _collectionsView(notes)]),
      ),
    );
  }
}
