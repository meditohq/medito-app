import 'dart:io';

import 'package:flutter/services.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/analytics/install_source_utms.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records, once per Android install, where the Play Store says the install
/// came from. GA4 reads the same referrer for its own traffic source, but the
/// app never kept it, so Stripe donations from Google/Meta ad installs had no
/// source and lifetime value per channel couldn't be measured.
///
/// The referrer is stored as the UTM prefs deep links set (see
/// [storeInstallSourceUtms]). Native side: InstallReferrer.kt.
class PlayInstallReferrerService {
  PlayInstallReferrerService({bool? isAndroid})
    : _isAndroid = isAndroid ?? Platform.isAndroid;

  final bool _isAndroid;

  static const channel = MethodChannel('com.medito.app/install_referrer');

  /// Google Ads app-campaign referrers often carry only a click ID.
  static const _googleClickIds = {'gclid', 'gbraid', 'wbraid'};

  /// Meta's utm_content is an encrypted JSON blob far past GA4's user
  /// property limit and useless without Meta's key; values this long are
  /// dropped.
  static const _maxValueLength = 100;

  static const _utmKeys = [
    SharedPreferenceConstants.utmSource,
    SharedPreferenceConstants.utmMedium,
    SharedPreferenceConstants.utmCampaign,
    SharedPreferenceConstants.utmTerm,
    SharedPreferenceConstants.utmContent,
  ];

  /// Safe to call on every launch: it does nothing once the referrer has been
  /// read. If Play's service is unavailable it tries again next launch.
  Future<void> attributeOnce() async {
    if (!_isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(SharedPreferenceConstants.playInstallReferrerChecked) ??
          false) {
        return;
      }

      final referrer = await channel.invokeMethod<String>('getReferrer');
      if (referrer == null) return;

      await prefs.setBool(
        SharedPreferenceConstants.playInstallReferrerChecked,
        true,
      );
      final utms = utmsFromReferrer(referrer);
      if (utms.isNotEmpty) await storeInstallSourceUtms(prefs, utms);
    } catch (e) {
      AppLogger.w('INSTALL_REFERRER', 'Install referrer lookup failed: $e');
    }
  }

  static Map<String, String> utmsFromReferrer(String referrer) {
    final Map<String, String> params;
    try {
      params = Uri.splitQueryString(referrer);
    } on ArgumentError {
      // Bad percent-encoding.
      return {};
    }

    if (params[SharedPreferenceConstants.utmSource]?.isNotEmpty ?? false) {
      return {
        for (final key in _utmKeys)
          if (params[key] case final value?
              when value.isNotEmpty && value.length <= _maxValueLength)
            key: value,
      };
    }
    if (params.keys.any(_googleClickIds.contains)) {
      return {
        SharedPreferenceConstants.utmSource: 'google',
        SharedPreferenceConstants.utmMedium: 'cpc',
      };
    }

    return {};
  }
}
