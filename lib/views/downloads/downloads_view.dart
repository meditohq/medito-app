import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/duration_extensions.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/downloads/widgets/download_list_item.dart';
import 'package:Medito/views/empty_widget.dart';
import 'package:Medito/widgets/headers/medito_app_bar_small.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DownloadsView extends ConsumerStatefulWidget {
  @override
  ConsumerState<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends ConsumerState<DownloadsView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final key = GlobalKey<AnimatedListState>();
  var scaffoldKey = GlobalKey<ScaffoldState>();
  List<TrackModel> downloadedTracks = [];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final downloadedTracks = ref.watch(downloadedTracksProvider);

    return Scaffold(
      appBar: MeditoAppBarSmall(
        title: StringConstants.downloads,
        closePressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            ref.read(refreshHomeAPIsProvider.future);
            context.go(RouteConstants.homePath);
          }
        },
        isTransparent: true,
        hasCloseButton: true,
      ),
      key: scaffoldKey,
      body: downloadedTracks.when(
        skipLoadingOnRefresh: false,
        data: (data) {
          if (data.isEmpty) {
            return _getEmptyWidget();
          }

          return _getDownloadList(data);
        },
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(downloadedTracksProvider),
        ),
        loading: () => TrackShimmerWidget(),
      ),
    );
  }

  ReorderableListView _getDownloadList(List<TrackModel> tracks) {
    // In order for the Dismissible action still to work on the list items,
    // the default ReorderableListView is used (instead of the .builder one)
    return ReorderableListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          var reorderedItem = tracks.removeAt(oldIndex);
          tracks.insert(newIndex, reorderedItem);
          // To ensure, that the new list order is saved
          ref.read(
            addTrackListInPreferenceProvider(tracks: tracks),
          );
        });
      },
      children: tracks.map((item) => _getSlidingItem(item)).toList(),
    );
  }

  Widget _getEmptyWidget() => EmptyStateWidget(
        message: StringConstants.emptyDownloadsMessage,
      );

  Widget _getSlidingItem(TrackModel item) {
    return InkWell(
      // This (additional) key is required in order for the ReorderableListView to distinguish between the different list items
      key: ValueKey('${item.id}-${item.audio.first.files.first.id}'),
      onTap: () {
        _openPlayer(ref, item);
      },
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.endToStart,
        background: _getDismissibleBackgroundWidget(),
        onDismissed: (direction) => _handleDismissable(direction, item),
        child: _getListItemWidget(item),
      ),
    );
  }

  Widget _getDismissibleBackgroundWidget() => Container(
        color: ColorConstants.charcoal,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Spacer(),
              Icon(
                Icons.delete,
                color: Colors.redAccent,
              ),
            ],
          ),
        ),
      );

  DownloadListItemWidget _getListItemWidget(TrackModel item) {
    var audioLength =
        Duration(milliseconds: item.audio.first.files.first.duration)
            .inMinutes
            .toString();
    var guideName = item.audio.first.guideName;
    var duration = _getDuration(audioLength);
    var subTitle = guideName != null ? '$guideName — $duration' : '$duration';

    return DownloadListItemWidget(
      PackImageListItemData(
        title: item.title,
        subtitle: subTitle,
        cover: item.coverUrl,
        coverSize: 70,
      ),
    );
  }

  String _getDuration(String? length) => formatTrackLength(length);

  void _openPlayer(
    WidgetRef ref,
    TrackModel trackModel,
  ) async {
    final audioProvider = ref.read(audioPlayerNotifierProvider);
    await audioProvider.stop();
    await ref.read(playerProvider.notifier).loadSelectedTrack(
          trackModel: trackModel,
          file: trackModel.audio.first.files.first,
        );
    unawaited(context.push(RouteConstants.playerPath));
  }

  void _handleDismissable(DismissDirection _, TrackModel item) {
    if (mounted) {
      ref.read(removeDownloadedTrackProvider(track: item));
    }
    createSnackBar(
      '"${item.title}" ${StringConstants.removed.toLowerCase()}',
      context,
      color: ColorConstants.walterWhite,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
