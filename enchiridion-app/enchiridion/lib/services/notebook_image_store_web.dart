import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'notebook_image_store.dart';

NotebookImageStore createNotebookImageStore(SharedPreferences prefs) =>
    _PrefsNotebookImageStore(prefs);

class _PrefsNotebookImageStore implements NotebookImageStore {
  final SharedPreferences _prefs;

  _PrefsNotebookImageStore(this._prefs);

  String _key(String id) => 'notebook_image_$id';

  @override
  Future<Uint8List?> read(String id) async {
    final raw = _prefs.getString(_key(id));
    return raw == null ? null : base64Decode(raw);
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    await _prefs.setString(_key(id), base64Encode(bytes));
  }

  @override
  Future<void> delete(String id) async {
    await _prefs.remove(_key(id));
  }
}
