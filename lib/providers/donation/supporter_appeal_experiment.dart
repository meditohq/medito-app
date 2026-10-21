import 'dart:convert';
import 'dart:math';

import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches authenticated server assignments and keeps campaign attribution
/// separate from acquisition and pricing experiments. Local enrollment exists
/// only for the isolated preview and tests; production pushes come from the server.
class SupporterAppealExperiment {
  SupporterAppealExperiment(this.prefs);

  final SharedPreferences prefs;
  static const enabled = bool.fromEnvironment(
    'SUPPORTER_APPEAL_ENABLED',
    defaultValue: true,
  );
  static const name = 'supporter_appeal_v1';
  static const campaign = 'support_medito_june_copy_v1';
  static const notificationId = 10103000;
  static const notificationTitle = '🫶 Your practice misses you 🫶';
  static const notificationBody =
      'Just a few minutes of stillness can change your whole day. Ready to breathe?';
  // June 8 appeal, with the historical date and unverified shortfall removed.
  static const announcementText =
      'We need your help to keep Medito free for everyone.\n\n'
      'Medito is a nonprofit; no ads, no paywalls. If it\'s been part of your '
      'life, a small monthly or yearly donation helps keep this space open for all.';
  static const assignmentKey = '${name}_assignment';
  static const dismissedKey = '${name}_dismissed';
  static const scheduledKey = '${name}_scheduled';
  static const shownKey = '${name}_shown';
  static const tapKey = '${name}_notification_tap';
  static const pendingOpenKey = 'supporter_campaign_pending_open';

  /// Campaign identity and queued events belong to the signed-in account.
  static Future<void> clearAccountState(SharedPreferences prefs) async {
    for (final key in [
      assignmentKey,
      dismissedKey,
      scheduledKey,
      shownKey,
      tapKey,
      pendingOpenKey,
      'supporter_campaign_registered',
    ]) {
      await prefs.remove(key);
    }
  }

  static const cardWindow = Duration(days: 7);
  static const attributionWindow = Duration(days: 7);
  static const measurementWindow = Duration(days: 90);
  static final _serverIdPattern = RegExp(
    r'^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$',
  );

  AppealAssignment? get assignment {
    final raw = prefs.getString(assignmentKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final arm = data['arm'];
      final at = data['at'];
      if (!['A', 'B', 'C'].contains(arm) || at is! int) return null;
      final nonce = data['nonce'];
      final serverId = data['server_id'];
      final isServer = serverId is String;
      if (isServer &&
          (!_serverIdPattern.hasMatch(serverId) ||
              data['user_id'] is! String ||
              data['user_id'] !=
                  prefs.getString(SharedPreferenceConstants.userId) ||
              prefs.getBool(SharedPreferenceConstants.isLoggedIn) == false)) {
        return null;
      }
      if (!isServer &&
          (nonce is! String || !RegExp(r'^[a-f0-9]{16}$').hasMatch(nonce))) {
        return null;
      }
      return AppealAssignment(
        arm: arm as String,
        at: DateTime.fromMillisecondsSinceEpoch(at),
        consistency: data['consistency'] as String,
        notificationsAllowed: data['notifications_allowed'] == true,
        nonce: nonce is String ? nonce : '',
        serverId: isServer ? serverId : null,
        campaignId: data['campaign_id'] as String? ?? campaign,
        announcement: data['announcement'] as String? ?? announcementText,
        ctaTitle: data['cta_title'] as String? ?? 'Donate now',
        expiresAt: data['expires_at'] is int
            ? DateTime.fromMillisecondsSinceEpoch(data['expires_at'] as int)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Accept only the authenticated app backend's assignment. Device preview
  /// enrollment remains separate; normal builds never randomize locally.
  Future<bool> applyServerAssignment(
    Map<String, dynamic> data, {
    required String userId,
  }) async {
    // Capture this ID before the request, not when its response arrives.
    if (userId.isEmpty ||
        userId != prefs.getString(SharedPreferenceConstants.userId) ||
        prefs.getBool(SharedPreferenceConstants.isLoggedIn) == false) {
      return false;
    }
    final id = data['id'], arm = data['arm'], at = data['assigned_at'];
    final end = data['expires_at'], campaignId = data['campaign_id'];
    if (id is! String ||
        !_serverIdPattern.hasMatch(id) ||
        !['A', 'B', 'C'].contains(arm) ||
        at is! int ||
        end is! int ||
        end <= at ||
        end - at > cardWindow.inMilliseconds ||
        campaignId is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]{2,79}$').hasMatch(campaignId) ||
        data['announcement'] is! String ||
        data['cta_title'] is! String) {
      return false;
    }
    if (assignment?.id != id) {
      for (final key in [dismissedKey, shownKey, scheduledKey, tapKey]) {
        await prefs.remove(key);
      }
    }
    await prefs.setString(
      assignmentKey,
      jsonEncode({
        'server_id': id,
        'user_id': userId,
        'campaign_id': campaignId,
        'arm': arm,
        'at': at,
        'expires_at': end,
        'consistency': data['consistency_band'] as String? ?? 'unknown',
        'notifications_allowed': data['notification_eligible'] == true,
        'announcement': data['announcement'],
        'cta_title': data['cta_title'],
      }),
    );
    return true;
  }

  bool get suppressed =>
      (prefs.getBool(dismissedKey) ?? false) ||
      prefs.getInt(SharedPreferenceConstants.lastSuccessfulDonationAtMs) !=
          null;

  bool isSnoozed(DateTime now) =>
      (prefs.getInt(SharedPreferenceConstants.donationAskSnoozedUntilMs) ?? 0) >
      now.millisecondsSinceEpoch;

  bool eligible(LocalAllStats stats, DateTime now) {
    if (!enabled || suppressed || isSnoozed(now)) return false;
    final completions =
        stats.audioCompleted
            ?.where((s) => s.timestamp <= now.millisecondsSinceEpoch)
            .toList() ??
        [];
    // Session history supplies a conservative, locally available age. We do
    // not pretend an upgrade date is the original install date.
    if (completions.length < 3) return false;
    final first = completions.map((s) => s.timestamp).reduce(min);
    final last = completions.map((s) => s.timestamp).reduce(max);
    return now.difference(DateTime.fromMillisecondsSinceEpoch(first)) >=
            const Duration(days: 30) &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) <=
            const Duration(days: 30);
  }

  Future<AppealAssignment?> enroll({
    required LocalAllStats stats,
    required DateTime now,
    required bool notificationsAllowed,
    Random? random,
  }) async {
    final existing = assignment;
    if (existing != null) return existing;
    // Fail closed on corrupt state rather than re-randomising an existing user.
    if (prefs.containsKey(assignmentKey) || !eligible(stats, now)) return null;
    final result = AppealAssignment(
      arm: ['A', 'B', 'C'][(random ?? Random()).nextInt(3)],
      at: now,
      consistency: stats.consistencyScore < .25
          ? 'under_25'
          : stats.consistencyScore < .5
          ? '25_to_50'
          : '50_plus',
      notificationsAllowed: notificationsAllowed,
      nonce: List.generate(
        2,
        (_) =>
            Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
      ).join(),
    );
    await prefs.setString(
      assignmentKey,
      jsonEncode({
        'arm': result.arm,
        'at': now.millisecondsSinceEpoch,
        'consistency': result.consistency,
        'notifications_allowed': notificationsAllowed,
        'nonce': result.nonce,
      }),
    );
    return result;
  }

  bool showCard(DateTime now) {
    final a = assignment;
    return enabled &&
        a != null &&
        a.arm != 'A' &&
        !suppressed &&
        !isSnoozed(now) &&
        !now.isBefore(a.at) &&
        now.isBefore(a.expiresAt ?? a.at.add(cardWindow));
  }

  String notificationPayload(AppealAssignment a) => jsonEncode({
    'source': name,
    'campaign_id': a.campaignId,
    'variant_id': a.arm,
    'appeal_id': a.id,
  });

  /// Returns a deduplicated click record for cold and warm starts. Never
  /// counts a scheduled notification as delivered or opened.
  Future<Map<String, String>?> recordNotificationTap(
    Map<String, dynamic>? data,
    DateTime now,
  ) async {
    final a = assignment;
    if (!enabled ||
        a == null ||
        (a.isServer ? a.arm == 'A' : a.arm != 'C') ||
        data?['source'] != name ||
        data?['campaign_id'] != a.campaignId ||
        data?['variant_id'] != a.arm ||
        data?['appeal_id'] != a.id ||
        now.isBefore(a.at) ||
        !now.isBefore(a.expiresAt ?? a.at.add(cardWindow)) ||
        prefs.containsKey(tapKey)) {
      return null;
    }
    final tap = {'id': a.id, 'at': now.millisecondsSinceEpoch};
    await prefs.setString(tapKey, jsonEncode(tap));
    return paymentMetadata(now: now);
  }

  Map<String, String> paymentMetadata({DateTime? now}) {
    final a = assignment;
    final at = now ?? DateTime.now();
    if (a == null ||
        at.isBefore(a.at) ||
        at.difference(a.at) > measurementWindow) {
      return {};
    }
    final result = <String, String>{
      name: a.arm,
      'appeal_id': a.id,
      'appeal_assigned_at': '${a.at.millisecondsSinceEpoch ~/ 1000}',
      'appeal_consistency': a.consistency,
      'appeal_notifications_allowed': a.notificationsAllowed ? 'true' : 'false',
      if (a.isServer) 'appeal_campaign_id': a.campaignId,
    };
    final raw = prefs.getString(tapKey);
    if (raw != null) {
      try {
        final tap = jsonDecode(raw) as Map<String, dynamic>;
        final tappedAt = DateTime.fromMillisecondsSinceEpoch(tap['at'] as int);
        if (tap['id'] == a.id &&
            !at.isBefore(tappedAt) &&
            at.difference(tappedAt) <= attributionWindow) {
          result.addAll({
            'appeal_notification_click_id': tap['id'] as String,
            'appeal_notification_tapped_at':
                '${tappedAt.millisecondsSinceEpoch ~/ 1000}',
          });
        }
      } catch (_) {
        /* Corrupt attribution must never break a payment. */
      }
    }
    return result;
  }

  /// Only the appeal CTA adds campaign UTMs. Acquisition UTMs stored by the
  /// app are never overwritten, and other donation entry points retain them.
  Map<String, String> ctaMetadata({DateTime? now}) => {
    'utm_source': 'medito_app',
    'utm_medium': 'in_app_announcement',
    'utm_campaign': assignment?.campaignId ?? campaign,
    'utm_content': assignment?.arm ?? 'unknown',
  };

  /// Preserve first-touch attribution alongside the CTA's campaign UTMs in
  /// the payment record, as well as leaving the stored acquisition untouched.
  Map<String, String> acquisitionMetadata() => {
    for (final key in [
      'utm_source',
      'utm_medium',
      'utm_campaign',
      'utm_content',
      'utm_term',
    ])
      if (prefs.getString(key) case final String value when value.isNotEmpty)
        'acquisition_$key': value,
  };
}

class AppealAssignment {
  const AppealAssignment({
    required this.arm,
    required this.at,
    required this.consistency,
    required this.notificationsAllowed,
    required this.nonce,
    this.serverId,
    this.campaignId = SupporterAppealExperiment.campaign,
    this.announcement = SupporterAppealExperiment.announcementText,
    this.ctaTitle = 'Donate now',
    this.expiresAt,
  });
  final String arm;
  final DateTime at;
  final String consistency;
  final bool notificationsAllowed;
  final String nonce;
  final String? serverId;
  final String campaignId;
  final String announcement;
  final String ctaTitle;
  final DateTime? expiresAt;
  bool get isServer => serverId != null;
  String get id => serverId ?? '${SupporterAppealExperiment.name}_$nonce';
}
