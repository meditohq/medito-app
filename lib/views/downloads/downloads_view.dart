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
  List<Track> downloadedTracks = [];

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

  ReorderableListView _getDownloadList(List<Track> tracks) {
    return ReorderableListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      onReorderItem: (int oldIndex, int newIndex) {
        setState(() {
          var reorderedItem = tracks.removeAt(oldIndex);
          tracks.insert(newIndex, reorderedItem);
          ref.read(addTrackListInPreferenceProvider(tracks: tracks));
        });
      },
      children: tracks.map((item) => _getSlidingItem(item)).toList(),
    );
  }

  Widget _getEmptyWidget() => EmptyStateWidget(
    message: AppLocalizations.of(context)!.emptyDownloadsMessage,
  );

  Widget _getSlidingItem(Track item) {
    final firstFile = item.voices.first.audioFiles.first;
    return InkWell(
      key: ValueKey('${item.id}-${firstFile.id}'),
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

  DownloadListItemWidget _getListItemWidget(Track item) {
    final firstVoice = item.voices.first;
    final firstFile = firstVoice.audioFiles.first;
    var audioLength = Duration(
      milliseconds: firstFile.duration,
    ).inMinutes.toString();
    var guideName = firstVoice.guideName;
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

  void _openPlayer(WidgetRef ref, Track track) async {
    final voice = track.voices.first;
    final file = voice.audioFiles.first;
    final request = PlaybackRequest.fromTrack(track, voice, file);
    await ref.read(playerProvider.notifier).play(request);
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlayerView()),
      ),
    );
  }

  void _handleDismissible(DismissDirection _, Track item) async {
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
      ref.invalidate(downloadedTracksProvider);
    }
  }

  Future<void> _deleteDownload(Track item) async {
    final firstFile = item.voices.first.audioFiles.first;
    final fileName =
        '${item.id}-${firstFile.id}${getAudioFileExtension(firstFile.path)}';

    final isDownloaded = await ref
        .read(downloaderRepositoryProvider)
        .isFileDownloaded(fileName);
    if (isDownloaded) {
      await ref
          .read(audioDownloaderProvider.notifier)
          .deleteTrackAudio(fileName);
    }

    final trackList = await ref
        .read(trackRepositoryProvider)
        .fetchTrackFromPreference();
    trackList.removeWhere(
      (t) => t.voices.first.audioFiles.any((f) => f.id == firstFile.id),
    );
    await ref.read(trackRepositoryProvider).addTrackInPreference(trackList);

    ref.invalidate(downloadedTracksProvider);
  }

  @override
  bool get wantKeepAlive => true;
}
