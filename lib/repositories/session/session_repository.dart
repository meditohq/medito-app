import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_services.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_repository.g.dart';

abstract class SessionRepository {
  Future<SessionModel> fetchSession(int sessionId);
}

class SessionRepositoryImpl extends SessionRepository {
  final DioApiService client;

  SessionRepositoryImpl({required this.client});

  @override
  Future<SessionModel> fetchSession(int sessionId) async {
    try {
      var res = await client.getRequest('${HTTPConstants.SESSIONS}/$sessionId');

      return SessionModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
SessionRepository sessionRepository(SessionRepositoryRef ref) {
  return SessionRepositoryImpl(client: ref.watch(dioClientProvider));
}
