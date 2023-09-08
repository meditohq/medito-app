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
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/meditation_buttons_widget.dart';

class MeditationView extends ConsumerStatefulWidget {
  final String id;

  MeditationView({Key? key, required this.id}) : super(key: key);
  @override
  ConsumerState<MeditationView> createState() => _MeditationViewState();
}

class _MeditationViewState extends ConsumerState<MeditationView>
    with AutomaticKeepAliveClientMixin<MeditationView> {
  @override
  void initState() {
    _handleTrackEvent(ref, widget.id);
    super.initState();
  }

  void _handleTrackEvent(WidgetRef ref, String meditationId) {
    var meditationViewedModel =
        MeditationViewedModel(meditationId: meditationId);
    var event = EventsModel(
      name: EventTypes.meditationViewed,
      payload: meditationViewedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(meditationOpenedFirstTimeProvider);
    var meditations = ref.watch(meditationsProvider(meditationId: widget.id));
    ref.listen(meditationOpenedFirstTimeProvider, (prev, next) {
      var _user =
          ref.read(authProvider.notifier).userRes.body as UserTokenModel;
      if (_user.email == null && next.value != null && next.value!) {
        context.push(
          RouteConstants.joinIntroPath,
          extra: {'screen': Screen.meditation},
        );
      }
    });

    return Scaffold(
      body: meditations.when(
        skipLoadingOnRefresh: false,
        data: (data) => _buildScaffoldWithData(context, data, ref),
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () =>
              ref.refresh(meditationsProvider(meditationId: widget.id)),
        ),
        loading: () => _buildLoadingWidget(),
      ),
    );
  }

  MeditationShimmerWidget _buildLoadingWidget() =>
      const MeditationShimmerWidget();
  RefreshIndicator _buildScaffoldWithData(
    BuildContext context,
    MeditationModel meditationModel,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async =>
          await ref.refresh(meditationsProvider(meditationId: widget.id)),
      child: Scaffold(
        body: CollapsibleHeaderWidget(
          bgImage: meditationModel.coverUrl,
          title: meditationModel.title,
          description: meditationModel.description,
          selectableTitle: true,
          selectableDescription: true,
          children: [
            _mainContent(context, meditationModel),
          ],
        ),
      ),
    );
  }

  Widget _mainContent(BuildContext context, MeditationModel meditationModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          height8,
          _getSubTitle(context, meditationModel.subtitle),
          height16,
          MeditationButtonsWidget(
            meditationModel: meditationModel,
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
                ?.copyWith(color: ColorConstants.newGrey, fontFamily: DmSans),
          ),
        ],
      );
    }

    return SizedBox();
  }

  @override
  bool get wantKeepAlive => true;
}
