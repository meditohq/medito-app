import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/utils/track_variant_selector.dart';

TrackAudioFile _file(int minutes) => TrackAudioFile(
  id: 'f$minutes',
  path: 'https://example.com/$minutes.mp3',
  duration: minutes * 60000,
);

Track _track(List<TrackVoice> voices) => Track(
  id: 't',
  title: 'Track',
  description: '',
  coverUrl: '',
  isPublished: true,
  hasBackgroundSound: false,
  voices: voices,
);

void main() {
  final will = TrackVoice(guideName: 'Will', audioFiles: [_file(5), _file(10)]);
  final tasha = TrackVoice(guideName: 'Tasha', audioFiles: [_file(10)]);

  group('defaultsFromPlay', () {
    test('saves the played voice and length when neither is set', () {
      final d = TrackVariantSelector.defaultsFromPlay(
        _track([will, tasha]),
        will,
        _file(5),
      );
      expect(d.guideName, 'Will');
      expect(d.durationMs, 5 * 60000);
    });

    test('leaves saved defaults alone', () {
      final d = TrackVariantSelector.defaultsFromPlay(
        _track([will, tasha]),
        will,
        _file(5),
        savedGuideName: 'Tasha',
        savedDurationMs: 10 * 60000,
      );
      expect(d.guideName, isNull);
      expect(d.durationMs, isNull);
    });

    test('a single-voice, single-length track decides nothing', () {
      final d = TrackVariantSelector.defaultsFromPlay(
        _track([tasha]),
        tasha,
        _file(10),
      );
      expect(d.guideName, isNull);
      expect(d.durationMs, isNull);
    });

    test('only the dimension with a choice is saved', () {
      final d = TrackVariantSelector.defaultsFromPlay(
        _track([will]),
        will,
        _file(10),
      );
      expect(d.guideName, isNull);
      expect(d.durationMs, 10 * 60000);
    });

    test('an unnamed voice is never saved', () {
      final unnamed = TrackVoice(audioFiles: [_file(5)]);
      final d = TrackVariantSelector.defaultsFromPlay(
        _track([unnamed, tasha]),
        unnamed,
        _file(5),
      );
      expect(d.guideName, isNull);
    });
  });
}
