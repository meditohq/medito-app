import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

//ignore:prefer-match-file-name
class MockPackRepository extends Mock implements PackRepositoryImpl {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  ProviderContainer makeProviderContainer(MockPackRepository repository) {
    final container = ProviderContainer(
      overrides: [
        packRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  group('getPacks', () {
    test(
      'get packs using the pack repository',
      () async {
        //ARRANGE
        final packResponseData = PackModel(
          id: '28',
          title: 'UCLA',
          description:
              'Guided tracks provided by [UCLA Mindful Awareness Research Center]',
          coverUrl: 'Some test cover url',
          isPublished: true,
          items: [
            PackItemsModel(
              type: 'track',
              id: '120',
              title: 'Complete track',
              subtitle: '19 min',
              path: 'tracks/120',
            ),
          ],
        );
        final mockPackRepository = MockPackRepository();
        when(() => mockPackRepository.fetchPacks('28'))
            .thenAnswer((_) async => packResponseData);

        //ACT
        final container = makeProviderContainer(mockPackRepository);

        //ASSERT
        expect(
          container.read(packsProvider(packId: '28')),
          const AsyncValue<PackModel>.loading(),
        );
        await container.read(packsProvider(packId: '28').future);
        expect(
          container.read(packsProvider(packId: '28')).value,
          isA<PackModel>()
              .having((s) => s.id, 'id', '28')
              .having((s) => s.title, 'title', 'UCLA')
              .having(
                (s) => s.description,
                'description',
                'Guided tracks provided by [UCLA Mindful Awareness Research Center]',
              ),
        );
        verify(
          () => mockPackRepository.fetchPacks('28'),
        ).called(1);
      },
    );
    test(
      'return errors when pack repository throws',
      () async {
        final exception = Exception();
        //ARRANGE
        final mockPackRepository = MockPackRepository();
        when(() => mockPackRepository.fetchPacks('28'))
            .thenAnswer((_) async => throw (exception));

        //ACT
        final container = makeProviderContainer(mockPackRepository);

        //ASSERT
        expect(
          container.read(packsProvider(packId: '28')),
          const AsyncValue<PackModel>.loading(),
        );
        await expectLater(
          container.read(packsProvider(packId: '28').future),
          throwsA(isA<Exception>()),
        );
        expect(
          container.read(packsProvider(packId: '28')),
          isA<AsyncError<PackModel>>()
              .having((e) => e.error, 'error', exception),
        );
        verify(
          () => mockPackRepository.fetchPacks('28'),
        ).called(1);
      },
    );
  });
}
