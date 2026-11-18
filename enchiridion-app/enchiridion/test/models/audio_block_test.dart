import 'package:enchiridion/models/content_block.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio blocks parse their title and tracks and round-trip', () {
    final json = {
      'type': 'audio',
      'title': 'Mitral regurgitation',
      'tracks': [
        'assets/audio/sounds/mr_1.mp3',
        'assets/audio/sounds/mr_2.mp3'
      ],
    };

    final block = ContentBlock.fromJson(json);

    expect(block, isA<AudioBlock>());
    final audio = block as AudioBlock;
    expect(audio.type, BlockType.audio);
    expect(audio.title, 'Mitral regurgitation');
    expect(audio.tracks, hasLength(2));
    expect(audio.toJson(), json);
  });

  test('an audio block without tracks parses to an empty list', () {
    final block = ContentBlock.fromJson({'type': 'audio', 'title': 'S3'});
    expect((block as AudioBlock).tracks, isEmpty);
  });
}
