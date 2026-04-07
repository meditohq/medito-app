import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:intl/intl.dart';
import 'package:medito/providers/locale_provider.dart';

import '../../models/device_info/device_and_app_info_model.dart';
import '../../models/me/me_model.dart';
import '../me/me_provider.dart';

part 'device_and_app_info_provider.g.dart';

@riverpod
Future<DeviceAndAppInfoModel> deviceAndAppInfo(Ref ref) async {
  ref.keepAlive();

  var packageInfo = await PackageInfo.fromPlatform();
  var deviceInfo = await _getDeviceInfo();
  var localeInfo = _getLocaleInfo(ref);

  var data = <String, dynamic>{
    'model': deviceInfo.model,
    'os': deviceInfo.os,
    'platform': deviceInfo.platform,
    'buildNumber': packageInfo.buildNumber,
    'appVersion': packageInfo.version,
    'languageCode': localeInfo.languageCode,
    'currencyName': localeInfo.currencyName,
    'currency': localeInfo.currency,
    'country': localeInfo.country,
  };

  return DeviceAndAppInfoModel.fromJson(data);
}

class _LocaleInfo {
  final String languageCode;
  final String currencyName;
  final String? currency;
  final String? country;

  _LocaleInfo(
      this.languageCode, this.currencyName, this.currency, this.country);
}

_LocaleInfo _getLocaleInfo(Ref ref) {
  // Get the current locale from the locale provider (user's preference)
  final currentLocale = ref.watch(localeProvider);

  // Use the user's selected locale, fallback to system locale if not set
  var languageCode = currentLocale?.languageCode ??
      PlatformDispatcher.instance.locale.languageCode;
  var currencyName =
      NumberFormat.simpleCurrency(locale: languageCode).currencyName ?? '';

  // Get country code (ISO format like "US", "GB")
  var country = currentLocale?.countryCode ??
      PlatformDispatcher.instance.locale.countryCode;

  // Get currency code (ISO format like "usd", "eur")
  var currency = _getCurrencyCode(country);

  return _LocaleInfo(languageCode, currencyName, currency, country);
}

class _DeviceInfo {
  final String model;
  final String os;
  final String platform;

  _DeviceInfo(this.model, this.os, this.platform);
}

Future<_DeviceInfo> _getDeviceInfo() async {
  var deviceModel = '';
  var deviceOS = '';
  var devicePlatform = '';
  var deviceInfo = DeviceInfoPlugin();

  if (Platform.isIOS) {
    var iosInfo = await deviceInfo.iosInfo;
    deviceModel = iosInfo.utsname.machine;
    deviceOS = iosInfo.utsname.sysname;
    devicePlatform = 'iOS';
  } else if (Platform.isAndroid) {
    var androidInfo = await deviceInfo.androidInfo;
    deviceModel = androidInfo.model;
    deviceOS = androidInfo.version.release;
    devicePlatform = 'android';
  }

  return _DeviceInfo(deviceModel, deviceOS, devicePlatform);
}

String? _getCurrencyCode(String? countryCode) {
  if (countryCode == null) return null;

  // Basic mapping of country codes to currency codes
  final currencyMap = {
    'US': 'usd',
    'GB': 'gbp',
    'UK': 'gbp', // Alternative for UK
    'DE': 'eur',
    'FR': 'eur',
    'IT': 'eur',
    'ES': 'eur',
    'NL': 'eur',
    'BE': 'eur',
    'AT': 'eur',
    'PT': 'eur',
    'FI': 'eur',
    'IE': 'eur',
    'GR': 'eur',
    'LU': 'eur',
    'SI': 'eur',
    'MT': 'eur',
    'CY': 'eur',
    'SK': 'eur',
    'EE': 'eur',
    'LV': 'eur',
    'LT': 'eur',
    'HR': 'eur',
    'CA': 'cad',
    'AU': 'aud',
    'NZ': 'nzd',
    'JP': 'jpy',
    'CN': 'cny',
    'IN': 'inr',
    'BR': 'brl',
    'MX': 'mxn',
    'AR': 'ars',
    'CL': 'clp',
    'CO': 'cop',
    'PE': 'pen',
    'VE': 'ves',
    'UY': 'uyu',
    'PY': 'pyg',
    'BO': 'bob',
    'EC': 'usd', // Ecuador uses USD
    'ZA': 'zar',
    'EG': 'egp',
    'NG': 'ngn',
    'KE': 'kes',
    'GH': 'ghs',
    'MA': 'mad',
    'TN': 'tnd',
    'TR': 'try',
    'IL': 'ils',
    'SA': 'sar',
    'AE': 'aed',
    'QA': 'qar',
    'KW': 'kwd',
    'BH': 'bhd',
    'OM': 'omr',
    'JO': 'jod',
    'LB': 'lbp',
    'IQ': 'iqd',
    'SY': 'syp',
    'YE': 'yer',
    'IR': 'irr',
    'PK': 'pkr',
    'BD': 'bdt',
    'LK': 'lkr',
    'NP': 'npr',
    'MM': 'mmk',
    'TH': 'thb',
    'VN': 'vnd',
    'MY': 'myr',
    'SG': 'sgd',
    'ID': 'idr',
    'PH': 'php',
    'KR': 'krw',
    'TW': 'twd',
    'HK': 'hkd',
    'MO': 'mop',
  };

  return currencyMap[countryCode.toUpperCase()];
}

@riverpod
Future<String> deviceAppAndUserInfo(Ref ref) async {
  var me = await ref.watch(meProvider.future);
  var deviceInfo = await ref.watch(deviceAndAppInfoProvider.future);
  var auth = ref.read(authRepositorySyncProvider);
  var email = auth.getUserEmail();
  var stats = await ref.read(statsProvider.future);

  var basicInfo = _formatBasicInfo(me, deviceInfo, email);
  var streakDebugInfo = _formatStreakDebugInfo(stats);
  var audioCompletionInfo = await _formatAudioCompletionInfo(stats);

  return '$basicInfo$streakDebugInfo$audioCompletionInfo';
}

String _formatBasicInfo(
  MeModel? me,
  DeviceAndAppInfoModel? deviceInfo,
  String? emailAddress,
) {
  var isProdString = contentBaseUrl.contains('dev') ? 'Dev' : 'Prod';
  var env = 'env: $isProdString';
  var id = 'id: ${me?.id ?? ''}';
  var appVersion = 'appVersion: ${deviceInfo?.appVersion ?? ''}';
  var buildNumber = 'buildNumber: ${deviceInfo?.buildNumber ?? ''}';
  var deviceOs = 'deviceOs: ${deviceInfo?.os ?? ''}';
  var deviceModel = 'deviceModel: ${deviceInfo?.model ?? ''}';
  var devicePlatform = 'devicePlatform: ${deviceInfo?.platform ?? ''}';
  var email = 'email: ${emailAddress ?? ''}';
  var isMonthlyDonorString = 'd: ${me?.hasActiveSubscription ?? false}';

  return '$env\n$id\n$email\n$appVersion\n$buildNumber\n$deviceModel\n$devicePlatform\n$deviceOs\n$isMonthlyDonorString';
}

String _formatStreakDebugInfo(LocalAllStats? stats) {
  if (stats == null) return '';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final buf = StringBuffer();

  buf.writeln(
    '\n\nnow: ${now.day.toString().padLeft(2, '0')}/'
    '${now.month.toString().padLeft(2, '0')}/'
    '${now.year} '
    '${now.hour.toString().padLeft(2, '0')}:'
    '${now.minute.toString().padLeft(2, '0')} '
    '${now.timeZoneName}',
  );
  buf.writeln('streak: current=${stats.streakCurrent} longest=${stats.streakLongest}');
  buf.writeln('freezes: ${stats.streakFreezes ?? 0}/${stats.maxStreakFreezes ?? 0} available');

  // Count entries
  final allAudio = stats.audioCompleted ?? [];
  final freezeEntries =
      allAudio.where((a) => a.id == TypeConstants.streakFreeze).toList();
  final realEntries = allAudio.length - freezeEntries.length;
  buf.writeln('audio entries: total=${allAudio.length} real=$realEntries freeze=${freezeEntries.length}');

  // Freeze dates from audioCompleted
  final freezeDatesFromAudio = freezeEntries.map((a) {
    final d = DateTime.fromMillisecondsSinceEpoch(a.timestamp);
    return DateTime(d.year, d.month, d.day);
  }).toSet().toList()
    ..sort((a, b) => b.compareTo(a));

  // Legacy freeze usage dates
  final legacyFreezeDates = stats.freezeUsageDates.map((ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime(d.year, d.month, d.day);
  }).toSet().toList()
    ..sort((a, b) => b.compareTo(a));

  String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  if (freezeDatesFromAudio.isNotEmpty) {
    buf.writeln('freeze dates: ${freezeDatesFromAudio.map(fmtDate).join(', ')}');
  }
  if (legacyFreezeDates.isNotEmpty) {
    buf.writeln('legacy freeze dates: ${legacyFreezeDates.map(fmtDate).join(', ')}');
  }

  // Find streak break point
  final audioDates = allAudio
      .where((a) => a.id != TypeConstants.streakFreeze)
      .map((a) {
        final d = DateTime.fromMillisecondsSinceEpoch(a.timestamp);
        return DateTime(d.year, d.month, d.day);
      })
      .toSet()
      .toList();

  final allFreezeDates = {
    ...freezeDatesFromAudio,
    ...legacyFreezeDates,
  }.where((d) => !audioDates.contains(d) && !d.isAfter(today)).toSet();

  final allActivityDates = {...audioDates, ...allFreezeDates};

  final hasToday = allActivityDates.any(
    (d) => d.year == today.year && d.month == today.month && d.day == today.day,
  );
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final hasYesterday = allActivityDates.any(
    (d) =>
        d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day,
  );

  if (!hasToday && !hasYesterday) {
    buf.writeln('streak break: no activity today or yesterday');
  } else {
    var checkDate = hasYesterday ? yesterday : today;
    while (true) {
      final hasActivity = allActivityDates.any(
        (d) =>
            d.year == checkDate.year &&
            d.month == checkDate.month &&
            d.day == checkDate.day,
      );
      if (!hasActivity) {
        buf.writeln('streak break: ${fmtDate(checkDate)}');
        break;
      }
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }
  }

  return buf.toString();
}

Future<String> _formatAudioCompletionInfo(LocalAllStats? stats) async {
  if (stats?.audioCompleted == null ||
      (stats?.audioCompleted?.isEmpty ?? true)) {
    return '';
  }

  try {
    var formattedString = '\n\nact:';
    var recentSessions = _getRecentAudioSessions(stats!);

    for (var session in recentSessions) {
      var formattedTimestamp = _formatSessionTimestamp(session);
      formattedString += '\n$formattedTimestamp';
    }

    return formattedString;
  } catch (e) {
    return '\n\nError retrieving audio completion data: $e';
  }
}

List<LocalAudioCompleted> _getRecentAudioSessions(LocalAllStats stats) {
  // Sort by timestamp in descending order to get the most recent sessions
  var sortedSessions = List<LocalAudioCompleted>.from(stats.audioCompleted!)
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  // Take the 10 most recent sessions (or fewer if less are available)
  return sortedSessions.take(10).toList();
}

String _formatSessionTimestamp(LocalAudioCompleted session) {
  var timestamp = DateTime.fromMillisecondsSinceEpoch(session.timestamp);

  return '${timestamp.day.toString().padLeft(2, '0')}/'
      '${timestamp.month.toString().padLeft(2, '0')}/'
      '${timestamp.year} '
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}';
}
