import 'dart:typed_data';

import 'package:enchiridion/models/notebook_entry.dart';
import 'package:enchiridion/services/notebook_image_store.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NotebookEntry _entry(String id, String content, double position, DateTime at) =>
    NotebookEntry(
      id: id,
      kind: NotebookEntryKind.text,
      content: content,
      position: position,
      createdAt: at,
      updatedAt: at,
    );

void main() {
  late StorageService storage;
  late MemoryNotebookImageStore images;
  late List<UserDataEntity> pushed;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    images = MemoryNotebookImageStore();
    storage = StorageService(await SharedPreferences.getInstance(),
        notebookImages: images);
    pushed = [];
    storage.onUserDataChanged = pushed.add;
  });

  List<String> contents() =>
      storage.getNotebookEntries().map((e) => e.content).toList();

  test('entries keep the order they were added in', () async {
    await storage.addNotebookText('first');
    await storage.addNotebookText('second');
    await storage.addNotebookText('third');

    expect(contents(), ['first', 'second', 'third']);
    expect(pushed, everyElement(UserDataEntity.notebookEntries));
  });

  test('moving an entry places it between its new neighbours', () async {
    final a = await storage.addNotebookText('a');
    await storage.addNotebookText('b');
    final c = await storage.addNotebookText('c');

    await storage.moveNotebookEntry(c.id, 0);
    expect(contents(), ['c', 'a', 'b']);

    await storage.moveNotebookEntry(a.id, 2);
    expect(contents(), ['c', 'b', 'a']);

    await storage.moveNotebookEntry(a.id, 1);
    expect(contents(), ['c', 'a', 'b']);
  });

  test('editing changes content and bumps updatedAt', () async {
    final entry = await storage.addNotebookText('draft');
    await storage.updateNotebookEntry(entry.id, 'final');

    final updated = storage.getNotebookEntries().single;
    expect(updated.content, 'final');
    expect(
        updated.updatedAt.isAfter(entry.updatedAt) ||
            updated.updatedAt == entry.updatedAt,
        isTrue);
  });

  test('photos store their bytes and deleting removes them with a tombstone',
      () async {
    final entry = await storage.addNotebookImage(Uint8List.fromList([1, 2, 3]));

    expect(entry.kind, NotebookEntryKind.image);
    expect(await images.read(entry.id), [1, 2, 3]);

    await storage.deleteNotebookEntry(entry.id);

    expect(storage.getNotebookEntries(), isEmpty);
    expect(await images.read(entry.id), isNull);
    expect(
      storage.getDeletions().map((d) => (d.entity, d.id)),
      [(UserDataEntity.notebookEntries, entry.id)],
    );
  });

  test('remote entries merge last-write-wins without triggering a push',
      () async {
    final old = DateTime.utc(2026, 1, 1);
    final recent = DateTime.utc(2026, 1, 2);
    await storage.mergeNotebookEntries([_entry('n1', 'local', 1, recent)]);

    expect(await storage.mergeNotebookEntries([_entry('n1', 'stale', 1, old)]),
        isFalse);
    expect(
        await storage.mergeNotebookEntries([_entry('n2', 'remote', 0, recent)]),
        isTrue);

    expect(contents(), ['remote', 'local']);
    expect(pushed, isEmpty);
  });

  test('a remote tombstone removes the entry and its photo', () async {
    final entry = await storage.addNotebookImage(Uint8List.fromList([9]));
    final deletion = SyncDeletion(
      entity: UserDataEntity.notebookEntries,
      id: entry.id,
      deletedAt: DateTime.now().toUtc(),
    );

    expect(await storage.applyDeletions([deletion]), isTrue);
    expect(storage.getNotebookEntries(), isEmpty);
    expect(await images.read(entry.id), isNull);
  });

  test('uploaded photo ids are remembered', () async {
    await storage.markNotebookImageUploaded('p1');
    expect(storage.getUploadedNotebookImages(), {'p1'});
  });
}
