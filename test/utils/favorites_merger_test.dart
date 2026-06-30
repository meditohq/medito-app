import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/utils/favorites_merger.dart';

void main() {
  // Helper to create a FavoriteItem for tests
  FavoriteItem createTestItem({
    required String id,
    String title = 'Test Title',
    FavoriteItemType type = FavoriteItemType.track,
    required int timestamp,
    String? subtitle,
    String? coverUrl,
    String? path,
  }) {
    return FavoriteItem(
      id: id,
      title: title,
      type: type,
      timestamp: timestamp,
      subtitle: subtitle,
      coverUrl: coverUrl,
      path: path ?? '/path/to/$id',
    );
  }

  group('mergeFavoriteLists', () {
    test('should return empty list when both inputs are empty', () {
      final result = mergeFavoriteLists([], []);

      expect(result, isEmpty);
    });

    test('should return local items when server list is empty', () {
      final local = [
        createTestItem(id: '1', timestamp: 100),
        createTestItem(id: '2', timestamp: 200),
      ];
      final result = mergeFavoriteLists(local, []);

      // Expect same items, sorted by timestamp desc
      expect(result.length, 2);
      expect(result[0].id, '2');
      expect(result[1].id, '1');
    });

    test('should return server items when local list is empty', () {
      final server = [
        createTestItem(id: 'a', timestamp: 300),
        createTestItem(id: 'b', timestamp: 400),
      ];
      final result = mergeFavoriteLists([], server);

      // Expect same items, sorted by timestamp desc
      expect(result.length, 2);
      expect(result[0].id, 'b');
      expect(result[1].id, 'a');
    });

    test('should combine unique items from both lists', () {
      final local = [createTestItem(id: '1', timestamp: 100)];
      final server = [createTestItem(id: 'a', timestamp: 300)];
      final result = mergeFavoriteLists(local, server);

      expect(result.length, 2);
      expect(result.map((e) => e.id), containsAll(['1', 'a']));
      // Check sorting
      expect(result[0].id, 'a');
      expect(result[1].id, '1');
    });

    test('should keep local item when it is newer than server item', () {
      final local = [
        createTestItem(id: '1', title: 'Local Newer', timestamp: 500),
      ];
      final server = [
        createTestItem(id: '1', title: 'Server Older', timestamp: 300),
      ];
      final result = mergeFavoriteLists(local, server);

      expect(result.length, 1);
      expect(result[0].id, '1');
      expect(result[0].title, 'Local Newer');
      expect(result[0].timestamp, 500);
    });

    test('should take server item when it is newer than local item', () {
      final local = [
        createTestItem(id: '1', title: 'Local Older', timestamp: 300),
      ];
      final server = [
        createTestItem(id: '1', title: 'Server Newer', timestamp: 500),
      ];
      final result = mergeFavoriteLists(local, server);

      expect(result.length, 1);
      expect(result[0].id, '1');
      expect(result[0].title, 'Server Newer');
      expect(result[0].timestamp, 500);
    });

    test('should keep local item when timestamps are equal', () {
      // Based on the implementation, local items are added first,
      // and server items only overwrite if strictly newer (>)
      final local = [
        createTestItem(id: '1', title: 'Local Same', timestamp: 500),
      ];
      final server = [
        createTestItem(id: '1', title: 'Server Same', timestamp: 500),
      ];
      final result = mergeFavoriteLists(local, server);

      expect(result.length, 1);
      expect(result[0].id, '1');
      expect(result[0].title, 'Local Same'); // Local version should be kept
      expect(result[0].timestamp, 500);
    });

    test('should correctly merge a complex mix of items', () {
      final local = [
        createTestItem(id: '1', timestamp: 100), // Unique local
        createTestItem(id: '2', timestamp: 500), // Newer local
        createTestItem(id: '3', timestamp: 300), // Older local
        createTestItem(id: '4', timestamp: 700), // Equal local
      ];
      final server = [
        createTestItem(id: 'a', timestamp: 200), // Unique server
        createTestItem(id: '2', timestamp: 300), // Older server
        createTestItem(id: '3', timestamp: 600), // Newer server
        createTestItem(id: '4', timestamp: 700), // Equal server
      ];

      final result = mergeFavoriteLists(local, server);

      // Expected IDs: a (200), 1 (100), 3 (600 - server), 2 (500 - local), 4 (700 - local)
      // Expected final sorted order by timestamp desc: 4, 3, 2, a, 1
      expect(result.length, 5);
      expect(result.map((e) => e.id), containsAll(['1', '2', '3', '4', 'a']));

      // Check specific items and their sources based on timestamps
      expect(result[0].id, '4');
      expect(result[0].timestamp, 700); // Kept local (equal timestamp)

      expect(result[1].id, '3');
      expect(result[1].timestamp, 600); // Took server (newer)

      expect(result[2].id, '2');
      expect(result[2].timestamp, 500); // Kept local (newer)

      expect(result[3].id, 'a');
      expect(result[3].timestamp, 200); // Unique server

      expect(result[4].id, '1');
      expect(result[4].timestamp, 100); // Unique local
    });

    test('should handle different types correctly', () {
      final local = [
        createTestItem(
          id: 'track1',
          type: FavoriteItemType.track,
          timestamp: 100,
        ),
      ];
      final server = [
        createTestItem(
          id: 'pack1',
          type: FavoriteItemType.pack,
          timestamp: 200,
        ),
      ];
      final result = mergeFavoriteLists(local, server);

      expect(result.length, 2);
      expect(result[0].id, 'pack1');
      expect(result[0].type, FavoriteItemType.pack);
      expect(result[1].id, 'track1');
      expect(result[1].type, FavoriteItemType.track);
    });
  });

  test('should handle different types correctly and timestamps are equal', () {
    final local = [
      createTestItem(
        id: 'track1',
        type: FavoriteItemType.track,
        timestamp: 100,
      ),
    ];
    final server = [
      createTestItem(id: 'pack1', type: FavoriteItemType.pack, timestamp: 100),
    ];
    final result = mergeFavoriteLists(local, server);

    expect(result.length, 2);
    // Adjust order based on stable sort with equal timestamps
    expect(result[0].id, 'track1');
    expect(result[0].type, FavoriteItemType.track);
    expect(result[1].id, 'pack1');
    expect(result[1].type, FavoriteItemType.pack);
  });
}
