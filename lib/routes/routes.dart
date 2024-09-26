import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/pack/pack_view.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/views/track/track_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medito/views/web_view/sign_up_log_in_web_view_screen.dart';

import '../utils/utils.dart';
import '../views/downloads/downloads_view.dart';

extension SanitisePath on String {
  String sanitisePath() {
    return replaceFirst('/', '');
  }
}

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> handleNavigation(
  String? place,
  List<String?> ids,
  BuildContext context, {
  WidgetRef? ref,
}) async {
  ids.removeWhere((element) => element == null);

  if (place != null && (place.contains('tracks') || place.contains('track'))) {
    try {
      var trackId = ids.first!;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrackView(trackId: trackId),
        ),
      ).then(
        (value) {
          ref?.invalidate(fetchStatsProvider);
        },
      );
    } catch (e, s) {
      if (kDebugMode) {
        print(s);
      }
    }
    return;
  } else if (place != null && place.contains('pack3')) {
    var p3id = ids[2]!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackView(id: p3id),
      ),
    ).then(
      (value) {
        ref?.invalidate(fetchStatsProvider);
      },
    );
  } else if (place != null && place.contains('pack2')) {
    var p2id = ids[1]!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackView(id: p2id),
      ),
    ).then(
      (value) {
        ref?.invalidate(fetchStatsProvider);
      },
    );
  } else if (place == TypeConstants.pack) {
    var pid = ids.first!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackView(id: pid),
      ),
    ).then(
      (value) {
        ref?.invalidate(fetchStatsProvider);
      },
    );
  } else if (place == TypeConstants.url || place == TypeConstants.link) {
    var url = ids.last ?? StringConstants.meditoUrl;
    await launchURLInBrowser(url);
    return;
  } else if (place != null && place.contains('settings')) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then(
      (value) {
        ref?.invalidate(fetchStatsProvider);
      },
    );
  } else if (place == TypeConstants.email) {
    if (ref != null) {
      var deviceAppAndUserInfo =
          await ref.read(deviceAppAndUserInfoProvider.future);
      var info =
          '${StringConstants.debugInfo}\n$deviceAppAndUserInfo\n${StringConstants.writeBelowThisLine}';
      var emailAddress = ids.first!;
      await launchEmailSubmission(
        emailAddress,
        body: info,
      );
    }
    return;
  } else if (place == TypeConstants.flow) {
    if (ids.contains('downloads')) {
      await navigatorKey.currentState
          ?.push(
        MaterialPageRoute(builder: (context) => const DownloadsView()),
      )
          .then((value) {
        ref?.invalidate(fetchStatsProvider);
      });
    }
  } else if (place == TypeConstants.webViewAccount) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignUpLogInWebView(url: ids.last ?? ''),
      ),
    );
  }
}

Future<void> launchEmailSubmission(String email, {String? body}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    query: 'body=$body',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    throw 'Could not launch $uri';
  }
}
