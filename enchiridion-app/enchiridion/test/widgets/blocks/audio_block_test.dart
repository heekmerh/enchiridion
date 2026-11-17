import 'package:enchiridion/models/content_block.dart';
import 'package:enchiridion/services/sound_player.dart';
import 'package:enchiridion/widgets/blocks/audio_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSoundPlayer implements SoundPlayer {
  @override
  final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  @override
  Future<void> toggle(String assetPath) async {
    playing.value = playing.value == assetPath ? null : assetPath;
  }

  @override
  Future<void> stop() async => playing.value = null;
}

Widget _host(AudioBlock block, SoundPlayer player) => MaterialApp(
      home: Scaffold(
        body: AudioBlockWidget(block: block, fontSize: 16, player: player),
      ),
    );

void main() {
  testWidgets('a single-track sound toggles between play and stop',
      (tester) async {
    final player = _FakeSoundPlayer();
    await tester.pumpWidget(_host(
      AudioBlock(title: 'Aortic stenosis', tracks: ['as.mp3']),
      player,
    ));

    expect(find.text('Aortic stenosis'), findsOneWidget);
    await tester.tap(find.byTooltip('Play Aortic stenosis'));
    await tester.pump();

    expect(player.playing.value, 'as.mp3');
    expect(find.byTooltip('Stop Aortic stenosis'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop Aortic stenosis'));
    await tester.pump();
    expect(player.playing.value, isNull);
  });

  testWidgets('a multi-track sound lists each track with its own button',
      (tester) async {
    final player = _FakeSoundPlayer();
    await tester.pumpWidget(_host(
      AudioBlock(title: 'Split S2', tracks: ['a.mp3', 'b.mp3']),
      player,
    ));

    expect(find.text('Track 1'), findsOneWidget);
    expect(find.text('Track 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Play Split S2, track 2'));
    await tester.pump();

    expect(player.playing.value, 'b.mp3');
    expect(find.byTooltip('Stop Split S2, track 2'), findsOneWidget);
    expect(find.byTooltip('Play Split S2, track 1'), findsOneWidget);
  });
}
