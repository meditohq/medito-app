import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/home/home_model.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/announcement/announcement_widget.dart';
import 'widgets/filters/filter_widget.dart';
import 'widgets/header/home_header_widget.dart';
import 'widgets/search/search_widget.dart';
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

  Color _backgroundColor = ColorConstants.ebony;
  var _announcementColor;
  var hasAnnouncement = false;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final newColor = _scrollController.offset > 100
        ? ColorConstants.ebony
        : _announcementColor;
    if (_backgroundColor != newColor) {
      setState(() {
        _backgroundColor = newColor;
      });
    }
  }

  void _handleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      hasAnnouncement = !hasAnnouncement;
      _backgroundColor = ColorConstants.ebony;
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
    var homeRes = ref.watch(homeProvider);
    var stats = ref.watch(remoteStatsProvider);
    final currentlyPlayingSession = ref.watch(playerProvider);
    var topPadding = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      body: homeRes.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (data) {
          hasAnnouncement = data.announcement == null;
          _announcementColor = !_isCollapsed && !hasAnnouncement
              ? ColorConstants.getColorFromString(
                  data.announcement!.colorBackground,
                )
              : ColorConstants.ebony;

          return SafeArea(
            top: hasAnnouncement,
            bottom: false,
            child: Container(
              color: _backgroundColor,
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
                        setState(() {
                          _isCollapsed = false;
                        });
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
                              _getAnnouncementBanner(data),
                              Visibility(
                                visible: hasAnnouncement ? false : _isCollapsed,
                                child: SizedBox(
                                  height: topPadding,
                                ),
                              ),
                              HomeHeaderWidget(
                                homeMenuModel: data.menu,
                                miniStatsModel: stats.asData?.value.mini,
                              ),
                              Column(
                                children: [
                                  SearchWidget(),
                                  height8,
                                  FilterWidget(
                                    chips: data.chips,
                                  ),
                                  height16,
                                  height16,
                                  _cardListWidget(data),
                                  SizedBox(
                                    height: currentlyPlayingSession != null
                                        ? 16
                                        : 48,
                                  ),
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
                bottom: e.title == data.rows.last.title ? 16 : 32,
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
        child: AnnouncementWidget(
          announcement: data.announcement!,
          onPressedDismiss: _handleCollapse,
        ),
      );
    }

    return SizedBox();
  }

  @override
  bool get wantKeepAlive => true;
}
