import 'dart:developer' as dev;
import 'package:medito/exceptions/app_error.dart';
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
        throw const UnauthorizedError();
      }

      dev.log('Session refresh successful');
      updateAuthHeader('Bearer ${refreshedSession.session!.accessToken}');
    } on AuthException catch (e) {
      dev.log('Refresh failed: ${e.message}');
      await forceLogout();
      throw const UnauthorizedError();
    }
  }
}
