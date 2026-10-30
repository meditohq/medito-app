import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
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

class _QueuedHomeRepository implements HomeRepositoryImpl {
  _QueuedHomeRepository(this.responses);
  final List<Completer<HomeModel>> responses;
  @override
  Future<HomeModel> fetchHome() => responses.removeAt(0).future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePackRepository implements PackRepositoryImpl {
  _FakePackRepository({this.pack, this.error});
  final PackModel? pack;
  final Object? error;
  Completer<PackModel>? gate;
  final requestedIds = <String>[];

  @override
  Future<PackModel> fetchPacks(String packId) async {
    requestedIds.add(packId);
    if (gate != null) return gate!.future;
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
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.userId: 'test-user',
    });
    prefs = await SharedPreferences.getInstance();
  });
  Future<HomeModel> readHome(ProviderContainer container) async {
    container.listen(homeContentProvider, (_, _) {});
    await container.read(fetchHomeProvider.future);
    await container.pump();
    if (container.exists(spanishFeaturedPackProvider)) {
      try {
        await container.read(spanishFeaturedPackProvider.future);
      } catch (_) {}
      await container.pump();
    }
    return container.read(homeContentProvider).requireValue;
  }

  ProviderContainer makeContainer({
    required List<Locale> locales,
    required HomeModel home,
    required _FakePackRepository packs,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocalesProvider.overrideWithValue(locales),
        homeRepositoryProvider.overrideWithValue(_FakeHomeRepository(home)),
        packRepositoryProvider.overrideWithValue(packs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('slow Spanish enrichment never holds up the base feed', () async {
    final packs = _FakePackRepository()..gate = Completer<PackModel>();
    final container = makeContainer(
      locales: const [Locale('es')],
      home: const HomeModel(carousel: [_networkCard]),
      packs: packs,
    );
    container.listen(homeContentProvider, (_, _) {});
    await container.read(fetchHomeProvider.future);
    await container.pump();
    final home = container.read(homeContentProvider).requireValue;
    expect(home.carousel, [_networkCard]);
    expect(packs.requestedIds, [kSpanishFeaturedPackId]);
    packs.gate!.complete(_spanishPack);
    await container.pump();
    expect(
      container.read(homeContentProvider).requireValue.carousel.first.id,
      kSpanishFeaturedPackId,
    );
  });

  test(
    'saved feed displays immediately, updates online and survives offline refresh',
    () async {
      final first = makeContainer(
        locales: const [Locale('en')],
        home: const HomeModel(greeting: 'Saved home', carousel: [_networkCard]),
        packs: _FakePackRepository(),
      );
      await readHome(first);
      await first.pump();
      final response = Completer<HomeModel>();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue(const [Locale('en')]),
          fetchHomeProvider.overrideWith((ref) => response.future),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeContentProvider, (_, _) {});
      expect(
        container.read(homeContentProvider).requireValue.greeting,
        'Saved home',
      );
      response.complete(const HomeModel(greeting: 'Fresh home'));
      await container.pump();
      expect(
        container.read(homeContentProvider).requireValue.greeting,
        'Fresh home',
      );
      container.updateOverrides([
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocalesProvider.overrideWithValue(const [Locale('en')]),
        fetchHomeProvider.overrideWith(
          (ref) async => throw Exception('offline'),
        ),
      ]);
      await container.pump();
      expect(
        container.read(homeContentProvider).requireValue.greeting,
        'Fresh home',
      );
    },
  );

  test('an account switch rejects an old in-flight feed response', () async {
    final previous = Completer<HomeModel>(), current = Completer<HomeModel>();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocalesProvider.overrideWithValue(const [Locale('en')]),
        homeRepositoryProvider.overrideWithValue(
          _QueuedHomeRepository([previous, current]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(homeContentProvider, (_, _) {});
    await prefs.setString(
      SharedPreferenceConstants.userId,
      'another-test-user',
    );
    container.invalidate(homeCacheScopeProvider);
    await container.pump();
    previous.complete(const HomeModel(greeting: 'Previous account'));
    await container.pump();
    expect(container.read(homeContentProvider).isLoading, isTrue);
    expect(prefs.getString(homeFeedCacheKey), isNull);
    current.complete(const HomeModel(greeting: 'Current account'));
    await container.pump();
    expect(
      container.read(homeContentProvider).requireValue.greeting,
      'Current account',
    );
  });

  test('wrong-account, expired and corrupt caches are ignored', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocalesProvider.overrideWithValue(const [Locale('en')]),
        fetchHomeProvider.overrideWith((ref) => Completer<HomeModel>().future),
      ],
    );
    addTearDown(container.dispose);
    final scope = container.read(homeCacheScopeProvider);
    for (final raw in [
      'broken json',
      jsonEncode({
        'scope': 'different-account',
        'saved_at': DateTime.now().millisecondsSinceEpoch,
        'home': const HomeModel(greeting: 'Private').toJson(),
      }),
      jsonEncode({
        'scope': scope,
        'saved_at': DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch,
        'home': const HomeModel(greeting: 'Old').toJson(),
      }),
    ]) {
      await prefs.setString(homeFeedCacheKey, raw);
      container.invalidate(homeFeedProvider);
      expect(container.read(homeFeedProvider).isLoading, isTrue);
    }
  });

  group('fetchHome Spanish featured pack', () {
    test(
      'prepends the Spanish pack when any device locale is Spanish',
      () async {
        final packs = _FakePackRepository(pack: _spanishPack);
        final container = makeContainer(
          locales: const [Locale('en', 'US'), Locale('es', 'MX')],
          home: const HomeModel(carousel: [_networkCard]),
          packs: packs,
        );

        final home = await readHome(container);

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
      },
    );

    test('leaves the carousel untouched without a Spanish locale', () async {
      final packs = _FakePackRepository(pack: _spanishPack);
      final container = makeContainer(
        locales: const [Locale('en', 'GB'), Locale('fr')],
        home: const HomeModel(carousel: [_networkCard]),
        packs: packs,
      );

      final home = await readHome(container);

      expect(packs.requestedIds, isEmpty);
      expect(home.carousel, [_networkCard]);
    });

    test(
      'does not duplicate the pack if the network already features it',
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

        final home = await readHome(container);

        expect(packs.requestedIds, isEmpty);
        expect(home.carousel, [_networkCard, alreadyThere]);
      },
    );

    test(
      'falls back to the network carousel when the pack fetch fails',
      () async {
        final packs = _FakePackRepository(error: Exception('offline'));
        final container = makeContainer(
          locales: const [Locale('es', 'ES')],
          home: const HomeModel(carousel: [_networkCard]),
          packs: packs,
        );

        final home = await readHome(container);

        expect(home.carousel, [_networkCard]);
      },
    );
  });
}
