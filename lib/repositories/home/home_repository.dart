import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_repository.g.dart';

abstract class HomeRepository {
  Future<HomeModel> fetchHomeData();
  Future<HomeHeaderModel> fetchHomeHeader();
  Future<QuoteModel> fetchQuote();
  Future<ShortcutsModel> fetchShortcuts();
}

class HomeRepositoryImpl extends HomeRepository {
  final DioApiService client;

  HomeRepositoryImpl({required this.client});

  @override
  Future<HomeModel> fetchHomeData() async {
    try {
      var res = await client.getRequest(HTTPConstants.HOME);

      return HomeModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }

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

      return ShortcutsModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
HomeRepositoryImpl homeRepository(ref) {
  return HomeRepositoryImpl(client: ref.watch(dioClientProvider));
}
