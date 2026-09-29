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
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  final home = await homeRepository.fetchHome();
  return _withSpanishFeaturedPack(ref, home);
}

/// Prepends [kSpanishFeaturedPackId] to `home.carousel` when the device
/// prefers Spanish. The card is built from the live pack (title/cover stay
/// in sync with the CMS); if the fetch fails the network carousel is returned
/// untouched so a missing pack never breaks the home screen.
Future<HomeModel> _withSpanishFeaturedPack(Ref ref, HomeModel home) async {
  final prefersSpanish = ref
      .read(deviceLocalesProvider)
      .any((locale) => locale.languageCode.toLowerCase() == 'es');
  if (!prefersSpanish) return home;

  final alreadyFeatured = home.carousel.any(
    (item) => item.id == kSpanishFeaturedPackId ||
        item.path?.split('/').last == kSpanishFeaturedPackId,
  );
  if (alreadyFeatured) return home;

  final PackModel pack;
  try {
    pack = await ref
        .read(packRepositoryProvider)
        .fetchPacks(kSpanishFeaturedPackId);
  } catch (e) {
    AppLogger.w('Home', 'Spanish featured pack unavailable: $e');
    return home;
  }

  final card = HomeCarouselModel(
    id: pack.id,
    title: pack.title,
    subtitle: pack.subtitle ?? '',
    coverUrl: pack.coverUrl ?? '',
    path: pack.path ?? 'packs/${pack.id}',
    type: TypeConstants.pack,
  );
  return home.copyWith(carousel: [card, ...home.carousel]);
}

@riverpod
Future<void> refreshHomeAPIs(Ref ref) async {
  ref.invalidate(fetchHomeProvider);
  await ref.read(fetchHomeProvider.future);
}
