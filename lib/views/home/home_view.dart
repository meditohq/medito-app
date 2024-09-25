import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home/home_provider.dart';
import 'widgets/announcement/announcement_widget.dart';
import 'widgets/bottom_sheet/stats/stats_bottom_sheet_widget.dart';
import 'widgets/editorial/carousel_widget.dart';
import 'widgets/header_widget.dart';
import 'widgets/quote/quote_widget.dart';
import 'widgets/shortcuts/shortcuts_items_widget.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
  bool isCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  late CurvedAnimation curvedAnimation = CurvedAnimation(
    parent: AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
        duration: const Duration(milliseconds: 1000),
      )..forward(),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final home = ref.watch(fetchHomeProvider);
    final announcementData = ref.watch(fetchLatestAnnouncementProvider);
    final stats = ref.watch(fetchStatsProvider);

    return home.when(
      loading: () => const HomeShimmerWidget(),
      error: (err, stack) => MeditoErrorWidget(
        message: home.error.toString(),
        onTap: () => _onRefresh(),
        isLoading: home.isLoading,
      ),
      data: (HomeModel homeData) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 92.0,
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
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                children: [
                  _getAnnouncementBanner(announcementData.value),
                  height20,
                  ShortcutsItemsWidget(data: homeData.shortcuts),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14.0),
          topRight: Radius.circular(14.0),
        ),
      ),
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: ColorConstants.onyx,
      builder: (BuildContext context) {
        return const StatsBottomSheetWidget();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
