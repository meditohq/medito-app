import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final WidgetRef ref;
  final BuildContext context;

  DeepLinkService({
    required this.ref,
    required this.context,
  });

  void initialize() {
    AppLogger.d('DEEPLINK', 'Setting up deep link handlers');

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        AppLogger.d('DEEPLINK', 'Got deep link: $uri');
        handleDeepLink(uri);
      },
      onError: (err) {
        AppLogger.e('DEEPLINK', 'Error from link stream', err);
      },
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  Future<void> handleDeepLink(Uri uri) async {
    AppLogger.d('DEEPLINK', 'Handling deep link: ${uri.toString()}');
    AppLogger.d('DEEPLINK', 'Scheme: ${uri.scheme}');
    AppLogger.d('DEEPLINK', 'Host: ${uri.host}');
    AppLogger.d('DEEPLINK', 'Path: ${uri.path}');

    try {
      // Extract and store UTM parameters before navigation
      await _storeUtmParameters(uri);

      var pathSegments = <String>[];

      if (uri.scheme == 'org.meditofoundation') {
        // For custom scheme, if host is "medito", use pathSegments directly
        // Otherwise, treat host as first path segment (e.g., org.meditofoundation://tracks/123)
        if (uri.host == 'medito') {
          pathSegments = uri.pathSegments;
        } else {
          pathSegments = [uri.host, ...uri.pathSegments];
        }
      } else if (uri.scheme == 'https' && uri.host == 'medito.app') {
        pathSegments = uri.pathSegments;
      } else {
        final localizations = AppLocalizations.of(context);
        if (localizations != null) {
          showSnackBar(context, localizations.invalidDeepLink);
        }
        return;
      }

      // If no path segments, just open the app (e.g., for UTM-only links from Apple Ads)
      if (pathSegments.isEmpty) {
        AppLogger.d('DEEPLINK',
            'No path segments, opening app (UTM parameters already processed)');
        return;
      }

      // Handle OTP links
      if (pathSegments[0] == 'otp' ||
          (pathSegments.length > 1 && pathSegments[1] == 'otp')) {
        return;
      }

      // Handle other navigation links
      var path = pathSegments[0];
      var id = pathSegments.length > 1 ? pathSegments[1] : '';

      AppLogger.d('DEEPLINK', 'Navigating to: $path with id: $id');

      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) {
          handleNavigation(path, [id], context, ref: ref);
        }
      });
    } catch (e) {
      AppLogger.e('DEEPLINK', 'Error handling deep link', e);
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        showSnackBar(context, localizations.deepLinkError);
      }
    }
  }

  Future<void> _storeUtmParameters(Uri uri) async {
    try {
      final queryParameters = uri.queryParameters;
      AppLogger.d('DEEPLINK', 'Query parameters: $queryParameters');

      if (queryParameters.isEmpty) {
        AppLogger.d('DEEPLINK', 'No query parameters found in deep link');
        return;
      }

      // Standard UTM parameter names and their SharedPreferences keys
      final utmParamMap = {
        'utm_source': SharedPreferenceConstants.utmSource,
        'utm_medium': SharedPreferenceConstants.utmMedium,
        'utm_campaign': SharedPreferenceConstants.utmCampaign,
        'utm_term': SharedPreferenceConstants.utmTerm,
        'utm_content': SharedPreferenceConstants.utmContent,
      };

      final prefs = await SharedPreferences.getInstance();
      var storedCount = 0;

      for (final entry in utmParamMap.entries) {
        final value = queryParameters[entry.key];
        if (value != null && value.isNotEmpty) {
          await prefs.setString(entry.value, value);
          storedCount++;
          AppLogger.d(
              'DEEPLINK', 'Stored UTM parameter: ${entry.key} = $value');
        }
      }

      if (storedCount > 0) {
        AppLogger.d('DEEPLINK',
            'Stored $storedCount UTM parameter(s) for later application');
      } else {
        AppLogger.d('DEEPLINK', 'No UTM parameters found in query string');
      }
    } catch (e) {
      AppLogger.e('DEEPLINK', 'Error storing UTM parameters', e);
    }
  }
}
