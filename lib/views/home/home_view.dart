import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/home/widgets/header_and_announcement_widget.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/quote/quote_widget.dart';
import 'widgets/shortcuts/shortcuts_widget.dart';
import 'widgets/tiles/tiles_widget.dart';

class HomeView extends ConsumerStatefulWidget {
  HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var connectivityStatus =
        ref.watch(connectivityStatusProvider) as ConnectivityStatus;
    if (connectivityStatus == ConnectivityStatus.isDisonnected) {
      return ConnectivityErrorWidget();
    }

    return Scaffold(
      floatingActionButton: _buildFloatingButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        bottom: false,
        child: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
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
                          HeaderAndAnnouncementWidget(),
                          height16,
                          ShortcutsWidget(),
                          height24,
                          QuoteWidget(),
                          height24,
                          TilesWidget(),
                          SizedBox(
                            height: 140,
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
      ),
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(fetchHomeHeaderProvider);
    await ref.read(fetchHomeHeaderProvider.future);
    ref.invalidate(fetchShortcutsProvider);
    await ref.read(fetchShortcutsProvider.future);
    ref.invalidate(fetchQuoteProvider);
    await ref.read(fetchQuoteProvider.future);
    ref.invalidate(remoteStatsProvider);
    await ref.read(remoteStatsProvider.future);
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
