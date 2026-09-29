import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/providers/network/http_api_service_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:medito/services/stats_backup_service.dart';
import 'package:medito/utils/completed_tracks_storage.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dev = const AppLoggerAdapter('ACCOUNT_SERVICE');

/// Reason codes sent with `DELETE me`. The server stores them as-is (max 64
/// chars), so keep these stable — they're what the deletion log is grouped by.
enum DeleteAccountReason {
  notUsing('not_using'),
  privacy('privacy'),
  switchingApp('switching_app'),
  technicalIssues('technical_issues'),
  tooManyNotifications('too_many_notifications'),
  other('other');

  const DeleteAccountReason(this.code);

  final String code;
}

/// Account-scoped local data wiped after a deletion. Device preferences
/// (theme, reminders, downloads, onboarding) are kept.
const _accountPrefKeys = [
  SharedPreferenceConstants.userId,
  SharedPreferenceConstants.userEmail,
  SecureStorageService.userEmailPrefsKey,
  SharedPreferenceConstants.favorites,
  SharedPreferenceConstants.removedFavorites,
  SharedPreferenceConstants.favoritePacks,
  SharedPreferenceConstants.consistencyScoreHistory,
  SharedPreferenceConstants.emailAddressForReceipt,
  SharedPreferenceConstants.lastSuccessfulDonationAtMs,
  SharedPreferenceConstants.lastSuccessfulDonationFrequency,
  SharedPreferenceConstants.signedInUserHistory,
  SharedPreferenceConstants.upNextPackId,
  SharedPreferenceConstants.upNextReturnPackId,
  SharedPreferenceConstants.incompleteAudioSession,
  // Track completions still waiting to be posted as stats.
  CompletedTracksStorage.completedTracksKey,
  // Legacy keys no current code writes: the v3.x plaintext API token and the
  // monthly-donor flag mirrored from /me until 265e12b7.
  'userToken',
  'has_active_subscription',
];

/// The deletion request never got a definite answer (network dropped or
/// timed out, even after retries), so the account may or may not be gone.
class AccountDeletionUnconfirmed implements Exception {
  const AccountDeletionUnconfirmed(this.cause);

  final Object cause;

  @override
  String toString() => 'AccountDeletionUnconfirmed($cause)';
}

class AccountService {
  final HttpApiService _httpApiService;
  final AuthRepository _authRepository;
  final SharedPreferences _preferences;
  final StatsManager _statsManager;

  /// Base delay between DELETE retries (multiplied by the attempt number).
  final Duration retryDelay;

  AccountService({
    required HttpApiService httpApiService,
    required AuthRepository authRepository,
    required SharedPreferences preferences,
    required StatsManager statsManager,
    this.retryDelay = const Duration(seconds: 1),
  }) : _httpApiService = httpApiService,
       _authRepository = authRepository,
       _preferences = preferences,
       _statsManager = statsManager;

  /// Deletes the account server-side, then signs out and wipes local data.
  ///
  /// Throws if the server didn't confirm the deletion; the user stays signed
  /// in and can retry (the endpoint is idempotent). Throws
  /// [AccountDeletionUnconfirmed] when no definite answer arrived.
  Future<void> deleteAccount({
    DeleteAccountReason? reason,
    String? details,
  }) async {
    final trimmedDetails = details?.trim();
    final body = <String, dynamic>{
      if (reason != null) 'reason': reason.code,
      if (trimmedDetails != null && trimmedDetails.isNotEmpty)
        'details': trimmedDetails,
    };

    final response = await _deleteWithRetry(body.isEmpty ? null : body);
    if (response['deleted'] != true) {
      throw Exception('Account deletion was not confirmed');
    }
    dev.log('[ACCOUNT_SERVICE] Account deleted', level: 500);

    await _clearLocalAccount();
  }

  /// DELETE me is idempotent (an already-deleted account still gets 200), so
  /// a lost or timed-out response is retried rather than reported as a
  /// failure. A 5xx is a definite failure: the user stays signed in.
  Future<Map<String, dynamic>> _deleteWithRetry(
    Map<String, dynamic>? body,
  ) async {
    const attempts = 3;
    for (var attempt = 1; ; attempt++) {
      try {
        return await _httpApiService.deleteRequest(
          HTTPConstants.me,
          body: body,
        );
      } on ServerError {
        rethrow;
      } on AppError catch (e) {
        final transient =
            e is NetworkConnectionError ||
            e is TimeoutError ||
            e is UnknownError;
        if (!transient) rethrow;
        if (attempt >= attempts) throw AccountDeletionUnconfirmed(e);
        dev.log(
          '[ACCOUNT_SERVICE] Delete attempt $attempt failed ($e), retrying',
          level: 800,
        );
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  /// The access token stays valid for up to 2 hours after deletion and any
  /// authenticated call would recreate a profile, so drop it before anything
  /// else can fire. The server session is already gone, so no tokens/signout.
  Future<void> _clearLocalAccount() async {
    _httpApiService.clearAuthHeader();
    await _authRepository.signOutLocally();
    await _statsManager.clearAllStats();
    await StatsBackupService(prefs: _preferences).clearAll();
    for (final key in _accountPrefKeys) {
      await _preferences.remove(key);
    }
  }
}

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(
    httpApiService: ref.watch(httpApiServiceProvider),
    authRepository: ref.watch(authRepositorySyncProvider),
    preferences: ref.watch(sharedPreferencesProvider),
    statsManager: ref.watch(statsManagerProvider),
  );
});
