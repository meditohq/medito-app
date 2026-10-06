import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AnalyticsEventLogger =
    Future<void> Function(String name, Map<String, Object> parameters);

/// Works out, once per iOS install, whether the install came from an Apple
/// Ads campaign. GA4 can't see Apple Ads installs on its own: they land in
/// "(direct)", and only the few that open through a tagged deep link carry
/// UTMs.
///
/// The native side (AppDelegate.swift) hands over an AdServices token, which
/// is exchanged with Apple's attribution API. Neither step needs ATT consent.
/// Attributed installs are stored as the same UTMs the Apple Ads deep links
/// use, so GA4 user properties, Meta events and Stripe metadata pick them up
/// without changes.
class AppleAdsAttributionService {
  AppleAdsAttributionService({
    http.Client? client,
    AnalyticsEventLogger? logEvent,
    bool? isIOS,
    this.retryDelay = const Duration(seconds: 5),
  }) : _client = client ?? http.Client(),
       _logEvent = logEvent ?? _logToFirebase,
       _isIOS = isIOS ?? Platform.isIOS;

  final http.Client _client;
  final AnalyticsEventLogger _logEvent;
  final bool _isIOS;

  /// Apple asks for up to three retries, 5s apart, on a 404 (the record isn't
  /// ready yet right after install).
  final Duration retryDelay;
  static const _maxAttempts = 4;

  static const channel = MethodChannel('com.medito.app/adservices');
  static final _endpoint = Uri.parse(
    'https://api-adservices.apple.com/api/v1/',
  );
  static const _timeout = Duration(seconds: 10);

  /// Development and TestFlight builds get a sample payload with these IDs.
  static const _samplePayloadId = 1234567890;

  static const utmSource = 'apple-search';
  static const utmMedium = 'asa';

  /// Safe to call on every launch: it does nothing once Apple has answered.
  /// Failures (no network, Apple 5xx) leave it to retry on the next launch;
  /// the token stays valid for 24 hours and attribution for 30 days.
  Future<void> attributeOnce() async {
    if (!_isIOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(SharedPreferenceConstants.appleAdsAttributionChecked) ??
          false) {
        return;
      }

      final token = await channel.invokeMethod<String>('attributionToken');
      if (token == null || token.isEmpty) return;

      final payload = await _fetchAttribution(token);
      if (payload == null) return;

      await prefs.setBool(
        SharedPreferenceConstants.appleAdsAttributionChecked,
        true,
      );
      await _record(prefs, payload);
    } catch (e) {
      AppLogger.w('APPLE_ADS', 'Attribution lookup failed: $e');
    }
  }

  /// The attribution payload, `{}` when Apple rejects the token for good, or
  /// null when it's worth trying again next launch.
  Future<Map<String, dynamic>?> _fetchAttribution(String token) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final response = await _client
          .post(_endpoint, headers: {'Content-Type': 'text/plain'}, body: token)
          .timeout(_timeout);

      switch (response.statusCode) {
        case 200:
          return jsonDecode(response.body) as Map<String, dynamic>;
        case 404 when attempt < _maxAttempts:
          await Future<void>.delayed(retryDelay);
        case 400:
          AppLogger.w('APPLE_ADS', 'AdServices rejected the token');
          return {};
        default:
          AppLogger.w(
            'APPLE_ADS',
            'AdServices returned ${response.statusCode}',
          );
          return null;
      }
    }
    return null;
  }

  Future<void> _record(
    SharedPreferences prefs,
    Map<String, dynamic> payload,
  ) async {
    if (payload.isEmpty) return;
    if (payload['campaignId'] == _samplePayloadId) {
      AppLogger.d('APPLE_ADS', 'Ignoring sample payload (non-App Store build)');
      return;
    }

    final attributed = payload['attribution'] == true;
    await _logEvent(AnalyticsEventConstants.appleAdsAttribution, {
      'attributed': '$attributed',
      if (attributed) ...{
        for (final MapEntry(:key, :value) in const {
          'campaign_id': 'campaignId',
          'ad_group_id': 'adGroupId',
          'keyword_id': 'keywordId',
          'claim_type': 'claimType',
          'conversion_type': 'conversionType',
          'country_or_region': 'countryOrRegion',
        }.entries)
          if (payload[value] != null) key: '${payload[value]}',
      },
    });
    if (!attributed) return;

    // A tagged deep link is more specific (named campaign), so keep its UTMs.
    if (prefs.getString(SharedPreferenceConstants.utmSource) != null) return;
    final utms = {
      SharedPreferenceConstants.utmSource: utmSource,
      SharedPreferenceConstants.utmMedium: utmMedium,
      SharedPreferenceConstants.utmCampaign: payload['campaignId'],
      SharedPreferenceConstants.utmContent: payload['adGroupId'],
      SharedPreferenceConstants.utmTerm: payload['keywordId'],
    };
    for (final MapEntry(:key, :value) in utms.entries) {
      if (value != null) await prefs.setString(key, '$value');
    }
    await FirebaseAnalyticsService.applyStoredUtmParameters();
  }

  static Future<void> _logToFirebase(
    String name,
    Map<String, Object> parameters,
  ) => FirebaseAnalyticsService().logEvent(name: name, parameters: parameters);
}
