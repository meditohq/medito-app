import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/view_model/folder/folder_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFolderRepository extends Mock implements FolderRepositoryImpl {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  ProviderContainer makeProviderContainer(MockFolderRepository repository) {
    final container = ProviderContainer(
      overrides: [
        folderRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('getFolders', () {
    test(
      'get folders using the folder repository',
      () async {
        //ARRANGE
        final folderResponseData = FolderModel(
          id: 28,
          title: 'UCLA',
          description:
              'Guided meditations provided by [UCLA Mindful Awareness Research Center]',
          coverUrl: 'Some test cover url',
          isPublished: true,
          items: [
            FolderItemsModel(
                type: 'session',
                id: 120,
                title: 'Complete meditation',
                subtitle: '19 min',
                path: 'sessions/120')
          ],
        );
        final mockFolderRepository = MockFolderRepository();
        when(() => mockFolderRepository.fetchFolders(28))
            .thenAnswer((_) async => folderResponseData);

        //ACT
        final container = makeProviderContainer(mockFolderRepository);

        //ASSERT
        expect(
          container.read(foldersProvider(folderId: 28)),
          const AsyncValue<FolderModel>.loading(),
        );
        await container.read(foldersProvider(folderId: 28).future);
        expect(
          container.read(foldersProvider(folderId: 28)).value,
          isA<FolderModel>()
              .having((s) => s.id, 'id', 28)
              .having((s) => s.title, 'title', 'UCLA')
              .having((s) => s.description, 'description',
                  'Guided meditations provided by [UCLA Mindful Awareness Research Center]'),
        );
        verify(
          () => mockFolderRepository.fetchFolders(28),
        ).called(1);
      },
    );
    test(
      'return errors when folder repository throws',
      () async {
        final exception = Exception();
        //ARRANGE
        final mockFolderRepository = MockFolderRepository();
        when(() => mockFolderRepository.fetchFolders(28))
            .thenAnswer((_) async => throw (exception));

        //ACT
        final container = makeProviderContainer(mockFolderRepository);

        //ASSERT
        expect(
          container.read(foldersProvider(folderId: 28)),
          const AsyncValue<FolderModel>.loading(),
        );
        await expectLater(
          container.read(foldersProvider(folderId: 28).future),
          throwsA(isA<Exception>()),
        );
        expect(
          container.read(foldersProvider(folderId: 28)),
          isA<AsyncError<FolderModel>>()
              .having((e) => e.error, 'error', exception),
        );
        verify(
          () => mockFolderRepository.fetchFolders(28),
        ).called(1);
      },
    );
  });
}
