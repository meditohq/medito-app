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
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final home = ref.watch(fetchHomeProvider);

    return home.when(
      loading: () => const HomeShimmerWidget(),
      error: (err, stack) {
        return MeditoErrorWidget(
          message: home.error.toString(),
          onTap: () => _onRefresh(),
          isLoading: home.isLoading,
        );
      },
      data: (HomeModel homeData) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 56.0,
            title: HeaderWidget(
              greeting: homeData.greeting ?? StringConstants.welcome,
              onStatsButtonTap: () => _onStatsButtonTapped(context),
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
                  _getAnnouncementBanner(),
                  height20,
                  ShortcutsItemsWidget(data: homeData.shortcuts),
                  height20,
                  CarouselWidget(carouselItems: homeData.carousel),
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

  Widget _getAnnouncementBanner() {
    final data = ref.watch(fetchLatestAnnouncementProvider);

    return data.when(
      loading: () => Container(),
      error: (err, stack) => Container(),
      data: (announcement) {
        if (announcement == null || announcement.text == null || announcement.text == '') {
          return Container();
        }

        return AnnouncementWidget(
          announcement: announcement,
          onPressedDismiss: () {
            ref.invalidate(fetchLatestAnnouncementProvider);
          },
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(fetchLatestAnnouncementProvider);
    await ref.read(fetchLatestAnnouncementProvider.future);
    ref.invalidate(refreshHomeAPIsProvider);
    await ref.read(refreshHomeAPIsProvider.future);
  }

  void _onStatsButtonTapped(BuildContext context) {
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
