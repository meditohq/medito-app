import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/pack/packs_repository.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Stats extends StatsNotifier {
  _Stats(this.checked);
  final List<String> checked;

  @override
  Future<LocalAllStats> build() async =>
      LocalAllStats.empty().copyWith(tracksChecked: checked);
}

class _FakeClient implements HttpApiService {
  _FakeClient(this.response);
  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> getRequest(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements PackRepositoryImpl {
  _FakeRepo({this.packTracks = const {}, this.pack, this.error});
  final Map<String, List<String>> packTracks;
  final PackModel? pack;
  final Object? error;

  @override
  Future<Map<String, List<String>>> fetchPackTrackIds() async {
    if (error != null) throw error!;
    return packTracks;
  }

  @override
  Future<PackModel> fetchPacks(String packId) async => pack!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _container(
  _FakeRepo repo,
  List<String> checked, {
  SharedPreferences? prefs,
}) async {
  if (prefs == null) {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  }
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      packRepositoryProvider.overrideWithValue(repo),
      statsProvider.overrideWith(() => _Stats(checked)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

PackItemsModel _item(String type, String id, {bool? done}) => PackItemsModel(
  type: type,
  id: id,
  title: id,
  path: '/$id',
  isCompleted: done,
);

Future<Set<String>> _completed(ProviderContainer container) async {
  container.listen(completedPackIdsProvider, (_, _) {});
  await container.read(packTrackIdsProvider.future);
  await container.read(statsProvider.future);
  return container.read(completedPackIdsProvider);
}

void main() {
  group('completedPackIdsProvider', () {
    test('ticks a pack only when all its tracks are checked', () async {
      final container = await _container(
        _FakeRepo(
          packTracks: {
            'sleep': ['a', 'b'],
            'focus': ['b', 'c'],
          },
        ),
        ['a', 'b'],
      );

      expect(await _completed(container), {'sleep'});
    });

    test('a shared track counts towards every pack that has it', () async {
      final container = await _container(
        _FakeRepo(
          packTracks: {
            'sleep': ['shared'],
            'rest': ['shared'],
          },
        ),
        ['shared'],
      );

      expect(await _completed(container), {'sleep', 'rest'});
    });

    test('never ticks a pack with no tracks', () async {
      final container = await _container(
        _FakeRepo(packTracks: {'empty': []}),
        ['a'],
      );

      expect(await _completed(container), isEmpty);
    });

    test('shows no ticks when the endpoint fails', () async {
      final container = await _container(
        _FakeRepo(error: Exception('offline')),
        ['a'],
      );

      expect(await _completed(container), isEmpty);
    });
  });

  test('packProvider marks completed sub-pack rows', () async {
    final container = await _container(
      _FakeRepo(
        packTracks: {
          'done': ['a'],
          'todo': ['b'],
        },
        pack: const PackModel(
          id: 'parent',
          title: 'Parent',
          items: [
            PackItemsModel(
              type: TypeConstants.pack,
              id: 'done',
              title: 'Done',
              path: '/packs/done',
            ),
            PackItemsModel(
              type: TypeConstants.pack,
              id: 'todo',
              title: 'Todo',
              path: '/packs/todo',
            ),
            PackItemsModel(
              type: TypeConstants.track,
              id: 'a',
              title: 'A',
              path: '/tracks/a',
            ),
          ],
        ),
      ),
      ['a'],
    );
    container.listen(packProvider(packId: 'parent'), (_, _) {});
    await container.read(packDataProvider(packId: 'parent').future);
    await _completed(container);

    final items = container.read(packProvider(packId: 'parent')).value!.items;
    expect(items.map((i) => i.isCompleted), [true, false, true]);
  });

  group('isPackFullyComplete', () {
    PackModel pack(List<PackItemsModel> items) =>
        PackModel(id: 'p', title: 'P', items: items);

    test('true when all tracks and sub-packs are completed', () {
      expect(
        isPackFullyComplete(
          pack([
            _item(TypeConstants.track, 't', done: true),
            _item(TypeConstants.pack, 's', done: true),
          ]),
        ),
        isTrue,
      );
    });

    test('false when one item is not completed', () {
      expect(
        isPackFullyComplete(
          pack([
            _item(TypeConstants.track, 't', done: true),
            _item(TypeConstants.track, 'u', done: false),
          ]),
        ),
        isFalse,
      );
    });

    test('false for an empty pack', () {
      expect(isPackFullyComplete(pack([])), isFalse);
    });

    test('ignores link items', () {
      expect(
        isPackFullyComplete(
          pack([
            _item(TypeConstants.track, 't', done: true),
            _item(TypeConstants.link, 'l'),
          ]),
        ),
        isTrue,
      );
    });
  });

  group('locallyCompletedPacksProvider', () {
    test('setComplete adds, removes and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = await _container(_FakeRepo(), [], prefs: prefs);
      final notifier = container.read(locallyCompletedPacksProvider.notifier);

      notifier.setComplete('p1', true);
      expect(container.read(locallyCompletedPacksProvider), {'p1'});
      expect(prefs.getStringList('locally_completed_pack_ids'), ['p1']);

      notifier.setComplete('p1', false);
      expect(container.read(locallyCompletedPacksProvider), isEmpty);
      expect(prefs.getStringList('locally_completed_pack_ids'), isEmpty);
    });

    test('setComplete is a no-op when unchanged', () async {
      final container = await _container(_FakeRepo(), []);
      var calls = 0;
      container.listen(locallyCompletedPacksProvider, (_, _) => calls++);
      final notifier = container.read(locallyCompletedPacksProvider.notifier);

      notifier.setComplete('p1', false);
      expect(calls, 0);
      notifier.setComplete('p1', true);
      notifier.setComplete('p1', true);
      expect(calls, 1);
    });

    test('survives a new container on the same preferences', () async {
      SharedPreferences.setMockInitialValues({
        'locally_completed_pack_ids': ['p1'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = await _container(_FakeRepo(), [], prefs: prefs);

      expect(container.read(locallyCompletedPacksProvider), {'p1'});
    });
  });

  group('local completion in completedPackIdsProvider', () {
    test('ticks a locally recorded pack when the endpoint fails', () async {
      final container = await _container(
        _FakeRepo(error: Exception('offline')),
        [],
      );
      container
          .read(locallyCompletedPacksProvider.notifier)
          .setComplete('p1', true);

      expect(await _completed(container), {'p1'});
    });

    test('recording then un-recording removes the tick', () async {
      final container = await _container(_FakeRepo(), []);
      final notifier = container.read(locallyCompletedPacksProvider.notifier);

      notifier.setComplete('p1', true);
      expect(await _completed(container), {'p1'});
      notifier.setComplete('p1', false);
      expect(container.read(completedPackIdsProvider), isEmpty);
    });

    test('unions server-derived and local ids', () async {
      final container = await _container(
        _FakeRepo(
          packTracks: {
            'a': ['t'],
          },
        ),
        ['t'],
      );
      container
          .read(locallyCompletedPacksProvider.notifier)
          .setComplete('b', true);

      expect(await _completed(container), {'a', 'b'});
    });

    test('packProvider ticks a sub-pack recorded locally', () async {
      final container = await _container(
        _FakeRepo(
          pack: PackModel(
            id: 'parent',
            title: 'Parent',
            items: [_item(TypeConstants.pack, 'child')],
          ),
        ),
        [],
      );
      container
          .read(locallyCompletedPacksProvider.notifier)
          .setComplete('child', true);
      container.listen(packProvider(packId: 'parent'), (_, _) {});
      await container.read(packDataProvider(packId: 'parent').future);
      await _completed(container);

      final items = container.read(packProvider(packId: 'parent')).value!.items;
      expect(items.map((i) => i.isCompleted), [true]);
    });
  });

  test('fetchPackTrackIds parses the packTracks map', () async {
    final repo = PackRepositoryImpl(
      client: _FakeClient({
        'packTracks': {
          'sleep': ['a', 'b'],
          'odd': 'not a list',
        },
      }),
    );

    expect(await repo.fetchPackTrackIds(), {
      'sleep': ['a', 'b'],
    });
  });
}
