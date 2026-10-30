import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/views/home/widgets/header/home_hero.dart';

void main() {
  test(
    'keeps the cover while progress reloads and the pack refreshes',
    () async {
      const pack = PackModel(id: 'pinned', title: 'Pinned', coverUrl: '/cover');
      var response = Completer<PackModel>()..complete(pack);
      final container = ProviderContainer(
        overrides: [
          upNextPackIdProvider.overrideWithValue(pack.id),
          packDataProvider(
            packId: pack.id,
          ).overrideWith((ref) => response.future),
          // Session progress may be unresolved on return from the player.
          upNextProvider.overrideWith((ref) => const AsyncLoading()),
        ],
      );
      addTearDown(container.dispose);
      final covers = <String?>[];
      container.listen(
        homeHeroCoverProvider,
        (_, cover) => covers.add(cover),
        fireImmediately: true,
      );
      await container.read(packDataProvider(packId: pack.id).future);
      expect(container.read(homeHeroCoverProvider), '/cover');

      covers.clear();
      response = Completer<PackModel>();
      container.invalidate(packDataProvider(packId: pack.id));
      expect(container.read(homeHeroCoverProvider), '/cover');
      response.complete(pack);
      await container.read(packDataProvider(packId: pack.id).future);
      expect(container.read(homeHeroCoverProvider), '/cover');
      expect(covers, isNot(contains(null)));
    },
  );
}
