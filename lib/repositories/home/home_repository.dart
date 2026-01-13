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
    var response = await client.getRequest(HTTPConstants.home);

    return HomeModel.fromJson(response);
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
