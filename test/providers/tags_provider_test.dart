import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/models/tags/tag_model.dart';
import 'package:medito/providers/tags/tags_provider.dart';
import 'package:medito/repositories/tags/tags_repository.dart';

class _FakeTagsRepository implements TagsRepository {
  _FakeTagsRepository({this.catalog, this.error});
  final TagCatalog? catalog;
  final Object? error;
  int calls = 0;

  @override
  Future<TagCatalog> fetchCatalog() async {
    calls++;
    if (error != null) throw error!;
    return catalog!;
  }

  @override
  Future<List<TrackItem>> fetchTracksForTag(String tagId) async => const [];
}

ProviderContainer _container(TagsRepository repo) {
  final container = ProviderContainer(
    overrides: [tagsRepositoryProvider.overrideWithValue(repo)],
    // Riverpod 3 retries failed providers by default; keep tests deterministic.
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final catalog = TagCatalog.fromJson({
    'tags': [
      {'id': 'sleep', 'group': 'goal', 'description': 'd'},
    ],
    'trackTags': {'t1': ['sleep']},
  });

  test('catalog is empty while loading', () {
    final c = _container(_FakeTagsRepository(catalog: catalog));
    expect(c.read(tagCatalogProvider).isEmpty, isTrue);
    expect(c.read(trackTagsProvider('t1')), isEmpty);
  });

  test('catalog exposes tags once loaded', () async {
    final c = _container(_FakeTagsRepository(catalog: catalog));
    await c.read(tagCatalogFetchProvider.future);
    expect(c.read(tagCatalogProvider).tags.single.id, 'sleep');
    expect(c.read(trackTagsProvider('t1')).single.id, 'sleep');
    expect(c.read(trackTagsProvider('other')), isEmpty);
  });

  test('API failure reads as no tags, never throws', () async {
    final repo = _FakeTagsRepository(error: Exception('500'));
    final c = _container(repo);
    // The fetch provider schedules its own delayed retries after a failure,
    // so observe the error state rather than awaiting `.future`.
    c.listen(tagCatalogFetchProvider, (_, _) {});
    for (var i = 0; i < 20 && !c.read(tagCatalogFetchProvider).hasError; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.read(tagCatalogFetchProvider).hasError, isTrue);
    expect(c.read(tagCatalogProvider).isEmpty, isTrue);
    expect(c.read(trackTagsProvider('t1')), isEmpty);
    expect(repo.calls, 1);
  });
}
