import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notebook_image_store.dart';

NotebookImageStore createNotebookImageStore(SharedPreferences prefs) =>
    _FileNotebookImageStore();

class _FileNotebookImageStore implements NotebookImageStore {
  Directory? _dir;

  Future<File> _file(String id) async {
    final dir = _dir ??= Directory(
        '${(await getApplicationDocumentsDirectory()).path}/notebook_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$id.jpg');
  }

  @override
  Future<Uint8List?> read(String id) async {
    final file = await _file(id);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    await (await _file(id)).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }
}
