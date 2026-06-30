import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:medito/constants/http/http_constants.dart';
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
    this.languageCode,
    this.currencyName,
    this.currency,
    this.country,
  );
}

_LocaleInfo _getLocaleInfo(Ref ref) {
  // Get the current locale from the locale provider (user's preference)
  final currentLocale = ref.watch(localeProvider);

  // Use the user's selected locale, fallback to system locale if not set
  var languageCode =
      currentLocale?.languageCode ??
      PlatformDispatcher.instance.locale.languageCode;
  var currencyName =
      NumberFormat.simpleCurrency(locale: languageCode).currencyName ?? '';

  // Get country code (ISO format like "US", "GB")
  var country =
      currentLocale?.countryCode ??
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

  return _formatBasicInfo(me, deviceInfo, email);
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
