import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:medito/utils/logger.dart';

import '../../models/me/me_model.dart';
import '../../repositories/me/me_repository.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../constants/strings/shared_preference_constants.dart';
import '../shared_preference/shared_preference_provider.dart';

part 'me_provider.g.dart';

@Riverpod(keepAlive: true)
Future<MeModel> me(Ref ref) async {
  AppLogger.d('ME_PROVIDER', 'me provider called');
  try {
    final authRepo = ref.read(authRepositorySyncProvider);
    final currentUser = authRepo.currentUser;
    AppLogger.d('ME_PROVIDER', 'Current auth user: $currentUser');

    // Try to refresh the token to ensure we have valid credentials
    try {
      await authRepo.getToken();
      AppLogger.d('ME_PROVIDER', 'Retrieved valid token');

      // Since we have a valid token, try to fetch ME data first
      var repo = ref.read(meRepositoryProvider);
      AppLogger.d('ME_PROVIDER', 'Got repository instance');

      try {
        final meData = await repo.fetchMe();
        AppLogger.d('ME_PROVIDER', 'Fetched me data successfully: $meData');

        // If we got data from /me endpoint, ensure it's stored
        if (meData.email != null && meData.email!.isNotEmpty) {
          await authRepo.migrateEmailToStorage();
        }

        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setBool(
          SharedPreferenceConstants.hasActiveSubscription,
          meData.hasActiveSubscription,
        );

        return meData;
      } catch (e) {
        AppLogger.e('ME_PROVIDER', 'Error fetching me data', e);
        // Fall through to check local state
      }
    } catch (e) {
      AppLogger.e('ME_PROVIDER', 'Failed to get token', e);
      // If token refresh fails but we have a user with email, return that basic info
      if (currentUser != null && currentUser.email != null) {
        AppLogger.d('ME_PROVIDER', 'Using cached user data due to token error');
        final prefs = ref.read(sharedPreferencesProvider);
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
    AppLogger.d('ME_PROVIDER', 'User email from auth: $email');

    // If we have an email, ensure it's stored in secure storage
    if (email != null && email.isNotEmpty) {
      await authRepo.migrateEmailToStorage();
      final prefs = ref.read(sharedPreferencesProvider);
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
    AppLogger.d('ME_PROVIDER', 'No email found, user likely not authenticated');
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(
      SharedPreferenceConstants.hasActiveSubscription,
      false,
    );

    return MeModel(
        id: currentUser?.id ?? '', email: null, hasActiveSubscription: false);
  } catch (e) {
    AppLogger.e('ME_PROVIDER', 'Error checking auth state', e);
    rethrow;
  }
}

/// Provider to refresh the me provider
final meRefreshProvider = Provider<void Function()>((ref) {
  return () {
    AppLogger.d('ME_PROVIDER', 'invalidating me provider');
    ref.invalidate(meProvider);
    AppLogger.d('ME_PROVIDER', 'me provider invalidated');
  };
});
