import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/providers/home/home_provider.dart';
import 'package:medito/providers/locale_provider.dart';
import 'package:medito/repositories/home/home_repository.dart';
import 'package:medito/repositories/pack/packs_repository.dart';

class _FakeHomeRepository implements HomeRepositoryImpl {
  _FakeHomeRepository(this.home);
  final HomeModel home;

  @override
  Future<HomeModel> fetchHome() async => home;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePackRepository implements PackRepositoryImpl {
  _FakePackRepository({this.pack, this.error});
  final PackModel? pack;
  final Object? error;
  final requestedIds = <String>[];

  @override
  Future<PackModel> fetchPacks(String packId) async {
    requestedIds.add(packId);
    if (error != null) throw error!;
    return pack!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _networkCard = HomeCarouselModel(
  id: 'net-1',
  title: 'From the network',
  subtitle: 'sub',
  coverUrl: 'https://example.com/net.jpg',
  path: 'packs/net-1',
  type: 'pack',
);

const _spanishPack = PackModel(
  id: kSpanishFeaturedPackId,
  title: 'Meditación en español',
  subtitle: 'Guiadas',
  coverUrl: 'https://example.com/es.jpg',
  path: 'packs/$kSpanishFeaturedPackId',
);

void main() {
  ProviderContainer makeContainer({
    required List<Locale> locales,
    required HomeModel home,
    required _FakePackRepository packs,
  }) {
    final container = ProviderContainer(
      overrides: [
        deviceLocalesProvider.overrideWithValue(locales),
        homeRepositoryProvider.overrideWithValue(_FakeHomeRepository(home)),
        packRepositoryProvider.overrideWithValue(packs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('fetchHome Spanish featured pack', () {
    test('prepends the Spanish pack when any device locale is Spanish',
        () async {
      final packs = _FakePackRepository(pack: _spanishPack);
      final container = makeContainer(
        locales: const [Locale('en', 'US'), Locale('es', 'MX')],
        home: const HomeModel(carousel: [_networkCard]),
        packs: packs,
      );

      final home = await container.read(fetchHomeProvider.future);

      expect(packs.requestedIds, [kSpanishFeaturedPackId]);
      expect(home.carousel.map((c) => c.id), [
        kSpanishFeaturedPackId,
        'net-1',
      ]);
      final card = home.carousel.first;
      expect(card.title, 'Meditación en español');
      expect(card.subtitle, 'Guiadas');
      expect(card.coverUrl, 'https://example.com/es.jpg');
      expect(card.path, 'packs/$kSpanishFeaturedPackId');
      expect(card.type, 'pack');
    });

    test('leaves the carousel untouched without a Spanish locale', () async {
      final packs = _FakePackRepository(pack: _spanishPack);
      final container = makeContainer(
        locales: const [Locale('en', 'GB'), Locale('fr')],
        home: const HomeModel(carousel: [_networkCard]),
        packs: packs,
      );

      final home = await container.read(fetchHomeProvider.future);

      expect(packs.requestedIds, isEmpty);
      expect(home.carousel, [_networkCard]);
    });

    test('does not duplicate the pack if the network already features it',
        () async {
      final packs = _FakePackRepository(pack: _spanishPack);
      const alreadyThere = HomeCarouselModel(
        id: 'carousel-es',
        title: 'Server card',
        subtitle: '',
        coverUrl: '',
        path: 'packs/$kSpanishFeaturedPackId',
        type: 'pack',
      );
      final container = makeContainer(
        locales: const [Locale('es')],
        home: const HomeModel(carousel: [_networkCard, alreadyThere]),
        packs: packs,
      );

      final home = await container.read(fetchHomeProvider.future);

      expect(packs.requestedIds, isEmpty);
      expect(home.carousel, [_networkCard, alreadyThere]);
    });

    test('falls back to the network carousel when the pack fetch fails',
        () async {
      final packs = _FakePackRepository(error: Exception('offline'));
      final container = makeContainer(
        locales: const [Locale('es', 'ES')],
        home: const HomeModel(carousel: [_networkCard]),
        packs: packs,
      );

      final home = await container.read(fetchHomeProvider.future);

      expect(home.carousel, [_networkCard]);
    });
  });
}
