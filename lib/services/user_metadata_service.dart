import 'package:supabase_flutter/supabase_flutter.dart';

class UserMetadataService {
  static const _clientIdKey = 'client_id';

  Future<void> storeClientId(String clientId) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {_clientIdKey: clientId},
      ),
    );
  }

  Future<String?> getClientId() async {
    return Supabase.instance.client.auth.currentUser?.userMetadata?[_clientIdKey];
  }

  Future<void> clearClientId() async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {_clientIdKey: null},
      ),
    );
  }
} 