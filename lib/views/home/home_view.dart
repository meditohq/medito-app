import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/home/home_model.dart';
import 'package:Medito/models/stats/stats_model.dart';
import 'package:Medito/views/home/widgets/header_and_announcement_widget.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'widgets/announcement/announcement_widget.dart';
import 'widgets/filters/filter_widget.dart';
import 'widgets/header/home_header_widget.dart';
import 'package:Medito/providers/providers.dart';

class HomeView extends ConsumerStatefulWidget {
  HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var connectivityStatus =
        ref.watch(connectivityStatusProvider) as ConnectivityStatus;
    var homeRes = ref.watch(homeProvider);
    var stats = ref.watch(remoteStatsProvider);
    if (connectivityStatus == ConnectivityStatus.isDisonnected) {
      return ConnectivityErrorWidget();
    }

    return Scaffold(
      floatingActionButton: Listener(
        onPointerDown: onPointerDown,
        onPointerUp: onPointerUp,
        child: _buildFloatingButton(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: homeRes.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (data) {
          return _buildMain(data, stats);
        },
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(homeProvider),
          isLoading: homeRes.isLoading,
        ),
        loading: () => const HomeShimmerWidget(),
      ),
    );
  }

  void onPointerUp(_) async {
    if (await Vibration.hasVibrator() ?? false) {
      if ((await Vibration.hasAmplitudeControl()) ?? false) {
        unawaited(Vibration.vibrate(amplitude: 50, duration: 5));
      } else {
        unawaited(Vibration.vibrate(duration: 5));
      }
    }
  }

  void onPointerDown(_) async {
    if (await Vibration.hasVibrator() ?? false) {
      if ((await Vibration.hasAmplitudeControl()) ?? false) {
        unawaited(Vibration.vibrate(amplitude: 20, duration: 30));
      } else {
        unawaited(Vibration.vibrate(duration: 30));
      }
    }
  }

  SafeArea _buildMain(HomeModel data, AsyncValue<StatsModel> stats) {
    return SafeArea(
      bottom: false,
      child: Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(homeProvider);
                  await ref.read(homeProvider.future);
                  ref.invalidate(remoteStatsProvider);
                  await ref.read(remoteStatsProvider.future);
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Container(
                    color: ColorConstants.ebony,
                    child: Column(
                      children: [
                        HeaderAndAnnouncementWidget(),
                        height24,
                        FilterWidget(
                          chips: data.chips,
                        ),
                        height32,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  FloatingActionButton _buildFloatingButton(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: ColorConstants.onyx,
      onPressed: () {
        context.push(RouteConstants.searchPath);
      },
      icon: Icon(Icons.explore, color: ColorConstants.walterWhite),
      label: Text(
        StringConstants.explore,
        style: TextStyle(
          color: ColorConstants.walterWhite,
          fontFamily: DmSerif,
          fontSize: 20,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
