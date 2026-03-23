import 'package:medito/constants/constants.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/models/models.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_repository.g.dart';

abstract class HomeRepository {
  Future<HomeModel> fetchHome();

  Future<AnnouncementModel?> fetchLatestAnnouncement();
}

class HomeRepositoryImpl extends HomeRepository {
  final HttpApiService client;
  final Ref ref;

  HomeRepositoryImpl({required this.ref, required this.client});

  @override
  Future<HomeModel> fetchHome() async {
    print('[HOME_REPO] Fetching home...');
    var response = await client.getRequest(HTTPConstants.home);
    print('[HOME_REPO] Got response, parsing...');
    final model = HomeModel.fromJson(response);
    print('[HOME_REPO] Parsed successfully');
    return model;
  }

  @override
  Future<AnnouncementModel?> fetchLatestAnnouncement() async {
    var response = await client.getRequest(HTTPConstants.latestAnnouncement);

    return AnnouncementModel.fromJson(response);
  }
}

@riverpod
HomeRepositoryImpl homeRepository(Ref ref) {
  return HomeRepositoryImpl(ref: ref, client: HttpApiService());
}
