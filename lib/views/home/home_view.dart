import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/products_provider.dart';
import 'package:medito/providers/home/widget_order_provider.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/constants/constants.dart';
import 'widgets/announcement/home_announcement_section.dart';
import 'widgets/editorial/carousel_widget.dart';
import 'widgets/header_widget.dart';
import 'widgets/products/home_products_section.dart';
import 'widgets/quote/quote_widget.dart';
import 'widgets/shortcuts/shortcuts_items_widget.dart';
import 'widgets/up_next/up_next_widget.dart';
import 'widgets/up_next/your_path_explainer_strip.dart';

import '../../providers/home/announcement_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _analytics = FirebaseAnalyticsService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logScreenView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fixBrokenNotificationPermission();
    });
  }

  Future<void> _fixBrokenNotificationPermission() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (!(prefs.getBool(SharedPreferenceConstants.notifPermissionFixNeeded) ??
        false)) {
      return;
    }

    await prefs.remove(SharedPreferenceConstants.notifPermissionFixNeeded);

    final status = await Permission.notification.request();

    if (!mounted) return;

    if (status.isGranted) {
      final service = SmartRemindersService(
        prefs: prefs,
        reminders: ref.read(reminderProvider),
      );
      await service.enable();
      await ref.read(reminderEnabledProvider.notifier).setEnabled(true);
    } else {
      // They declined again — reset so the end-screen prompt can show later.
      await prefs.setBool(
        SharedPreferenceConstants.dailyReminderEnabled,
        false,
      );
      await prefs.remove(
        SharedPreferenceConstants.reminderPromptDismissedForever,
      );
      await prefs.remove(SharedPreferenceConstants.reminderPromptSnoozeUntil);
    }
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(screenName: 'HomeView');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final home = ref.watch(fetchHomeProvider);

    return home.when(
      loading: () => const _HomeLoadingView(),
      error: (err, stack) {
        final error = err is AppError ? err : const UnknownError();

        return MeditoErrorWidget(
          error: error,
          onTap: () => _onRefresh(),
          isLoading: home.isLoading,
        );
      },
      data: (HomeModel homeData) {
        final widgetOrder = ref.watch(homeWidgetOrderProvider);

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              edgeOffset: 150,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    floating: false,
                    pinned: false,
                    elevation: 0.0,
                    toolbarHeight: 56.0,
                    title: HeaderWidget(
                      greeting:
                          homeData.greeting ??
                          AppLocalizations.of(context)!.welcome,
                      onStatsButtonTap: () => _onStatsButtonTapped(context),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: HomeAnnouncementSection(),
                    ),
                  ),
                  SliverList.separated(
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: padding16,
                      endIndent: padding16,
                      color: context.brandPurple.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      var type = widgetOrder[index];
                      Widget child;
                      switch (type) {
                        case HomeWidgetType.shortcuts:
                          child = ShortcutsItemsWidget(
                            key: ValueKey(type.name),
                            data: homeData.shortcuts,
                          );
                          break;
                        case HomeWidgetType.carousel:
                          child = CarouselWidget(
                            key: ValueKey(type.name),
                            carouselItems: homeData.carousel,
                          );
                          break;
                        case HomeWidgetType.quote:
                          child = QuoteWidget(
                            key: ValueKey(type.name),
                            data: homeData.todayQuote,
                          );
                          break;
                        case HomeWidgetType.products:
                          child = const HomeProductsSection();
                          break;
                        case HomeWidgetType.upNext:
                          child = UpNextWidget(
                            key: ValueKey(type.name),
                            inlineStrip: const YourPathExplainerStrip(),
                          );
                          break;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: padding16,
                        ),
                        child: child,
                      );
                    },
                    itemCount: widgetOrder.length,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(fetchLatestAnnouncementProvider);
    ref.invalidate(refreshHomeAPIsProvider);
    ref.invalidate(refreshProductsProvider);
    // Refetch all pack data; upNext is derived and will re-derive automatically.
    ref.invalidate(packDataProvider);
    await Future.wait([
      ref.read(statsProvider.notifier).refresh(),
      ref.read(fetchLatestAnnouncementProvider.future),
      ref.read(refreshHomeAPIsProvider.future),
      ref.read(refreshProductsProvider.future),
    ]);
  }

  void _onStatsButtonTapped(BuildContext context) {
    ref
        .read(analyticsServiceProvider)
        .logFirstActionAfterOnboardingIfNeeded('stats');
    handleNavigation(
      TypeConstants.route,
      [RouteConstants.stats],
      context,
      ref: ref,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// Loading state for the home tab. If loading drags on (offline or a bad
/// connection can hold this spinner for up to the 30s request timeout), a
/// subtle "Go to Downloads" escape hatch fades in so downloaded sessions
/// stay reachable. A normal load resolves before the button ever appears.
class _HomeLoadingView extends StatefulWidget {
  const _HomeLoadingView();

  @override
  State<_HomeLoadingView> createState() => _HomeLoadingViewState();
}

class _HomeLoadingViewState extends State<_HomeLoadingView> {
  var _showDownloadsButton = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showDownloadsButton = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: SafeArea(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showDownloadsButton ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: TextButton(
                    onPressed: _showDownloadsButton
                        ? () => handleNavigation(TypeConstants.flow, [
                            TypeConstants.downloads,
                          ], context)
                        : null,
                    child: Text(
                      AppLocalizations.of(context)!.goToDownloads,
                      style: TextStyle(
                        color: context.brandPurple.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
