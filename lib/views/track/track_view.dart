/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/headers/description_widget.dart';
import 'package:Medito/widgets/headers/medito_app_bar_large.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/track_buttons_widget.dart';

class TrackView extends ConsumerStatefulWidget {
  final String id;

  TrackView({Key? key, required this.id}) : super(key: key);

  @override
  ConsumerState<TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends ConsumerState<TrackView>
    with AutomaticKeepAliveClientMixin<TrackView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    _handleTrackEvent(ref, widget.id);
    _scrollController.addListener(_scrollListener);
    super.initState();
  }

  void _scrollListener() {
    setState(() {});
  }

  void _handleTrackEvent(WidgetRef ref, String trackId) {
    var trackViewedModel = TrackViewedModel(trackId: trackId);
    var event = EventsModel(
      name: EventTypes.trackViewed,
      payload: trackViewedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(trackOpenedFirstTimeProvider);
    var tracks = ref.watch(tracksProvider(trackId: widget.id));
    ref.listen(trackOpenedFirstTimeProvider, (prev, next) {
      var _user =
          ref.read(authProvider.notifier).userRes.body as UserTokenModel;
      if (_user.email == null && next.value != null && next.value!) {
        var params = JoinRouteParamsModel(screen: Screen.track);
        context.push(
          RouteConstants.joinIntroPath,
          extra: params,
        );
      }
    });

    return Scaffold(
      body: tracks.when(
        skipLoadingOnRefresh: false,
        data: (data) => _buildScaffoldWithData(context, data, ref),
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(tracksProvider(trackId: widget.id)),
        ),
        loading: () => _buildLoadingWidget(),
      ),
    );

  }

  TrackShimmerWidget _buildLoadingWidget() => const TrackShimmerWidget();

  RefreshIndicator _buildScaffoldWithData(
      BuildContext context,
      TrackModel trackModel,
      WidgetRef ref,
      ) {
    return RefreshIndicator(
      onRefresh: () async => await ref.refresh(tracksProvider(trackId: widget.id)),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(), // add this line
        slivers: [
          MeditoAppBarLarge(
            coverUrl: trackModel.coverUrl,
            title: trackModel.title,
            scrollController: _scrollController,
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                if (trackModel.description.isNotNullAndNotEmpty())
                  DescriptionWidget(description: trackModel.description),
                _mainContent(
                  context,
                  trackModel,
                ),
                BottomPaddingWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _mainContent(BuildContext context, TrackModel trackModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          height8,
          _getSubTitle(context, trackModel.subtitle),
          height16,
          TrackButtonsWidget(
            trackModel: trackModel,
          ),
        ],
      ),
    );
  }

  Widget _getSubTitle(BuildContext context, String? subTitle) {
    if (subTitle != null) {
      return Column(
        children: [
          height16,
          Text(
            subTitle,
            style: Theme.of(context)
                .primaryTextTheme
                .bodyLarge
                ?.copyWith(color: ColorConstants.graphite, fontFamily: DmSans),
          ),
        ],
      );
    }

    return SizedBox();
  }

  @override
  bool get wantKeepAlive => true;
}
