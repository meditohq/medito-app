import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/dio_auth_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<UserTokenModel> generateUserToken([String? email]);

  Future<void> addUserInSharedPreference(UserTokenModel user);

  Future<String?> getClientIdFromSharedPreference();

  String? getEmailFromSharedPreference();

  String? getToken();

  Future<String> initializeUser();
}

class AuthRepositoryImpl extends AuthRepository {
  final DioAuthApiService client;
  final Ref ref;

  AuthRepositoryImpl({required this.ref, required this.client});

  @override
  Future<String> initializeUser() async {
    var token = getToken();

    if (token == null) {
      const maxRetries = 3;
      var retries = 0;
      UserTokenModel? user;

      while (retries < maxRetries) {
        user = await generateUserToken();
        if (user.token != null) {
          return user.token!;
        }
        retries++;
      }

      throw Exception('Failed to generate token after $maxRetries attempts');
    } else {
      return token;
    }
  }

  @override
  Future<UserTokenModel> generateUserToken([
    String? email,
  ]) async {
    var clientId = await getClientIdFromSharedPreference();

    clientId ??= const Uuid().v4();

    var response = await client.postRequest(
      HTTPConstants.TOKENS,
      data: {
        'clientId': clientId,
        'email': email,
      },
    );

    var user = UserTokenModel.fromJson(response).copyWith(clientId: clientId);
    await addUserInSharedPreference(user);

    return user;
  }

  @override
  Future<void> addUserInSharedPreference(UserTokenModel user) async {
    var prefs = ref.read(sharedPreferencesProvider);
    if (user.clientId != null) {
      await prefs.setString(SharedPreferenceConstants.userId, user.clientId!);
    }
    if (user.email != null) {
      await prefs.setString(SharedPreferenceConstants.userEmail, user.email!);
    }
    if (user.token != null) {
      await prefs.setString(SharedPreferenceConstants.userToken, user.token!);
    }
  }

  @override
  Future<String?> getClientIdFromSharedPreference() async {
    var prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(SharedPreferenceConstants.userId);
  }

  @override
  String? getEmailFromSharedPreference() {
    var prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(SharedPreferenceConstants.userEmail);
  }

  @override
  String? getToken() {
    var prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(SharedPreferenceConstants.userToken);
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(ref: ref, client: DioAuthApiService());
}
