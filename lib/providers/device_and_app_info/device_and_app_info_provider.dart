import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:intl/intl.dart';

import '../../models/device_info/device_and_app_info_model.dart';
import '../../models/me/me_model.dart';
import '../me/me_provider.dart';

part 'device_and_app_info_provider.g.dart';

@riverpod
Future<DeviceAndAppInfoModel> deviceAndAppInfo(Ref ref) async {
  ref.keepAlive();

  var packageInfo = await PackageInfo.fromPlatform();
  var deviceInfo = await _getDeviceInfo();
  var localeInfo = _getLocaleInfo();

  var data = <String, String>{
    'model': deviceInfo.model,
    'os': deviceInfo.os,
    'platform': deviceInfo.platform,
    'buildNumber': packageInfo.buildNumber,
    'appVersion': packageInfo.version,
    'languageCode': localeInfo.languageCode,
    'currencyName': localeInfo.currencyName,
  };

  return DeviceAndAppInfoModel.fromJson(data);
}

class _LocaleInfo {
  final String languageCode;
  final String currencyName;

  _LocaleInfo(this.languageCode, this.currencyName);
}

_LocaleInfo _getLocaleInfo() {
  var languageCode = PlatformDispatcher.instance.locale.languageCode;
  var currencyName =
      NumberFormat.simpleCurrency(locale: languageCode).currencyName ?? '';

  return _LocaleInfo(languageCode, currencyName);
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

@riverpod
Future<String> deviceAppAndUserInfo(Ref ref) async {
  var me = await ref.watch(meProvider.future);
  var deviceInfo = await ref.watch(deviceAndAppInfoProvider.future);
  var auth = ref.read(authRepositorySyncProvider);
  var email = auth.getUserEmail();
  var stats = await ref.read(statsProvider.future);

  var basicInfo = _formatBasicInfo(me, deviceInfo, email);
  var audioCompletionInfo = await _formatAudioCompletionInfo(stats);

  return '$basicInfo$audioCompletionInfo';
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
