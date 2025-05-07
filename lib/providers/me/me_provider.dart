import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:developer' as dev;

import '../../models/me/me_model.dart';
import '../../repositories/me/me_repository.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../constants/strings/shared_preference_constants.dart';
import '../shared_preferences_provider.dart';

part 'me_provider.g.dart';

@Riverpod(keepAlive: true)
Future<MeModel> me(Ref ref) async {
  dev.log('[ME_PROVIDER] me provider called', level: 500);
  try {
    final authRepo = ref.read(authRepositorySyncProvider);
    final currentUser = authRepo.currentUser;
    dev.log('[ME_PROVIDER] Current auth user: $currentUser', level: 500);

    // Try to refresh the token to ensure we have valid credentials
    try {
      await authRepo.getToken();
      dev.log('[ME_PROVIDER] Retrieved valid token', level: 500);

      // Since we have a valid token, try to fetch ME data first
      var repo = ref.read(meRepositoryProvider);
      dev.log('[ME_PROVIDER] Got repository instance', level: 500);

      try {
        final meData = await repo.fetchMe();
        dev.log('[ME_PROVIDER] Fetched me data successfully: $meData',
            level: 500);

        // If we got data from /me endpoint, ensure it's stored
        if (meData.email != null && meData.email!.isNotEmpty) {
          await authRepo.migrateEmailToStorage();
        }

        final prefs = await ref.read(sharedPreferencesProvider.future);
        await prefs.setBool(
          SharedPreferenceConstants.hasActiveSubscription,
          meData.hasActiveSubscription,
        );

        return meData;
      } catch (e) {
        dev.log('[ME_PROVIDER] Error fetching me data: $e',
            error: e, level: 500);
        // Fall through to check local state
      }
    } catch (e) {
      dev.log('[ME_PROVIDER] Failed to get token: $e', error: e, level: 500);
      // If token refresh fails but we have a user with email, return that basic info
      if (currentUser != null && currentUser.email != null) {
        dev.log('[ME_PROVIDER] Using cached user data due to token error',
            level: 500);
        final prefs = await ref.read(sharedPreferencesProvider.future);
        await prefs.setBool(
          SharedPreferenceConstants.hasActiveSubscription,
          false,
        );

        return MeModel(
          id: currentUser.id,
          email: currentUser.email,
          hasActiveSubscription: false,
        );
      }
      // Fall through to check local state
    }

    // Check if user has email locally as fallback
    final email = authRepo.getUserEmail();
    dev.log('[ME_PROVIDER] User email from auth: $email', level: 500);

    // If we have an email, ensure it's stored in secure storage
    if (email != null && email.isNotEmpty) {
      await authRepo.migrateEmailToStorage();
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setBool(
        SharedPreferenceConstants.hasActiveSubscription,
        false,
      );

      return MeModel(
        id: currentUser?.id ?? '',
        email: email,
        hasActiveSubscription: false,
      );
    }

    // If no email found anywhere, return anonymous user
    dev.log('[ME_PROVIDER] No email found, user likely not authenticated',
        level: 500);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(
      SharedPreferenceConstants.hasActiveSubscription,
      false,
    );

    return MeModel(
        id: currentUser?.id ?? '', email: null, hasActiveSubscription: false);
  } catch (e) {
    dev.log('[ME_PROVIDER] Error checking auth state: $e',
        error: e, level: 500);
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
