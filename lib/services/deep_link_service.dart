import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/app_globals.dart' show appReadyCompleter;
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final WidgetRef ref;
  final BuildContext context;

  // Guards against the same URI being delivered twice in quick succession —
  // happens on Android when both `getInitialLink()` and `uriLinkStream` fire
  // for a cold-start intent, or on rapid double-taps of a home-screen widget.
  Uri? _lastHandledUri;
  DateTime? _lastHandledAt;
  static const _dedupeWindow = Duration(milliseconds: 1500);

  // Completes once the initial link check finishes (hit or miss).
  // SplashView awaits this before applying stored UTM parameters to ensure
  // deferred deep links from Apple Search Ads are stored first.
  static final Completer<void> _initialLinkCompleter = Completer<void>();
  static Future<void> get initialLinkProcessed =>
      _initialLinkCompleter.future;

  DeepLinkService({
    required this.ref,
    required this.context,
  });

  void initialize() {
    AppLogger.d('DEEPLINK', 'Setting up deep link handlers');

    _checkInitialLink();

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

  Future<void> _checkInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        AppLogger.d('DEEPLINK', 'Got initial deep link: $initialUri');
        await handleDeepLink(initialUri);
      }
    } catch (e) {
      AppLogger.e('DEEPLINK', 'Error checking initial link', e);
    } finally {
      if (!_initialLinkCompleter.isCompleted) {
        _initialLinkCompleter.complete();
      }
    }
  }

  // Waits until the app has finished auth/init, then navigates.
  Future<void> _navigateWhenReady(String path, String id) async {
    try {
      await appReadyCompleter.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      AppLogger.w('DEEPLINK', 'App not ready after 15s, proceeding anyway');
    }

    if (!context.mounted) return;

    handleNavigation(path, [id], context, ref: ref);
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  Future<void> handleDeepLink(Uri uri) async {
    AppLogger.d('DEEPLINK', 'Handling deep link: ${uri.toString()}');
    AppLogger.d('DEEPLINK', 'Scheme: ${uri.scheme}');
    AppLogger.d('DEEPLINK', 'Host: ${uri.host}');
    AppLogger.d('DEEPLINK', 'Path: ${uri.path}');

    final now = DateTime.now();
    if (_lastHandledUri == uri &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < _dedupeWindow) {
      AppLogger.d('DEEPLINK', 'Ignoring duplicate deep link within dedupe window: $uri');
      return;
    }
    _lastHandledUri = uri;
    _lastHandledAt = now;

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
        if (context.mounted) {
          final localizations = AppLocalizations.of(context);
          if (localizations != null) {
            showSnackBar(context, localizations.invalidDeepLink);
          }
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

      _navigateWhenReady(path, id);
    } catch (e) {
      AppLogger.e('DEEPLINK', 'Error handling deep link', e);
      if (context.mounted) {
        final localizations = AppLocalizations.of(context);
        if (localizations != null) {
          showSnackBar(context, localizations.deepLinkError);
        }
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

      final prefs = await SharedPreferences.getInstance();
      var storedCount = 0;

      final utmParams = [
        SharedPreferenceConstants.utmSource,
        SharedPreferenceConstants.utmMedium,
        SharedPreferenceConstants.utmCampaign,
        SharedPreferenceConstants.utmTerm,
        SharedPreferenceConstants.utmContent,
      ];

      for (final paramKey in utmParams) {
        final value = queryParameters[paramKey];
        if (value != null && value.isNotEmpty) {
          await prefs.setString(paramKey, value);
          storedCount++;
          AppLogger.d('DEEPLINK', 'Stored UTM parameter: $paramKey = $value');
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
