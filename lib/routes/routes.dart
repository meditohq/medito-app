import 'dart:async';

import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/pack/pack_view.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/views/track/track_view.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/utils.dart';
import '../views/downloads/downloads_view.dart';

extension SanitisePath on String {
  String sanitisePath() {
    return replaceFirst('/', '');
  }
}

Future<void> logScreenView(String screenName,
    {Map<String, dynamic>? parameters}) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'screen_view',
    parameters: {
      'screen_name': screenName,
      ...?parameters,
    },
  );
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
      await logScreenView('Track View', parameters: {'track_id': trackId});
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
      print(s);
    }
    return;
  } else if (place != null && place.contains('pack3')) {
    var p3id = ids[2]!;
    await logScreenView('Pack View',
        parameters: {'pack_id': p3id, 'pack_level': '3'});
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
    ;
  } else if (place != null && place.contains('pack2')) {
    var p2id = ids[1]!;
    await logScreenView('Pack View',
        parameters: {'pack_id': p2id, 'pack_level': '2'});
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
    ;
  } else if (place == TypeConstants.pack) {
    var pid = ids.first!;
    await logScreenView('Pack View', parameters: {'pack_id': pid});
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
    await logScreenView('External URL', parameters: {'url': url});
    await launchURLInBrowser(url);
    return;
  } else if (place != null && place.contains('settings')) {
    await logScreenView('Settings Screen');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(),
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
      await logScreenView('Email Submission',
          parameters: {'email': emailAddress});
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
