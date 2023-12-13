import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_repository.g.dart';

abstract class HomeRepository {
  Future<HomeHeaderModel> fetchHomeHeader();

  Future<QuoteModel> fetchQuote();

  Future<ShortcutsModel> fetchShortcuts();

  List<String> getLocalShortcutIds();

  ShortcutsModel getSortedShortcuts(
    ShortcutsModel shortcutsModel,
  );

  Future<void> setShortcutIdsInPreference(
    List<String> ids,
  );
}

class HomeRepositoryImpl extends HomeRepository {
  final DioApiService client;
  final Ref ref;

  HomeRepositoryImpl({required this.ref, required this.client});

  @override
  Future<HomeHeaderModel> fetchHomeHeader() async {
    try {
      var response = await client.getRequest(HTTPConstants.HEADER);

      return HomeHeaderModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<QuoteModel> fetchQuote() async {
    try {
      var response = await client.getRequest(HTTPConstants.QUOTE);

      return QuoteModel.fromJson(response['quote']);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ShortcutsModel> fetchShortcuts() async {
    try {
      var response = await client.getRequest(HTTPConstants.SHORTCUTS);

      var parsedShortcuts = ShortcutsModel.fromJson(response);

      return getSortedShortcuts(parsedShortcuts);
    } catch (e) {
      rethrow;
    }
  }

  @override
  List<String> getLocalShortcutIds() {
    return ref
            .read(sharedPreferencesProvider)
            .getStringList(SharedPreferenceConstants.shortcuts) ??
        [];
  }

  @override
  ShortcutsModel getSortedShortcuts(
    ShortcutsModel shortcutsModel,
  ) {
    var shortcutsIds = getLocalShortcutIds();
    var shortcutsCopy = [...shortcutsModel.shortcuts];

    shortcutsCopy.sort((a, b) =>
        shortcutsIds.indexOf(a.id).compareTo(shortcutsIds.indexOf(b.id)));

    return shortcutsModel.copyWith(shortcuts: shortcutsCopy);
  }

  @override
  Future<void> setShortcutIdsInPreference(List<String> ids) async {
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(SharedPreferenceConstants.shortcuts, ids);
  }
}

@riverpod
HomeRepositoryImpl homeRepository(HomeRepositoryRef ref) {
  return HomeRepositoryImpl(ref: ref, client: ref.watch(dioClientProvider));
}
