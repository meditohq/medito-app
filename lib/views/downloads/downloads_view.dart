import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/utils/duration_extensions.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/views/downloads/widgets/download_list_item.dart';
import 'package:medito/views/empty_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


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
  var scaffoldKey = GlobalKey<ScaffoldState>();

  /// Matches the snackbar's display time, so Undo works while it's visible.
  static const _undoWindow = Duration(seconds: 4);
  _PendingDelete? _pendingDelete;

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
      body: AdaptivePageBody(
        maxWidth: 760,
        child: downloadedTracks.when(
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
          loading: () => const DownloadListShimmer(),
        ),
      ),
    );
  }

  Widget _getDownloadList(List<Track> tracks) {
    final pending = _pendingDelete;
    final visible = pending == null
        ? tracks
        : tracks.where((t) => _fileId(t) != _fileId(pending.track)).toList();
    if (visible.isEmpty) return _getEmptyWidget();

    return ReorderableListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      buildDefaultDragHandles: false,
      onReorderItem: (int oldIndex, int newIndex) {
        // Saving the order while a removal is pending would drop that track
        // from preferences, leaving nothing for Undo to restore.
        _commitPendingDelete();
        final reordered = List.of(visible);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        ref.read(addTrackListInPreferenceProvider(tracks: reordered));
        ref.invalidate(downloadedTracksProvider);
      },
      children: [
        for (var i = 0; i < visible.length; i++) _getSlidingItem(visible[i], i),
      ],
    );
  }

  Widget _getEmptyWidget() => EmptyStateWidget(
    message: AppLocalizations.of(context)!.emptyDownloadsMessage,
  );

  String _fileId(Track track) => track.voices.first.audioFiles.first.id;

  Widget _getSlidingItem(Track item, int index) {
    return Dismissible(
      // Stable across rebuilds so an undone row slots straight back in.
      key: ValueKey('${item.id}-${_fileId(item)}'),
      direction: DismissDirection.endToStart,
      background: _getDismissibleBackgroundWidget(),
      onDismissed: (_) => _removeWithUndo(item),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPlayer(ref, item),
          child: _getListItemWidget(item, index),
        ),
      ),
    );
  }

  Widget _getDismissibleBackgroundWidget() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(Icons.delete_outline, color: colorScheme.onError),
    );
  }

  DownloadListItemWidget _getListItemWidget(Track item, int index) {
    final firstVoice = item.voices.first;
    final firstFile = firstVoice.audioFiles.first;
    var audioLength = Duration(
      milliseconds: firstFile.duration,
    ).inMinutes.toString();
    var guideName = firstVoice.guideName;
    var duration = _getDuration(audioLength);
    var subTitle = guideName != null ? '$guideName — $duration' : duration;

    return DownloadListItemWidget(
      title: item.title,
      subtitle: subTitle,
      coverUrl: item.coverUrl,
      index: index,
    );
  }

  String _getDuration(String? length) => formatTrackLength(length);

  void _openPlayer(WidgetRef ref, Track track) {
    final voice = track.voices.first;
    final file = voice.audioFiles.first;
    final request = PlaybackRequest.fromTrack(track, voice, file);
    // Prepare + open the player immediately; PlayerView starts playback and
    // shows its own loading state (no wait on this screen).
    ref.read(playerProvider.notifier).prepare(request);
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlayerView()),
      ),
    );
  }

  /// Hides the row at once and offers Undo; the audio file is only deleted
  /// once the snackbar's window has passed. One removal is pending at a time:
  /// a second swipe commits the first.
  void _removeWithUndo(Track item) {
    _commitPendingDelete();
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _pendingDelete = _PendingDelete(
        track: item,
        timer: Timer(_undoWindow, _commitPendingDelete),
        commit: () => _deleteDownload(container, item),
      );
    });

    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    final l10n = AppLocalizations.of(context)!;
    showSnackBar(
      context,
      '"${item.title}" ${l10n.removed.toLowerCase()}',
      actionLabel: l10n.undo,
      onActionPressed: () {
        final pending = _pendingDelete;
        if (pending == null || pending.track != item) return;
        pending.timer.cancel();
        if (mounted) setState(() => _pendingDelete = null);
      },
    );
  }

  void _commitPendingDelete() {
    final pending = _pendingDelete;
    if (pending == null) return;
    pending.timer.cancel();
    _pendingDelete = null;
    if (mounted) setState(() {});
    unawaited(pending.commit());
  }

  // Uses the container rather than ref so a removal still completes if the
  // screen is closed during the undo window.
  static Future<void> _deleteDownload(
    ProviderContainer container,
    Track item,
  ) async {
    final firstFile = item.voices.first.audioFiles.first;
    final fileName =
        '${item.id}-${firstFile.id}${getAudioFileExtension(firstFile.path)}';

    final isDownloaded = await container
        .read(downloaderRepositoryProvider)
        .isFileDownloaded(fileName);
    if (isDownloaded) {
      await container
          .read(audioDownloaderProvider.notifier)
          .deleteTrackAudio(fileName);
    }

    final trackRepository = container.read(trackRepositoryProvider);
    final trackList = await trackRepository.fetchTrackFromPreference();
    trackList.removeWhere(
      (t) => t.voices.first.audioFiles.any((f) => f.id == firstFile.id),
    );
    await trackRepository.addTrackInPreference(trackList);

    container.invalidate(downloadedTracksProvider);
  }

  @override
  void dispose() {
    _commitPendingDelete();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}

class _PendingDelete {
  _PendingDelete({
    required this.track,
    required this.timer,
    required this.commit,
  });

  final Track track;
  final Timer timer;
  final Future<void> Function() commit;
}
