import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/home/widgets/bottom_sheet/stats/stats_bottom_sheet_widget.dart';
import 'package:Medito/views/home/widgets/editorial/carousel_widget.dart';
import 'package:Medito/views/home/widgets/header_and_announcement_widget.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uni_links/uni_links.dart';

import '../../models/home/home_model.dart';
import '../../routes/routes.dart';
import 'widgets/quote/quote_widget.dart';
import 'widgets/shortcuts/shortcuts_widget.dart';

class HomeView extends ConsumerStatefulWidget {
  HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    navigateToDeepLink();
  }

  void navigateToDeepLink() {
    Future.delayed(Duration(seconds: 1), () async {
      handleDeepLink(await getInitialUri(), context);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var connectivityStatus = ref.watch(connectivityStatusProvider);
    if (connectivityStatus == ConnectivityStatus.isDisconnected) {
      return ConnectivityErrorWidget();
    }

    final home = ref.watch(fetchHomeProvider);
    final latestAnnouncement = ref.watch(fetchLatestAnnouncementProvider);

    final stats = ref.watch(fetchStatsProvider);

    return home.when(
      loading: () => HomeShimmerWidget(),
      error: (err, stack) => MeditoErrorWidget(
        message: home.error.toString(),
        onTap: () => _onRefresh(),
        isLoading: home.isLoading,
      ),
      data: (HomeModel homeData) {
        return Scaffold(
          backgroundColor: ColorConstants.amsterdamSpring,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Container(
                  color: ColorConstants.ebony,
                  child: Column(
                    children: [
                      Container(
                        color: ColorConstants.amsterdamSpring,
                        child: HeaderAndAnnouncementWidget(
                          menuData: homeData.menu,
                          announcementData: latestAnnouncement.value,
                          statsData: stats.value,
                          onStatsButtonTap: () =>
                              _onStatsButtonTapped(context, ref),
                        ),
                      ),
                      height20,
                      ShortcutsWidget(data: homeData.shortcuts),
                      height20,
                      CarouselWidget(data: homeData.carousel),
                      height20,
                      QuoteWidget(data: homeData.todayQuote),
                      height200,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(refreshHomeAPIsProvider);
    await ref.read(refreshHomeAPIsProvider.future);
    ref.invalidate(refreshStatsProvider);
    await ref.read(refreshStatsProvider.future);
  }

  void _onStatsButtonTapped(BuildContext context, WidgetRef ref) {
    ref.invalidate(fetchStatsProvider);
    ref.read(fetchStatsProvider);
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14.0),
          topRight: Radius.circular(14.0),
        ),
      ),
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: ColorConstants.onyx,
      builder: (BuildContext context) {
        return StatsBottomSheetWidget();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
