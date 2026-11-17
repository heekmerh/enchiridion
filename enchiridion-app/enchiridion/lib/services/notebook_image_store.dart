import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'notebook_image_store_io.dart'
    if (dart.library.js_interop) 'notebook_image_store_web.dart' as platform;

abstract class NotebookImageStore {
  Future<Uint8List?> read(String id);
  Future<void> write(String id, Uint8List bytes);
  Future<void> delete(String id);

  factory NotebookImageStore.platform(SharedPreferences prefs) =>
      platform.createNotebookImageStore(prefs);
}

class MemoryNotebookImageStore implements NotebookImageStore {
  final Map<String, Uint8List> images = {};

  @override
  Future<Uint8List?> read(String id) async => images[id];

  @override
  Future<void> write(String id, Uint8List bytes) async => images[id] = bytes;

  @override
  Future<void> delete(String id) async => images.remove(id);
}
