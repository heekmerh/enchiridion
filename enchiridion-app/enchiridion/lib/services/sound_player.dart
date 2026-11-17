import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class SoundPlayer {
  SoundPlayer._();

  static final SoundPlayer instance = SoundPlayer._();

  final ValueNotifier<String?> playing = ValueNotifier<String?>(null);
  AudioPlayer? _player;

  Future<void> toggle(String assetPath) async {
    if (playing.value == assetPath) {
      await stop();
      return;
    }
    final player = _player ??= AudioPlayer();
    playing.value = assetPath;
    try {
      await player.stop();
      await player.setAsset(assetPath);
      await player.setLoopMode(LoopMode.one);
      if (playing.value != assetPath) return;
      await player.play();
    } catch (_) {
      if (playing.value == assetPath) playing.value = null;
    }
  }

  Future<void> stop() async {
    playing.value = null;
    await _player?.stop();
  }
}
