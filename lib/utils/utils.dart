import 'dart:async';
import 'dart:ui';

import 'package:medito/constants/constants.dart';
import 'package:medito/utils/logger.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

Color parseColor(String? color) {
  if (color == null || color.isEmpty) return ColorConstants.ebony;
  try {
    return Color(int.parse(color.replaceFirst('#', 'FF'), radix: 16));
  } catch (e) {
    return ColorConstants.ebony;
  }
}

Future<void> launchURLInBrowser(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      var launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );
      }
    }
  } catch (e) {
    AppLogger.e('URL', 'Error launching URL: $url', e);
  }
}

Future<void> launchEmailSubmission(
  String href, {
  String? subject,
  String? body,
}) async {
  var query = '';
  if (subject != null) {
    query = 'subject=$subject';
  }
  if (body != null) {
    var newBody = body.replaceAll('\n', '\r\n');
    query = query != '' ? '$query&body=$newBody' : 'body=$newBody';
  }

  final params = Uri(
    scheme: 'mailto',
    path: href.replaceAll('mailto:', ''),
    query: query,
  );

  if (await canLaunchUrl(params)) {
    await launchUrl(params);
  }
}

int convertDurationToMinutes({required int milliseconds}) {
  const millisecondsPerMinute = 60000;

  return (milliseconds.abs() / millisecondsPerMinute).round();
}

//ignore: prefer-match-file-name
extension EmptyOrNull on String? {
  bool isNullOrEmpty() {
    if (this == null) return true;
    if (this?.isEmpty == true) return true;

    return false;
  }

  bool isNotNullAndNotEmpty() {
    return this != null && this?.isNotEmpty == true;
  }
}

String getAudioFileExtension(String path) {
  var lastIndex = path.lastIndexOf('/');
  if (lastIndex != -1) {
    var filenameWithQuery = path.substring(lastIndex + 1);
    var filename = Uri.decodeFull(filenameWithQuery.split('?').first);
    var dotIndex = filename.lastIndexOf('.');
    if (dotIndex != -1) {
      var fileExtension = filename.substring(dotIndex + 1);

      return '.$fileExtension';
    }
  }

  return '.mp3';
}

extension GetIdFromPath on String {
  String getIdFromPath() {
    return split('/').last;
  }
}

extension ColorExtensions on Color {
  Color withOpacityValue(double opacity) {
    return withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
  }
}

/// Check if the device is currently set to a US locale
bool isInUS() {
  final countryCode = PlatformDispatcher.instance.locale.countryCode;
  return countryCode != null && countryCode.toUpperCase() == 'US';
}


Future<bool> shouldUseSuperwallForDonation() async {
  // Apple Pay is never available on simulator builds, and calling
  // isPlatformPaySupported() on a simulator triggers the OS-level
  // "Sign in with Apple ID" dialog that blocks the UI. Skip it entirely.
  const kIsSimulatorBuild = bool.fromEnvironment('IS_SIMULATOR');
  if (kIsSimulatorBuild) {
    AppLogger.d('DONATION_UTILS',
        'Simulator build — skipping Apple Pay check, using web donation');
    return false;
  }

  final isPlatformPaySupported =
      await Stripe.instance.isPlatformPaySupported();
  if (!isPlatformPaySupported) {
    AppLogger.d('DONATION_UTILS',
        'Apple Pay / Google Pay not supported - using web donation');

    return false;
  }

  try {
    final configStatus = await Superwall.shared.getConfigurationStatus();
    AppLogger.d('DONATION_UTILS', 'Superwall config status: $configStatus');

    if (configStatus == ConfigurationStatus.configured) {
      AppLogger.d('DONATION_UTILS', 'Superwall configured - using Superwall');

      return true;
    } else {
      AppLogger.w('DONATION_UTILS',
          'Superwall not configured (status: $configStatus) - using web donation');

      return false;
    }
  } catch (error) {
    AppLogger.e('DONATION_UTILS',
        'Error checking Superwall status - using web donation', error);

    return false;
  }
}
