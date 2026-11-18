import 'package:flutter/material.dart';

import '../../models/content_block.dart';
import '../../services/sound_player.dart';

class AudioBlockWidget extends StatelessWidget {
  final AudioBlock block;
  final double fontSize;
  final SoundPlayer player;

  AudioBlockWidget({
    super.key,
    required this.block,
    required this.fontSize,
    SoundPlayer? player,
  }) : player = player ?? SoundPlayer.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final multi = block.tracks.length > 1;
    return Container(
      margin: EdgeInsets.only(bottom: fontSize),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.graphic_eq, size: fontSize * 1.1, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (!multi && block.tracks.isNotEmpty)
                  _PlayStopButton(
                      player: player,
                      track: block.tracks.first,
                      label: block.title),
              ],
            ),
          ),
          if (multi)
            for (var i = 0; i < block.tracks.length; i++)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Track ${i + 1}',
                        style: TextStyle(
                            fontSize: fontSize * 0.9,
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                    _PlayStopButton(
                      player: player,
                      track: block.tracks[i],
                      label: '${block.title}, track ${i + 1}',
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _PlayStopButton extends StatelessWidget {
  final SoundPlayer player;
  final String track;
  final String label;

  const _PlayStopButton(
      {required this.player, required this.track, required this.label});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: player.playing,
      builder: (context, playing, _) {
        final active = playing == track;
        return IconButton(
          tooltip: active ? 'Stop $label' : 'Play $label',
          icon: Icon(active ? Icons.stop_circle : Icons.play_circle),
          color: Theme.of(context).colorScheme.primary,
          iconSize: 32,
          onPressed: () => player.toggle(track),
        );
      },
    );
  }
}
