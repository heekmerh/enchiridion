import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Append-only diagnostic log covering the Study Buddy path. Records
/// operation *boundaries*: a START/END pair with duration, an EVENT, or an
/// ERROR; a START with no matching END marks where things stopped. Unlike
/// `dart:developer`'s `log` (memory-only, invisible in release builds), each
/// call is a synchronous, immediately-flushed file append. Shared with the
/// native side (`DiagLog.kt`) via one file so a single timeline covers
/// native `FlutterEngine` construction/teardown as well as
/// Dart, across all three engines this app creates. Best-effort throughout:
/// a failing log write must never itself cause the freeze/crash it exists
/// to explain, and on platforms without `BubblePlugin` this is a no-op.
class DiagnosticsLog {
  DiagnosticsLog._();

  static const MethodChannel _channel = MethodChannel('enchiridion/bubbles');
  static const _fileName = 'study_buddy_diagnostics.log';
  static const _maxBytes = 2 * 1024 * 1024;

  static String? _path;
  static bool _unavailable = false;
  static String _engineTag = '?';

  // Lines recorded before the log directory is known. Without this, anything
  // logged during bootstrap was silently dropped — which is how a window
  // that froze before its first channel reply produced no log at all.
  static final List<String> _buffered = [];
  static const _maxBufferedLines = 200;

  /// Bootstraps the log with no platform channel and no `await`, using a
  /// directory the native side already handed us. The path the bubble
  /// window uses: [initFromRoute] pulls it from the launch route, so that
  /// engine can log its first instruction even if channels never respond.
  static void initWithDirectory(String directory, String engineTag) {
    _engineTag = engineTag;
    if (_path != null) return;
    _path = '$directory/$_fileName';
    _unavailable = false;
    _rotateIfNeeded();
    _flushBuffered();
  }

  /// Reads the log directory out of a launch route's `logdir` parameter (set
  /// by `BubblePlugin.bubbleActivityIntent` on the native side). No-ops
  /// harmlessly when the route carries no directory.
  static void initFromRoute(String routeName, String engineTag) {
    _engineTag = engineTag;
    try {
      final directory = Uri.tryParse(routeName)?.queryParameters['logdir'];
      if (directory == null || directory.isEmpty) return;
      initWithDirectory(directory, engineTag);
    } catch (_) {}
  }

  /// Resolves the log directory over the platform channel, for engines with
  /// no launch route to carry it. Must never be awaited on a critical path —
  /// a stalled channel would gate the work being instrumented — so anything
  /// logged while this is in flight is buffered and flushed when it lands.
  static Future<void> init(String engineTag) async {
    if (_path != null || _unavailable) return;
    _engineTag = engineTag;
    // Retried rather than latched on first failure: Dart starts running
    // before `configureFlutterEngine` registers plugins (~45ms), so an
    // early MissingPluginException is a timing artifact, not a verdict.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final dir = await _channel.invokeMethod<String>('diagLogDir');
        if (dir != null) {
          initWithDirectory(dir, engineTag);
          event('logger_init', {'attempt': attempt});
          return;
        }
      } catch (_) {
        // Plugin not registered yet, or not on Android at all.
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    // Give up quietly so later writes stay cheap. Buffered lines are kept,
    // not cleared — they cost nothing and are bounded.
    _unavailable = true;
  }

  /// A single point-in-time occurrence.
  static void event(String name, [Map<String, Object?>? data]) =>
      _write('EVENT', name, data);

  /// Marks the start of a potentially slow or blocking operation. Pair with
  /// [end] using the same [id] — if [end] (or [error]) never shows up in the
  /// log for a given id after a freeze, that operation is what hung.
  static void start(String id, [Map<String, Object?>? data]) =>
      _write('START', id, data);

  static void end(String id, [Map<String, Object?>? data]) =>
      _write('END', id, data);

  static void error(String id, Object error, [StackTrace? stack]) => _write(
        'ERROR',
        id,
        {
          'error': error.toString(),
          if (stack != null)
            'stack': stack.toString().replaceAll('\n', ' | '),
        },
      );

  /// Wraps [op] with automatic start/end/duration/failure logging under
  /// [id]. Prefer this over manual [start]/[end] pairs for a plain
  /// `await`-and-return call.
  static Future<T> track<T>(
    String id,
    Future<T> Function() op, [
    Map<String, Object?>? data,
  ]) async {
    final stopwatch = Stopwatch()..start();
    start(id, data);
    try {
      final result = await op();
      end(id, {'ms': stopwatch.elapsedMilliseconds});
      return result;
    } catch (e) {
      end(id, {'ms': stopwatch.elapsedMilliseconds, 'failed': true});
      rethrow;
    }
  }

  static void _write(String kind, String name, Map<String, Object?>? data) {
    final ts = DateTime.now().toIso8601String();
    final suffix = (data == null || data.isEmpty) ? '' : ' ${_encode(data)}';
    final line = '$ts [$_engineTag] $kind $name$suffix\n';

    final path = _path;
    if (path == null) {
      if (!_unavailable && _buffered.length < _maxBufferedLines) {
        _buffered.add(line);
      }
      return;
    }
    _append(path, line);
  }

  static void _flushBuffered() {
    final path = _path;
    if (path == null || _buffered.isEmpty) return;
    final pending = _buffered.join();
    _buffered.clear();
    _append(path, pending);
  }

  static void _append(String path, String text) {
    try {
      File(path).writeAsStringSync(text, mode: FileMode.append, flush: true);
    } catch (_) {
      // See class doc: logging must never cascade into the thing it watches.
    }
  }

  static String _encode(Map<String, Object?> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join(' ');

  static void _rotateIfNeeded() {
    final path = _path;
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > _maxBytes) {
        final rotated = File('$path.1');
        if (rotated.existsSync()) rotated.deleteSync();
        file.renameSync('$path.1');
      }
    } catch (_) {}
  }

  /// Full current log content (rotated predecessor first, if present), for
  /// display/export in-app. Works from any engine once [init] has run,
  /// since all three write to the same file.
  static Future<String> readAll() async {
    var path = _path;
    // The viewer runs in the main app engine, which may never itself have
    // needed to log anything yet — resolve the directory on demand.
    if (path == null && !_unavailable) {
      await init('main');
      path = _path;
    }
    if (path == null) return '';
    try {
      final buffer = StringBuffer();
      final rotated = File('$path.1');
      if (await rotated.exists()) buffer.write(await rotated.readAsString());
      final current = File(path);
      if (await current.exists()) buffer.write(await current.readAsString());
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  static Future<void> clear() async {
    final path = _path;
    if (path == null) return;
    try {
      final current = File(path);
      if (await current.exists()) await current.delete();
      final rotated = File('$path.1');
      if (await rotated.exists()) await rotated.delete();
    } catch (_) {}
  }
}
