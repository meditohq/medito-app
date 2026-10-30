import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import '../shared_preference/shared_preference_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/types/type_constants.dart';
import '../../models/home/home_model.dart';
import '../../models/pack/pack_model.dart';
import '../../repositories/home/home_repository.dart';
import '../../repositories/pack/packs_repository.dart';
import '../../utils/logger.dart';
import '../locale_provider.dart';

part 'home_provider.g.dart';

/// Pack pinned to the front of the Featured carousel for anyone whose phone
/// lists Spanish among its preferred languages (https://medito.app/packs/…).
/// The app UI is still English-only, so this is how Spanish speakers find
/// the Spanish content until the backend serves a localised home feed.
const String kSpanishFeaturedPackId = 'amjI3HrH0InbmBiW';

@riverpod
Future<HomeModel> fetchHome(Ref ref) async {
  ref.watch(homeCacheScopeProvider);
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchHome();
}

/// Invalidated when Home mounts, including after an account switch. The cache
/// envelope also guards account, backend and language on every read/write.
final homeCacheScopeProvider = Provider<String>(
  (ref) => jsonEncode([
    contentBaseUrl,
    ref.watch(localeProvider)?.languageCode ?? 'en',
    ref
        .watch(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.userId),
  ]),
);

const homeFeedCacheKey = 'home_feed_cache_v1';
const _cacheLifetime = Duration(days: 7);

HomeModel? _cachedHome(Ref ref, String scope) {
  try {
    final raw = ref.read(sharedPreferencesProvider).getString(homeFeedCacheKey);
    if (raw == null) return null;
    final saved = jsonDecode(raw) as Map<String, dynamic>;
    final age =
        DateTime.now().millisecondsSinceEpoch - (saved['saved_at'] as int);
    if (saved['scope'] != scope ||
        age < 0 ||
        age > _cacheLifetime.inMilliseconds) {
      return null;
    }
    return HomeModel.fromJson(saved['home'] as Map<String, dynamic>);
  } catch (_) {
    return null; // A corrupt/older cache must never break Home.
  }
}

/// Base Home content stays visible during refresh or a network failure. Only
/// the editorial feed is cached: announcements, assignments and user stats
/// retain their own validation and persistence paths.
final homeFeedProvider = Provider<AsyncValue<HomeModel>>((ref) {
  final scope = ref.watch(homeCacheScopeProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final network = ref.watch(fetchHomeProvider);
  final cached = _cachedHome(ref, scope);
  return network.when(
    skipLoadingOnRefresh: false,
    skipLoadingOnReload: false,
    data: (home) {
      unawaited(
        prefs
            .setString(
              homeFeedCacheKey,
              jsonEncode({
                'scope': scope,
                'saved_at': DateTime.now().millisecondsSinceEpoch,
                'home': home.toJson(),
              }),
            )
            .catchError((Object error) => false),
      );
      return AsyncData(home);
    },
    loading: () => cached == null ? const AsyncLoading() : AsyncData(cached),
    error: (error, stack) =>
        cached == null ? AsyncError(error, stack) : AsyncData(cached),
  );
});

final spanishFeaturedPackProvider = FutureProvider<PackModel?>((ref) async {
  try {
    return await ref
        .watch(packRepositoryProvider)
        .fetchPacks(kSpanishFeaturedPackId);
  } catch (e) {
    AppLogger.w('Home', 'Spanish featured pack unavailable: $e');
    return null;
  }
});

/// Optional enrichment updates the carousel without delaying the base feed.
final homeContentProvider = Provider<AsyncValue<HomeModel>>((ref) {
  final home = ref.watch(homeFeedProvider);
  final prefersSpanish = ref
      .watch(deviceLocalesProvider)
      .any((locale) => locale.languageCode.toLowerCase() == 'es');
  if (!prefersSpanish || !home.hasValue) return home;
  final data = home.requireValue;
  if (data.carousel.any(
    (item) =>
        item.id == kSpanishFeaturedPackId ||
        item.path?.split('/').last == kSpanishFeaturedPackId,
  )) {
    return home;
  }
  final pack = ref.watch(spanishFeaturedPackProvider).value;
  if (pack == null) return home;
  return AsyncData(
    data.copyWith(
      carousel: [
        HomeCarouselModel(
          id: pack.id,
          title: pack.title,
          subtitle: pack.subtitle ?? '',
          coverUrl: pack.coverUrl ?? '',
          path: pack.path ?? 'packs/${pack.id}',
          type: TypeConstants.pack,
        ),
        ...data.carousel,
      ],
    ),
  );
});

@riverpod
Future<void> refreshHomeAPIs(Ref ref) async {
  ref.invalidate(fetchHomeProvider);
  await ref.read(fetchHomeProvider.future);
}
