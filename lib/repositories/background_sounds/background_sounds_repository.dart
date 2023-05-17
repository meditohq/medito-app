import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'background_sounds_repository.g.dart';

abstract class BackgroundSoundsRepository {
  Future<List<BackgroundSoundsModel>> fetchBackgroundSounds();
}

class BackgroundSoundsRepositoryImpl extends BackgroundSoundsRepository {
  final DioApiService client;

  BackgroundSoundsRepositoryImpl({required this.client});

  @override
  Future<List<BackgroundSoundsModel>> fetchBackgroundSounds() async {
    try {
      var res = await client.getRequest(HTTPConstants.BACKGROUND_SOUNDS);
      var tempResponse = res as List;

      return tempResponse
          .map((x) => BackgroundSoundsModel.fromJson(x))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
BackgroundSoundsRepositoryImpl backgroundSoundsRepository(
  BackgroundSoundsRepositoryRef ref,
) {
  return BackgroundSoundsRepositoryImpl(client: ref.watch(dioClientProvider));
}
