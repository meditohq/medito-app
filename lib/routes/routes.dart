// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/pack/pack_view.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/views/track/track_view.dart';
import 'package:medito/views/timer/timer_view.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medito/views/home/customise_home_layout_screen.dart';

import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/views/debug/debug_info_screen.dart';
import 'package:medito/views/donation/webview_donation_screen.dart';
import 'package:medito/views/favorites/favorites_view.dart';
import 'package:medito/views/stats/stats_screen.dart';
import 'package:medito/views/settings/analytics_settings_screen.dart';
import 'package:medito/views/shop/product_screen.dart';
import 'package:medito/views/shop/shop_screen.dart';
import 'package:medito/services/shop/fourthwall_service.dart';

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
  // Where a Timer opened from, for timer_opened; deeplink when unset.
  String? timerSource,
}) async {
  ids.removeWhere((element) => element == null);

  if (type == null) return;

  if (type.contains('tracks') || type.contains('track')) {
    await _handleTrackNavigation(ids, ref, timerSource: timerSource);
  } else if (type.contains('pack')) {
    var packId = type.contains('pack3')
        ? ids[2]!
        : type.contains('pack2')
        ? ids[1]!
        : ids.first!;
    AppLogger.d('ROUTES', 'Opening pack: $packId');
    if (packId == 'favorites') {
      await _pushRoute(const FavoritesView(), ref);
    } else {
      await _pushRoute(PackView(id: packId), ref);
    }
  } else if (type == TypeConstants.url || type == TypeConstants.link) {
    final url = ids.last ?? 'https://meditofoundation.org/';
    final uri = Uri.parse(url);
    final shopRoute = _nativeShopRoute(uri);
    if (shopRoute != null) {
      await _pushRoute(shopRoute, ref);
    } else if (await canLaunchUrl(uri)) {
      final isEditStatsUrl = url.startsWith(editStatsUrl);
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => _URLLauncherScreen(url: uri)),
      );
      // After returning from edit stats web form, force sync to get updated stats
      if (isEditStatsUrl && ref != null) {
        ref.read(statsManagerProvider).sync(force: true);
        ref.read(statsProvider.notifier).refresh();
      }
    }
  } else if (type.contains('settings')) {
    await _pushRoute(SettingsScreen(), ref);
  } else if (_isDonationRoute(type, ids)) {
    await handleDonationNavigation(context, ref, sourceRouteName);
  } else if (type == TypeConstants.email) {
    await _handleEmailNavigation(ids, ref);
  } else if (type == TypeConstants.flow && ids.contains('downloads')) {
    await _pushRoute(const DownloadsView(), ref);
  } else if (type == TypeConstants.account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SignUpLogInPage(
          source: AnalyticsEventConstants.sourceDeeplink,
        ),
      ),
    );
  } else if (type == TypeConstants.route &&
      ids.contains(TypeConstants.customiseHomeLayout)) {
    await _pushRoute(const CustomiseHomeLayoutScreen(), ref);
  } else if (type == TypeConstants.route &&
      ids.any((id) => id?.contains(RouteConstants.stats) ?? false)) {
    final statsPath = ids.firstWhere(
      (id) => id?.contains(RouteConstants.stats) ?? false,
      orElse: () => RouteConstants.stats,
    );
    final initialTabIndex = statsPath?.contains(':history') == true ? 1 : 0;
    await _pushRoute(StatsScreen(initialTabIndex: initialTabIndex), ref);
  } else if (type == TypeConstants.route && ids.any(_isShopRoute)) {
    final id = ids.firstWhere(_isShopRoute)!;
    final slug = id.contains(':') ? id.substring(id.indexOf(':') + 1) : '';
    final source = sourceRouteName ?? AnalyticsEventConstants.sourceDeeplink;
    await _pushRoute(
      slug.isEmpty
          ? ShopScreen(source: source)
          : ProductScreen(slug: slug, source: source),
      ref,
    );
  } else if (type == TypeConstants.route &&
      ids.contains(RouteConstants.timer)) {
    await _pushRoute(
      TimerView(source: timerSource ?? AnalyticsEventConstants.sourceDeeplink),
      ref,
    );
  } else if (type == TypeConstants.route &&
      ids.contains(RouteConstants.analytics)) {
    await _pushRoute(const AnalyticsSettingsScreen(), ref);
  } else if (type == '/debug_info') {
    await _pushRoute(const DebugInfoScreen(), ref);
  }
}

bool _isShopRoute(String? id) =>
    id == RouteConstants.shop ||
    (id?.startsWith('${RouteConstants.shop}:') ?? false);

/// Links to shop.medito.app (announcements, carousel, settings) open the
/// native shop: the storefront root or a collection opens the grid, a
/// product link opens that product. Anything else stays on the web.
Widget? _nativeShopRoute(Uri uri) {
  if (uri.host != FourthwallService.shopDomain) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty || segments.first == 'collections') {
    return const ShopScreen(source: AnalyticsEventConstants.sourceDeeplink);
  }
  if (segments.first == 'products' && segments.length > 1) {
    return ProductScreen(
      slug: segments[1],
      source: AnalyticsEventConstants.sourceDeeplink,
    );
  }
  return null;
}

Future<bool?> _pushRoute(Widget route, WidgetRef? ref) async {
  return await navigatorKey.currentState?.push<bool>(
    MaterialPageRoute(builder: (context) => route),
  );
}

/// Check if the navigation type/ids represent a donation route
bool _isDonationRoute(String? type, List<String?> ids) {
  return type == 'donation' ||
      (type == TypeConstants.route && ids.contains(RouteConstants.donation));
}

Future<void> _handleTrackNavigation(
  List<String?> ids,
  WidgetRef? ref, {
  String? timerSource,
}) async {
  try {
    var trackId = ids.first!;
    // The home Timer shortcut still points at the old bell-only track; the
    // native timer replaces it wherever it is linked from.
    if (trackId == kLegacyTimerTrackId) {
      await _pushRoute(
        TimerView(
          source: timerSource ?? AnalyticsEventConstants.sourceDeeplink,
        ),
        ref,
      );
      return;
    }
    await _pushRoute(TrackView(trackId: trackId), ref);
    ref?.read(statsProvider.notifier).refresh();
  } catch (e, s) {
    AppLogger.d('ROUTES', s.toString());
  }
}

Future<void> _handleEmailNavigation(List<String?> ids, WidgetRef? ref) async {
  if (ref != null) {
    var deviceAppAndUserInfo = await ref.read(
      deviceAppAndUserInfoProvider.future,
    );
    var info =
        'Debug info\n$deviceAppAndUserInfo\n--- Write below this line ---'; // These will be localized in the UI layer
    var emailAddress = ids.first!;
    await launchEmailSubmission(emailAddress, body: info);
  }
}

Future<bool?> handleDonationNavigation(
  BuildContext context,
  WidgetRef? ref,
  String? sourceRouteName, {
  NavigatorState? navigator,
}) async {
  if (ref == null) {
    AppLogger.w('ROUTES', 'Cannot open donation screen: ref is null');
    return false;
  } else {
    AppLogger.d('ROUTES', 'Opening donation screen from $sourceRouteName');
  }

  if (isMockMode) {
    AppLogger.d('ROUTES', 'Mock mode: skipping payment and paywall flows');
    return false;
  }

  // Stripe's publishable key is set lazily when paymentConfigProvider resolves.
  // Preload so the webview can pass currency/country and the in-page Stripe
  // Elements fallback (used when no native pay method is available) works.
  try {
    await ref
        .read(paymentConfigProvider.future)
        .timeout(const Duration(seconds: 5));
  } on TimeoutException {
    AppLogger.w('ROUTES', 'Payment config load timed out — proceeding anyway');
  } catch (e) {
    AppLogger.w('ROUTES', 'Could not preload payment config: $e');
  }

  final nav = navigator ?? navigatorKey.currentState;
  if (nav == null) return false;

  return await nav.push<bool>(
    MaterialPageRoute(
      builder: (context) => WebViewDonationScreen(source: sourceRouteName),
    ),
  );
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
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}
