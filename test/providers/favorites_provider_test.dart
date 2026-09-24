import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/repositories/favorites/favorites_repository.dart';

FavoriteItem _item(String id, int timestamp) => FavoriteItem(
  id: id,
  title: 'Title $id',
  type: FavoriteItemType.track,
  timestamp: timestamp,
);

/// In-memory stand-in for local prefs + the /favorites endpoint.
class _FakeRepository implements FavoritesRepository {
  _FakeRepository({required this.local, required this.server});

  List<FavoriteItem> local;
  List<FavoriteItem> server;
  Map<String, int> removed = {};
  bool failPosts = false;
  final posts = <List<String>>[];

  /// When set, GET waits on this and returns the server list as it was
  /// when the request started (a slow fetch racing a removal).
  Completer<void>? holdGet;

  @override
  Future<List<FavoriteItem>> loadFavorites() async => [...local];

  @override
  Future<void> saveFavorites(List<FavoriteItem> favorites) async =>
      local = [...favorites];

  @override
  Future<List<FavoriteItem>> loadFavoritesFromServer() async {
    final snapshot = [...server];
    if (holdGet != null) await holdGet!.future;
    return snapshot;
  }

  @override
  Future<void> syncWithServer(List<FavoriteItem> favorites) async {
    if (failPosts) throw Exception('Contains invalid characters');
    posts.add(favorites.map((f) => f.id).toList());
    server = [...favorites];
  }

  @override
  Future<Map<String, int>> loadRemovedFavorites() async => {...removed};

  @override
  Future<void> saveRemovedFavorites(Map<String, int> value) async =>
      removed = {...value};
}

Future<ProviderContainer> _start(_FakeRepository repo) async {
  final container = ProviderContainer(
    overrides: [favoritesRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await container.read(favoritesNotifierProvider.future);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

List<String> _ids(ProviderContainer c) =>
    c.read(favoritesNotifierProvider).value!.map((f) => f.id).toList();

void main() {
  test(
    'removal during a slow fetch is not undone by the stale response',
    () async {
      final repo = _FakeRepository(
        local: [_item('a', 1), _item('b', 2)],
        server: [_item('a', 1), _item('b', 2)],
      )..holdGet = Completer<void>();
      final container = await _start(repo);

      await container
          .read(favoritesNotifierProvider.notifier)
          .removeFromFavorites('a');
      repo.holdGet!.complete();
      await _settle();

      expect(_ids(container), ['b']);
      expect(repo.local.map((f) => f.id), ['b']);
      expect(repo.server.map((f) => f.id), ['b']);
    },
  );

  test(
    'removal whose upload failed stays removed and is re-pushed later',
    () async {
      final repo = _FakeRepository(
        local: [_item('a', 1), _item('b', 2)],
        server: [_item('a', 1), _item('b', 2)],
      );
      var container = await _start(repo);
      await _settle();

      repo.failPosts = true;
      await container
          .read(favoritesNotifierProvider.notifier)
          .removeFromFavorites('a');
      expect(repo.server.map((f) => f.id), containsAll(['a', 'b']));

      // Next launch, uploads working again.
      container.dispose();
      repo.failPosts = false;
      container = await _start(repo);
      await _settle();

      expect(_ids(container), ['b']);
      expect(repo.server.map((f) => f.id), ['b']);
    },
  );

  test('removing the last favourite clears it on the server', () async {
    final repo = _FakeRepository(
      local: [_item('a', 1)],
      server: [_item('a', 1)],
    );
    var container = await _start(repo);
    await _settle();

    await container
        .read(favoritesNotifierProvider.notifier)
        .removeFromFavorites('a');
    expect(repo.posts.last, isEmpty);

    container.dispose();
    container = await _start(repo);
    await _settle();
    expect(_ids(container), isEmpty);
  });

  test(
    'confirmed removals are forgotten; re-adding clears the removal',
    () async {
      final repo = _FakeRepository(
        local: [_item('a', 1), _item('b', 2)],
        server: [_item('a', 1), _item('b', 2)],
      );
      final container = await _start(repo);
      await _settle();
      final notifier = container.read(favoritesNotifierProvider.notifier);

      await notifier.removeFromFavorites('a');
      expect(repo.removed.keys, ['a']);

      await notifier.addToFavorites(_item('a', 3));
      expect(repo.removed, isEmpty);

      await notifier.removeFromFavorites('b');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await notifier.refreshFromServer();
      expect(repo.removed, isEmpty, reason: 'server no longer has b');
    },
  );

  test('never pushes an empty list when nothing was removed', () async {
    final repo = _FakeRepository(local: [], server: []);
    final container = await _start(repo);
    await _settle();

    await container.read(favoritesNotifierProvider.notifier).syncWithServer();
    expect(repo.posts, isEmpty);
  });
}
