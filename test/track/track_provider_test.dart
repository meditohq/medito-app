import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

//ignore:prefer-match-file-name
class MockTrackRepository extends Mock implements TrackRepositoryImpl {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  ProviderContainer makeProviderContainer(MockTrackRepository repository) {
    final container = ProviderContainer(
      overrides: [
        trackRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  group('getTrack', () {
    test(
      'get track using the track repository',
      () async {
        //ARRANGE
        final trackResponseData = TrackModel(
          id: '1',
          title: 'Welcome',
          description: '',
          coverUrl: '',
          isPublished: true,
          audio: [
            TrackAudioModel(
              guideName: 'Will',
              files: [
                TrackFilesModel(id: '59', path: '', duration: 48000),
              ],
            ),
          ],
          hasBackgroundSound: false,
        );
        final mockTrackRepository = MockTrackRepository();
        when(() => mockTrackRepository.fetchTrack('1'))
            .thenAnswer((_) async => trackResponseData);

        //ACT
        final container = makeProviderContainer(mockTrackRepository);

        //ASSERT
        expect(
          container.read(tracksProvider(trackId: '1')),
          const AsyncValue<TrackModel>.loading(),
        );
        await container.read(tracksProvider(trackId: '1').future);
        expect(
          container.read(tracksProvider(trackId: '1')).value,
          isA<TrackModel>()
              .having((s) => s.id, 'id', '1')
              .having((s) => s.title, 'title', 'Welcome')
              .having(
                (s) => s.description,
                'description',
                '',
              ),
        );
        verify(
          () => mockTrackRepository.fetchTrack('1'),
        ).called(1);
      },
    );
    test(
      'return errors when track repository throws',
      () async {
        final exception = Exception();
        //ARRANGE
        final mockTrackRepository = MockTrackRepository();
        when(() => mockTrackRepository.fetchTrack('1'))
            .thenAnswer((_) async => throw (exception));

        //ACT
        final container = makeProviderContainer(mockTrackRepository);

        //ASSERT
        expect(
          container.read(tracksProvider(trackId: '1')),
          const AsyncValue<TrackModel>.loading(),
        );
        await expectLater(
          container.read(tracksProvider(trackId: '1').future),
          throwsA(isA<Exception>()),
        );
        expect(
          container.read(tracksProvider(trackId: '1')),
          isA<AsyncError<TrackModel>>()
              .having((e) => e.error, 'error', exception),
        );
        verify(
          () => mockTrackRepository.fetchTrack('1'),
        ).called(1);
      },
    );
  });
}
