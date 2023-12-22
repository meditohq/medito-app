import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/home/widgets/header_and_announcement_widget.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/editorial/editorial_widget.dart';
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
    var homeAPIsResponse = ref.watch(refreshHomeAPIsProvider);
    var connectivityStatus = ref.watch(connectivityStatusProvider);
    if (connectivityStatus == ConnectivityStatus.isDisconnected) {
      return ConnectivityErrorWidget();
    }

    if (homeAPIsResponse.hasError) {
      return MeditoErrorWidget(
        message: homeAPIsResponse.error.toString(),
        onTap: () => _onRefresh(),
        isLoading: homeAPIsResponse.isLoading,
      );
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
                          height20,
                          ShortcutsWidget(),
                          height20,
                          EditorialWidget(),
                          height20,
                          QuoteWidget(),
                          height20,
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
    ref.invalidate(refreshHomeAPIsProvider);
    await ref.read(refreshHomeAPIsProvider.future);
  }

  FloatingActionButton _buildFloatingButton(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: ColorConstants.lightPurple,
      onPressed: () {
        context.push(RouteConstants.searchPath);
      },
      icon: Icon(Icons.explore, color: ColorConstants.walterWhite),
      label: Text(
        StringConstants.explore,
        style: TextStyle(
          color: ColorConstants.walterWhite,
          fontFamily: SourceSerif,
          fontSize: 20,
          fontWeight: FontWeight.w700,

        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
