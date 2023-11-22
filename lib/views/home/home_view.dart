import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/home/home_model.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'widgets/announcement/announcement_widget.dart';
import 'widgets/filters/filter_widget.dart';
import 'widgets/header/home_header_widget.dart';
import 'widgets/meditation_cards/card_list_widget.dart';
import 'package:Medito/providers/providers.dart';

class HomeView extends ConsumerStatefulWidget {
  HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isCollapsed = false;
  final ScrollController _scrollController = ScrollController();

  late CurvedAnimation curvedAnimation = CurvedAnimation(
    parent: AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..forward(),
    curve: Curves.easeInOut,
  );

  void _handleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
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
    var connectivityStatus =
        ref.watch(connectivityStatusProvider) as ConnectivityStatus;
    var homeRes = ref.watch(homeProvider);
    var stats = ref.watch(remoteStatsProvider);
    if (connectivityStatus == ConnectivityStatus.isDisonnected) {
      return ConnectivityErrorWidget();
    }

    return Scaffold(
      floatingActionButton: Listener(
        onPointerDown: (_) async {
          if (await Vibration.hasVibrator() ?? false) {
            if ((await Vibration.hasAmplitudeControl()) ?? false) {
              Vibration.vibrate(amplitude: 20, duration: 30);
            } else {
              Vibration.vibrate(duration: 30);
            }
          }
        },
        onPointerUp: (_) async {
          if (await Vibration.hasVibrator() ?? false) {
            if ((await Vibration.hasAmplitudeControl()) ?? false) {
              Vibration.vibrate(amplitude: 50, duration: 5);
            } else {
              Vibration.vibrate(duration: 5);
            }
          }
        },
        child: FloatingActionButton.extended(
          backgroundColor: ColorConstants.onyx,
          onPressed: () {
            context.push(RouteConstants.search);
          },
          icon: Icon(Icons.explore, color: ColorConstants.walterWhite),
          label: Text(
            'Explore',
            style: TextStyle(
              color: ColorConstants.walterWhite,
              fontFamily: DmSerif,
              fontSize: 20,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: homeRes.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (data) {
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
                        if (_isCollapsed) {
                          _handleCollapse();
                        }
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
                              HomeHeaderWidget(
                                homeMenuModel: data.menu,
                                miniStatsModel: stats.asData?.value.mini,
                              ),
                              Column(
                                children: [
                                  _getAnnouncementBanner(data),
                                  height24,
                                  FilterWidget(
                                    chips: data.chips,
                                  ),
                                  height32,
                                  _cardListWidget(data),
                                  height32,
                                  height32,
                                  height32,
                                ],
                              ),
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

  Column _cardListWidget(HomeModel data) {
    return Column(
      children: data.rows
          .map(
            (e) => Padding(
              padding: EdgeInsets.only(
                bottom: e.title == data.rows.last.title ? 0 : 32,
              ),
              child: CardListWidget(
                row: e,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _getAnnouncementBanner(HomeModel data) {
    if (data.announcement != null) {
      return SizeTransition(
        axisAlignment: -1,
        sizeFactor: _isCollapsed
            ? Tween<double>(begin: 1.0, end: 0.0).animate(
                curvedAnimation,
              )
            : Tween<double>(begin: 0.0, end: 1.0).animate(
                curvedAnimation,
              ),
        child: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: AnnouncementWidget(
            announcement: data.announcement!,
            onPressedDismiss: _handleCollapse,
          ),
        ),
      );
    }

    return SizedBox();
  }

  @override
  bool get wantKeepAlive => true;
}
