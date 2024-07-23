import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/pack/pack_view.dart';
import 'package:Medito/views/settings/settings_screen.dart';
import 'package:Medito/views/track/track_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../views/downloads/downloads_view.dart';

extension SanitisePath on String {
  String sanitisePath() {
    return replaceFirst('/', '');
  }
}

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
          builder: (context) => TrackView(id: trackId),
        ),
      );
    } catch (e, s) {
      print(s);
    }
    return;
  } else if (place != null && place.contains('pack3')) {
    var p3id = ids[2]!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackView(id: p3id),
      ),
    );
  } else if (place != null && place.contains('pack2')) {
    var p2id = ids[1]!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackView(id: p2id),
      ),
    );
  } else if (place == TypeConstants.pack) {
    var pid = ids.first!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackView(id: pid),
      ),
    );
  } else if (place == TypeConstants.url || place == TypeConstants.link) {
    await launchURLInBrowser(ids.last ?? StringConstants.meditoUrl);

    return;
  } else if (place != null && place.contains('settings')) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(),
      ),
    );
  } else if (place == TypeConstants.email) {
    if (ref != null) {
      var deviceAppAndUserInfo =
          await ref.read(deviceAppAndUserInfoProvider.future);
      var _info =
          '${StringConstants.debugInfo}\n$deviceAppAndUserInfo\n${StringConstants.writeBelowThisLine}';
      var emailAddress = ids.first!;
      await launchEmailSubmission(
        emailAddress,
        body: _info,
      );
    }
    return;
  } else if (place == TypeConstants.flow) {
    if (ids.contains('downloads')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DownloadsView()),
      );
    }
  }
}

Future<void> launchURLInBrowser(String url) async {
  var uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    throw 'Could not launch $url';
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

void handleDeepLink(Uri? uri, BuildContext context) {
  var path = uri?.path;
  if (path != null) {
    if (path.contains('tracks')) {
      handleNavigation(
        'tracks',
        [uri?.pathSegments.last ?? ''],
        context,
      );
    } else {
      unawaited(
        Navigator.pushNamed(
          context,
          path.sanitisePath(),
        ),
      );
    }
  }
}
