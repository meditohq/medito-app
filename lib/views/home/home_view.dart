import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home/home_provider.dart';
import 'widgets/announcement/announcement_widget.dart';
import 'widgets/bottom_sheet/stats/stats_bottom_sheet_widget.dart';
import 'widgets/editorial/carousel_widget.dart';
import 'widgets/header_widget.dart';
import 'widgets/quote/quote_widget.dart';
import 'widgets/shortcuts/shortcuts_widget.dart';

class HomeView extends ConsumerStatefulWidget {
  HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
  var _isConnected = true;
  late final StreamSubscription _subscription;
  bool isCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }

  late CurvedAnimation curvedAnimation = CurvedAnimation(
    parent: AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..forward(),
    curve: Curves.easeInOut,
  );

  void _handleCollapse() {
    setState(() {
      isCollapsed = !isCollapsed;
    });
    curvedAnimation = CurvedAnimation(
      parent: AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1000),
      )..forward(),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_isConnected) {
      return ConnectivityErrorWidget();
    }

    final home = ref.watch(fetchHomeProvider);
    final announcementData = ref.watch(fetchLatestAnnouncementProvider);
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
          backgroundColor: ColorConstants.ebony,
          appBar: AppBar(
            backgroundColor: ColorConstants.onyx,
            toolbarHeight: 150.0,
            title: HeaderWidget(
              greeting: homeData.greeting ?? StringConstants.welcome,
              statsData: stats.value,
              onStatsButtonTap: () => _onStatsButtonTapped(context, ref),
            ),
            elevation: 0.0,
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                children: [
                  _getAnnouncementBanner(announcementData.value),
                  height20,
                  ShortcutsWidget(data: homeData.shortcuts),
                  height20,
                  CarouselWidget(data: homeData.carousel),
                  height20,
                  QuoteWidget(data: homeData.todayQuote),
                  height20,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _getAnnouncementBanner(AnnouncementModel? data) {
    if (data == null) {
      return Container();
    }

    return SizeTransition(
      axisAlignment: -1,
      sizeFactor: isCollapsed
          ? Tween<double>(begin: 1.0, end: 0.0).animate(
              curvedAnimation,
            )
          : Tween<double>(begin: 0.0, end: 1.0).animate(
              curvedAnimation,
            ),
      child: AnnouncementWidget(
        announcement: data,
        onPressedDismiss: _handleCollapse,
      ),
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(fetchLatestAnnouncementProvider);
    await ref.read(fetchLatestAnnouncementProvider.future);
    ref.invalidate(refreshHomeAPIsProvider);
    await ref.read(refreshHomeAPIsProvider.future);
    ref.invalidate(fetchStatsProvider);
    await ref.read(fetchStatsProvider.future);
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
