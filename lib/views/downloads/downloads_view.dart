// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/utils/duration_extensions.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/downloads/widgets/download_list_item.dart';
import 'package:medito/views/empty_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_icon.dart';

import '../../utils/permission_handler.dart';
import '../bottom_navigation/bottom_navigation_bar_view.dart';
import '../player/player_view.dart';

class DownloadsView extends ConsumerStatefulWidget {
  const DownloadsView({super.key, this.isRoot = false});

  final bool isRoot;

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
      bottomNavigationBar: widget.isRoot
          ? null
          : SingleBackButtonActionBar(
              onBackPressed: () {
                Navigator.pop(context);
              },
            ),
      appBar: MeditoAppBarSmall(
        title: AppLocalizations.of(context)!.downloads,
        closePressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            ref.read(refreshHomeAPIsProvider.future);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const BottomNavigationBarView(),
              ),
            );
          }
        },
        isTransparent: true,
        hasCloseButton: !widget.isRoot,
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
        error: (err, stack) {
          final error = err is AppError ? err : const UnknownError();

          return MeditoErrorWidget(
            error: error,
            onTap: () => ref.refresh(downloadedTracksProvider),
          );
        },
        loading: () => const TrackShimmerWidget(),
      ),
    );
  }

  ReorderableListView _getDownloadList(List<TrackModel> tracks) {
    // In order for the Dismissible action still to work on the list items,
    // the default ReorderableListView is used (instead of the .builder one)
    return ReorderableListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
        message: AppLocalizations.of(context)!.emptyDownloadsMessage,
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
        onDismissed: (direction) => _handleDismissible(direction, item),
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
              const Spacer(),
              const MeditoIcon(
                assetName: MeditoIcons.xmark,
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
    var subTitle = guideName != null ? '$guideName — $duration' : duration;
    var imageUrl = item.coverUrl;

    return DownloadListItemWidget(
      PackImageListItemData(
        title: item.title,
        subtitle: subTitle,
        cover: imageUrl,
        coverSize: 70,
      ),
    );
  }

  String _getDuration(String? length) => formatTrackLength(length);

  void _openPlayer(
    WidgetRef ref,
    TrackModel trackModel,
  ) async {
    await PermissionHandler.requestMediaPlaybackPermission(context);

    await ref.read(playerProvider.notifier).loadSelectedTrack(
          trackModel: trackModel,
          file: trackModel.audio.first.files.first,
        );
    unawaited(Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlayerView(),
      ),
    ));
  }

  void _handleDismissible(DismissDirection _, TrackModel item) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return MeditoDialog(
          title: AppLocalizations.of(context)!.confirmDeletionTitle,
          content: MeditoDialogBody(
            '${AppLocalizations.of(context)!.confirmDeletionMessage} ${item.title}?',
          ),
          actions: [
            MeditoDialogSecondaryButton(
              label: AppLocalizations.of(context)!.cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            MeditoDialogDestructiveButton(
              label: AppLocalizations.of(context)!.delete,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      if (mounted) {
        await _deleteDownload(item);
      }
      showSnackBar(
        context,
        '"${item.title}" ${AppLocalizations.of(context)!.removed.toLowerCase()}',
        backgroundColor: ColorConstants.white,
      );
    } else {
      // If the user cancels, refresh the list to ensure all items are visible again.
      ref.invalidate(downloadedTracksProvider);
    }
  }

  Future<void> _deleteDownload(TrackModel item) async {
    final firstItem = item.audio.first.files.first;
    final fileName =
        '${item.id}-${firstItem.id}${getAudioFileExtension(firstItem.path)}';

    final isDownloaded =
        await ref.read(downloaderRepositoryProvider).isFileDownloaded(fileName);
    if (isDownloaded) {
      await ref
          .read(audioDownloaderProvider.notifier)
          .deleteTrackAudio(fileName);
    }

    final trackList =
        await ref.read(trackRepositoryProvider).fetchTrackFromPreference();
    trackList.removeWhere((t) =>
        t.audio.first.files.any((f) => f.id == firstItem.id));
    await ref.read(trackRepositoryProvider).addTrackInPreference(trackList);

    ref.invalidate(downloadedTracksProvider);
  }

  @override
  bool get wantKeepAlive => true;
}
