import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

//ignore:prefer-match-file-name
class MockSessionRepository extends Mock implements SessionRepositoryImpl {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  ProviderContainer makeProviderContainer(MockSessionRepository repository) {
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  group('getSession', () {
    test(
      'get session using the session repository',
      () async {
        //ARRANGE
        final sessionResponseData = SessionModel(
          id: 1,
          title: 'Welcome',
          description: '',
          coverUrl: '',
          isPublished: true,
          audio: [
            SessionAudioModel(
              guideName: 'Will',
              files: [
                SessionFilesModel(id: 59, path: '', duration: 48000),
              ],
            ),
          ],
          hasBackgroundSound: false,
        );
        final mockSessionRepository = MockSessionRepository();
        when(() => mockSessionRepository.fetchSession(1))
            .thenAnswer((_) async => sessionResponseData);

        //ACT
        final container = makeProviderContainer(mockSessionRepository);

        //ASSERT
        expect(
          container.read(sessionsProvider(sessionId: 1)),
          const AsyncValue<SessionModel>.loading(),
        );
        await container.read(sessionsProvider(sessionId: 1).future);
        expect(
          container.read(sessionsProvider(sessionId: 1)).value,
          isA<SessionModel>()
              .having((s) => s.id, 'id', 1)
              .having((s) => s.title, 'title', 'Welcome')
              .having(
                (s) => s.description,
                'description',
                '',
              ),
        );
        verify(
          () => mockSessionRepository.fetchSession(1),
        ).called(1);
      },
    );
    test(
      'return errors when session repository throws',
      () async {
        final exception = Exception();
        //ARRANGE
        final mockSessionRepository = MockSessionRepository();
        when(() => mockSessionRepository.fetchSession(1))
            .thenAnswer((_) async => throw (exception));

        //ACT
        final container = makeProviderContainer(mockSessionRepository);

        //ASSERT
        expect(
          container.read(sessionsProvider(sessionId: 1)),
          const AsyncValue<SessionModel>.loading(),
        );
        await expectLater(
          container.read(sessionsProvider(sessionId: 1).future),
          throwsA(isA<Exception>()),
        );
        expect(
          container.read(sessionsProvider(sessionId: 1)),
          isA<AsyncError<SessionModel>>()
              .having((e) => e.error, 'error', exception),
        );
        verify(
          () => mockSessionRepository.fetchSession(1),
        ).called(1);
      },
    );
  });
}
