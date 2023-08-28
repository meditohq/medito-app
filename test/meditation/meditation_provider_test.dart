import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

//ignore:prefer-match-file-name
class MockMeditationRepository extends Mock
    implements MeditationRepositoryImpl {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  ProviderContainer makeProviderContainer(MockMeditationRepository repository) {
    final container = ProviderContainer(
      overrides: [
        meditationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  group('getMeditation', () {
    test(
      'get meditation using the meditation repository',
      () async {
        //ARRANGE
        final meditationResponseData = MeditationModel(
          id: '1',
          title: 'Welcome',
          description: '',
          coverUrl: '',
          isPublished: true,
          audio: [
            MeditationAudioModel(
              guideName: 'Will',
              files: [
                MeditationFilesModel(id: '59', path: '', duration: 48000),
              ],
            ),
          ],
          hasBackgroundSound: false,
        );
        final mockMeditationRepository = MockMeditationRepository();
        when(() => mockMeditationRepository.fetchMeditation('1'))
            .thenAnswer((_) async => meditationResponseData);

        //ACT
        final container = makeProviderContainer(mockMeditationRepository);

        //ASSERT
        expect(
          container.read(meditationsProvider(meditationId: '1')),
          const AsyncValue<MeditationModel>.loading(),
        );
        await container.read(meditationsProvider(meditationId: '1').future);
        expect(
          container.read(meditationsProvider(meditationId: '1')).value,
          isA<MeditationModel>()
              .having((s) => s.id, 'id', '1')
              .having((s) => s.title, 'title', 'Welcome')
              .having(
                (s) => s.description,
                'description',
                '',
              ),
        );
        verify(
          () => mockMeditationRepository.fetchMeditation('1'),
        ).called(1);
      },
    );
    test(
      'return errors when meditation repository throws',
      () async {
        final exception = Exception();
        //ARRANGE
        final mockMeditationRepository = MockMeditationRepository();
        when(() => mockMeditationRepository.fetchMeditation('1'))
            .thenAnswer((_) async => throw (exception));

        //ACT
        final container = makeProviderContainer(mockMeditationRepository);

        //ASSERT
        expect(
          container.read(meditationsProvider(meditationId: '1')),
          const AsyncValue<MeditationModel>.loading(),
        );
        await expectLater(
          container.read(meditationsProvider(meditationId: '1').future),
          throwsA(isA<Exception>()),
        );
        expect(
          container.read(meditationsProvider(meditationId: '1')),
          isA<AsyncError<MeditationModel>>()
              .having((e) => e.error, 'error', exception),
        );
        verify(
          () => mockMeditationRepository.fetchMeditation('1'),
        ).called(1);
      },
    );
  });
}
