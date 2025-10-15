// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/pack/pack_view.dart';
import 'package:medito/views/path/journal_entry_view.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/views/track/track_view.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medito/views/home/customise_home_layout_screen.dart';

import 'package:medito/views/debug/debug_info_screen.dart';
import 'package:medito/views/donation/superwall_donation_screen.dart';
import 'package:medito/views/favorites/favorites_view.dart';

extension SanitisePath on String {
  String sanitisePath() => replaceFirst('/', '');
}

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> handleNavigation(
  String? type,
  List<String?> ids,
  BuildContext context, {
  WidgetRef? ref,
  VoidCallback? onNavigationComplete,
  String? sourceRouteName,
}) async {
  ids.removeWhere((element) => element == null);

  if (type == null) return;

  if (type.contains('tracks') || type.contains('track')) {
    await _handleTrackNavigation(ids, ref);
  } else if (type.contains('pack')) {
    var packId = type.contains('pack3')
        ? ids[2]!
        : type.contains('pack2')
            ? ids[1]!
            : ids.first!;
    if (packId == 'favorites') {
      await _pushRoute(const FavoritesView(), ref);
    } else {
      await _pushRoute(PackView(id: packId), ref);
    }
  } else if (type == TypeConstants.url || type == TypeConstants.link) {
    final url = ids.last ?? 'https://meditofoundation.org/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _URLLauncherScreen(url: uri),
        ),
      );
    }
  } else if (type.contains('settings')) {
    await _pushRoute(SettingsScreen(), ref);
  } else if (type == TypeConstants.email) {
    await _handleEmailNavigation(ids, ref);
  } else if (type == TypeConstants.flow && ids.contains('downloads')) {
    await _pushRoute(const DownloadsView(), ref);
  } else if (type == TypeConstants.account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SignUpLogInPage(),
      ),
    );
  } else if (type == TypeConstants.journalEntry) {
    var id = ids.first ?? '';
    var content = ids.length > 1 ? ids[1] ?? '' : '';
    var isCompleted = ids.length > 2 ? ids[2] == 'true' : false;
    await _pushRoute(
        JournalEntryView(
          taskId: id,
          isCompleted: isCompleted,
          initialText: content,
        ),
        ref);
  } else if (type == TypeConstants.route &&
      ids.contains(TypeConstants.customiseHomeLayout)) {
    await _pushRoute(const CustomiseHomeLayoutScreen(), ref);
  } else if (type == TypeConstants.route &&
      ids.contains(RouteConstants.donation)) {
    await _pushRoute(SuperwallDonationScreen(source: sourceRouteName), ref);
  } else if (type == '/debug_info') {
    await _pushRoute(const DebugInfoScreen(), ref);
  }
}

Future<bool?> _pushRoute(Widget route, WidgetRef? ref) async {
  return await navigatorKey.currentState
      ?.push<bool>(MaterialPageRoute(builder: (context) => route))
      .then((success) {
    ref?.read(statsProvider.notifier).refresh();
    return success;
  });
}

Future<void> _handleTrackNavigation(List<String?> ids, WidgetRef? ref) async {
  try {
    var trackId = ids.first!;
    await _pushRoute(TrackView(trackId: trackId), ref);
  } catch (e, s) {
    AppLogger.d('ROUTES', s.toString());
  }
}

Future<void> _handleEmailNavigation(List<String?> ids, WidgetRef? ref) async {
  if (ref != null) {
    var deviceAppAndUserInfo =
        await ref.read(deviceAppAndUserInfoProvider.future);
    var info =
        'Debug info\n$deviceAppAndUserInfo\n--- Write below this line ---'; // These will be localized in the UI layer
    var emailAddress = ids.first!;
    await launchEmailSubmission(emailAddress, body: info);
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

// This allows running a callback onPop
class _URLLauncherScreen extends StatefulWidget {
  final Uri url;

  const _URLLauncherScreen({required this.url});

  @override
  State<_URLLauncherScreen> createState() => _URLLauncherScreenState();
}

class _URLLauncherScreenState extends State<_URLLauncherScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _launchUrl();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _launchUrl() async {
    await launchUrl(widget.url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
    );
  }
}
