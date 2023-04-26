import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<String> sendOTP(String email);
  Future<String> verifyOTP(String email, String OTP);
}

class AuthRepositoryImpl extends AuthRepository {
  final DioApiService client;

  AuthRepositoryImpl({required this.client});

  @override
  Future<String> sendOTP(String email) async {
    try {
      var res = await client
          .postRequest('${HTTPConstants.OTP}', data: {'email': email});
      print(res);

      return 'null';
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> verifyOTP(String email, String OTP) async {
    try {
      var res = await client.postRequest('${HTTPConstants.OTP}/$OTP', data: {'email': email});
      print(res);

      return 'null';
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
AuthRepository authRepository(ref) {
  return AuthRepositoryImpl(client: ref.watch(dioClientProvider));
}
