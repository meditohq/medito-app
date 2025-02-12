import 'dart:developer' as dev;
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/exceptions/exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TokenRefreshHandler {
  const TokenRefreshHandler();

  Future<void> handleRefresh({
    required void Function(String) updateAuthHeader,
    required Future<void> Function() forceLogout,
  }) async {
    try {
      final refreshedSession =
          await Supabase.instance.client.auth.refreshSession();

      if (refreshedSession.session == null) {
        throw const AppHttpException(StringConstants.unauthorizedRequest);
      }

      dev.log('Session refresh successful');
      updateAuthHeader('Bearer ${refreshedSession.session!.accessToken}');
    } on AuthException catch (e) {
      dev.log('Refresh failed: ${e.message}');
      await forceLogout();
      throw const AppHttpException(StringConstants.unauthorizedRequest);
    }
  }
}
