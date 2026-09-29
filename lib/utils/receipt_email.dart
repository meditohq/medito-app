import 'package:shared_preferences/shared_preferences.dart';

import '../constants/strings/shared_preference_constants.dart';

/// The email a donor typed for their receipt in a native donation flow
/// (end-screen inline card, onboarding native page). It goes to Stripe, not
/// to the account, so the install stays anonymous; keeping it lets the
/// sign-up screen prefill "add your email" instead of asking again.
///
/// Stored at submit time (not on success) so an abandoned card step still
/// saves the retype. Never treated as the account email.
class ReceiptEmail {
  ReceiptEmail._();

  static Future<void> save(SharedPreferences prefs, String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    await prefs.setString(
      SharedPreferenceConstants.emailAddressForReceipt,
      trimmed,
    );
  }

  static String? read(SharedPreferences prefs) {
    final value = prefs.getString(
      SharedPreferenceConstants.emailAddressForReceipt,
    );
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }
}
