import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:developer' as dev;

import '../../models/me/me_model.dart';
import '../../repositories/me/me_repository.dart';
import '../../repositories/auth/auth_repository.dart';

part 'me_provider.g.dart';

@Riverpod(keepAlive: true)
Future<MeModel> me(Ref ref) async {
  dev.log('[ME_PROVIDER] me provider called', level: 500);

  // First check authentication state
  String? token;
  try {
    final authRepo = ref.read(authRepositorySyncProvider);
    final currentUser = authRepo.currentUser;
    dev.log('[ME_PROVIDER] Current auth user: $currentUser', level: 500);

    // Check if user has email, which indicates logged in status
    final email = authRepo.getUserEmail();
    dev.log('[ME_PROVIDER] User email from auth: $email', level: 500);

    // If no email, the user is likely not authenticated, return anonymous user
    if (email == null || email.isEmpty) {
      dev.log('[ME_PROVIDER] No email found, user likely not authenticated',
          level: 500);
      // Return anonymous user model
      return MeModel(
          id: currentUser?.id ?? '', email: null, hasActiveSubscription: false);
    }

    // Try to refresh the token to ensure we have valid credentials
    try {
      token = await authRepo.getToken();
      dev.log('[ME_PROVIDER] Retrieved valid token', level: 500);
    } catch (e) {
      dev.log('[ME_PROVIDER] Failed to get token: $e', error: e, level: 500);
      // If token refresh fails but we have a user with email, return that basic info
      if (currentUser != null && currentUser.email != null) {
        dev.log('[ME_PROVIDER] Using cached user data due to token error',
            level: 500);
        return MeModel(
          id: currentUser.id,
          email: currentUser.email,
          hasActiveSubscription: false,
        );
      }
      rethrow; // No valid data available, must propagate the error
    }
  } catch (e) {
    dev.log('[ME_PROVIDER] Error checking auth state: $e',
        error: e, level: 500);
    rethrow;
  }

  // Since we have a valid token, proceed to fetch ME data
  var repo = ref.read(meRepositoryProvider);
  dev.log('[ME_PROVIDER] Got repository instance', level: 500);

  try {
    final meData = await repo.fetchMe();
    dev.log('[ME_PROVIDER] Fetched me data successfully: $meData', level: 500);
    return meData;
  } catch (e) {
    dev.log('[ME_PROVIDER] Error fetching me data: $e', error: e, level: 500);
    rethrow;
  }
}

/// Provider to refresh the me provider
final meRefreshProvider = Provider<void Function()>((ref) {
  return () {
    dev.log('[ME_PROVIDER] invalidating me provider', level: 1000);
    ref.invalidate(meProvider);
    dev.log('[ME_PROVIDER] me provider invalidated', level: 1000);
  };
});
