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
import 'package:flutter/services.dart';
import 'package:medito/services/watch_download_service.dart';
import 'package:medito/views/downloads/widgets/download_list_item.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bottom_navigation/bottom_navigation_bar_view.dart';
import '../empty_widget.dart';
import '../player/player_view.dart';

class DownloadsView extends ConsumerStatefulWidget {
  const DownloadsView({super.key, this.isRoot = false});

  final bool isRoot;

  @override
  ConsumerState<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends ConsumerState<DownloadsView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _onWatch = false;
  bool _selecting = false;
  bool _sendingSelection = false;
  final _selected = <String>{};
  final _sendingIds = <String>{};
  var scaffoldKey = GlobalKey<ScaffoldState>();

  /// Matches the snackbar's display time, so Undo works while it's visible.
  static const _undoWindow = Duration(seconds: 4);
  _PendingDelete? _pendingDelete;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final downloadedTracks = ref.watch(downloadedTracksProvider);
    final watch = ref.watch(watchDownloadsProvider);
    final available = watch.value?.available ?? false;

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
        actions: [
          if (available &&
              !_onWatch &&
              (downloadedTracks.value?.any(_canSendToWatch) ?? false))
            TextButton(
              onPressed: _sendingSelection
                  ? null
                  : () => setState(() {
                      _selecting = !_selecting;
                      _selected.clear();
                    }),
              child: Text(
                _selecting
                    ? AppLocalizations.of(context)!.cancel
                    : AppLocalizations.of(context)!.selectSessions,
              ),
            ),
        ],
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _downloadTab(
                      false,
                      AppLocalizations.of(context)!.onPhone,
                    ),
                  ),
                  Expanded(
                    child: _downloadTab(
                      true,
                      AppLocalizations.of(context)!.onWatch,
                    ),
                  ),
                ],
              ),
            ),
            if (_selecting)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty || _sendingSelection
                      ? null
                      : () => _sendSelection(downloadedTracks.value ?? []),
                  icon: _sendingSelection
                      ? _loadingIndicator()
                      : const Icon(Icons.watch_outlined),
                  label: Text(
                    _sendingSelection
                        ? AppLocalizations.of(context)!.sendingToWatch
                        : AppLocalizations.of(context)!.sendToWatch,
                  ),
                ),
              ),
            Expanded(
              child: _onWatch
                  ? _watchList(watch)
                  : downloadedTracks.when(
                      skipLoadingOnRefresh: false,
                      data: (data) {
                        if (data.isEmpty) {
                          return _getEmptyWidget();
                        }

                        return _getDownloadList(data);
                      },
                      error: (err, stack) {
                        final error = err is AppError
                            ? err
                            : const UnknownError();

                        return MeditoErrorWidget(
                          error: error,
                          onTap: () => ref.refresh(downloadedTracksProvider),
                        );
                      },
                      loading: () => const DownloadListShimmer(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadTab(bool onWatch, String label) {
    final theme = Theme.of(context);
    final selected = _onWatch == onWatch;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: _sendingSelection
            ? null
            : () => setState(() {
                _onWatch = onWatch;
                _selecting = false;
                _selected.clear();
              }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: theme.colorScheme.onSurface.withValues(
                alpha: selected ? 1 : 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingIndicator() => SizedBox.square(
    dimension: 14,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );

  Widget _transferStatus(
    String label, {
    bool busy = false,
    bool waiting = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (busy || waiting) ...[
            if (busy)
              _loadingIndicator()
            else
              Icon(
                Icons.schedule,
                size: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 20, top: 8),
        child: Row(
          children: [
            Icon(
              Icons.offline_pin_outlined,
              size: 20,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.tracks,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${visible.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
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

  Widget _getEmptyWidget() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.download_rounded,
              size: 36,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.emptyDownloadsMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    ),
  );

  String _fileId(Track track) => track.voices.first.audioFiles.first.id;

  Widget _getSlidingItem(Track item, int index) {
    return Padding(
      key: ValueKey('${item.id}-${_fileId(item)}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        // Stable across rebuilds so an undone row slots straight back in.
        key: ValueKey('${item.id}-${_fileId(item)}'),
        direction: _selecting
            ? DismissDirection.none
            : DismissDirection.endToStart,
        background: _getDismissibleBackgroundWidget(),
        onDismissed: (_) => _removeWithUndo(item),
        child: Material(
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          // Swipe-to-delete is unreachable with a screen reader; offer the
          // same delete (with undo) as an action on the row. Swipe is off
          // while selecting, so the action is too.
          child: Semantics(
            customSemanticsActions: _selecting
                ? null
                : {
                    CustomSemanticsAction(
                      label: AppLocalizations.of(context)!.deleteDownload,
                    ): () =>
                        _removeWithUndo(item),
                  },
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () =>
                  _selecting ? _toggleSelection(item) : _openPlayer(ref, item),
              child: _getListItemWidget(item, index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getDismissibleBackgroundWidget() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(20),
      ),
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
    var subTitle = _sessionSubtitle(guideName, duration);

    final l10n = AppLocalizations.of(context)!;
    final watch = ref.watch(watchDownloadsProvider).value;
    final entry = watch?.items
        .where((e) => e['fileId'] == firstFile.id)
        .firstOrNull;
    return DownloadListItemWidget(
      title: item.title,
      subtitle: subTitle,
      coverUrl: item.coverUrl,
      index: index,
      showReorder: !_selecting,
      status: _sendingIds.contains(_fileId(item))
          ? _transferStatus(l10n.checkingWatch, busy: true)
          : entry == null
          ? null
          : _transferStatus(
              _watchStatus(entry),
              busy: entry['state'] == 'sending' || entry['state'] == 'removing',
              waiting: entry['state'] == 'queued',
            ),
      trailing: _selecting
          ? Checkbox(
              value: _selected.contains(_fileId(item)),
              onChanged: _sendingSelection || !_canSendToWatch(item)
                  ? null
                  : (_) => _toggleSelection(item),
            )
          : _sendingIds.contains(_fileId(item)) || entry?['state'] == 'removing'
          ? const SizedBox(width: 48)
          : watch?.available == true
          ? PopupMenuButton<String>(
              tooltip: l10n.onWatch,
              onSelected: (action) => action == 'send'
                  ? _sendToWatch(item)
                  : _removeFromWatch(entry!),
              itemBuilder: (_) => [
                if (entry == null || entry['state'] == 'failed')
                  PopupMenuItem(
                    value: 'send',
                    child: Text(entry == null ? l10n.sendToWatch : l10n.retry),
                  ),
                if (entry != null)
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      entry['state'] == 'queued' || entry['state'] == 'sending'
                          ? l10n.cancelWatchTransfer
                          : l10n.removeFromWatch,
                    ),
                  ),
              ],
            )
          : null,
    );
  }

  bool _canSendToWatch(Track track) {
    final id = _fileId(track);
    if (_sendingIds.contains(id)) return false;
    final entry = ref
        .read(watchDownloadsProvider)
        .value
        ?.items
        .where((item) => item['fileId'] == id)
        .firstOrNull;
    return entry == null || entry['state'] == 'failed';
  }

  void _toggleSelection(Track track) {
    if (_sendingSelection || !_canSendToWatch(track)) return;
    setState(() {
      final id = _fileId(track);
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _sendSelection(List<Track> tracks) async {
    setState(() => _sendingSelection = true);
    final service = ref.read(watchDownloadServiceProvider);
    try {
      for (final track in tracks.where(
        (t) => _selected.contains(_fileId(t)) && _canSendToWatch(t),
      )) {
        await service.send(track);
      }
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _selected.clear();
        _onWatch = true;
      });
    } catch (error) {
      if (mounted) {
        showSnackBar(context, _transferError(error));
      }
    } finally {
      if (mounted) setState(() => _sendingSelection = false);
    }
  }

  Future<void> _sendToWatch(Track track) async {
    final id = _fileId(track);
    if (_sendingIds.contains(id)) return;
    setState(() => _sendingIds.add(id));
    try {
      await ref.read(watchDownloadServiceProvider).send(track);
      if (!mounted) return;
      setState(() => _onWatch = true);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showSnackBar(
        context,
        _transferError(e),
        actionLabel: e is PlatformException && e.code == 'storage_full'
            ? l10n.onWatch
            : null,
        onActionPressed: e is PlatformException && e.code == 'storage_full'
            ? () => setState(() => _onWatch = true)
            : null,
      );
    } finally {
      if (mounted) setState(() => _sendingIds.remove(id));
    }
  }

  Future<void> _removeFromWatch(Map<String, dynamic> item) async {
    try {
      await ref.read(watchDownloadServiceProvider).remove(item);
    } catch (_) {
      if (mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.watchStatusUnavailable,
        );
      }
    }
  }

  Widget _watchList(AsyncValue<WatchDownloads> watch) {
    final l10n = AppLocalizations.of(context)!;
    return watch.when(
      skipLoadingOnRefresh: true,
      loading: () => Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _loadingIndicator(),
            const SizedBox(width: 8),
            Text(
              l10n.checkingWatch,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(watchDownloadsProvider),
          child: Text(l10n.watchStatusUnavailable),
        ),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return EmptyStateWidget(
            message: data.available
                ? l10n.emptyWatchDownloads
                : l10n.noWatchConnected,
          );
        }
        return Column(
          children: [
            if (!data.available)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  l10n.noWatchConnected,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: data.items.length,
                itemBuilder: (context, index) {
                  final item = data.items[index];
                  final state = item['state'];
                  final checking = _sendingIds.contains(item['fileId']);
                  final status = checking
                      ? l10n.checkingWatch
                      : _watchStatus(item);
                  final source = ref
                      .watch(downloadedTracksProvider)
                      .value
                      ?.where(
                        (track) =>
                            track.voices.first.audioFiles.first.id ==
                            item['fileId'],
                      )
                      .firstOrNull;
                  final progress = (item['progress'] as num?)?.toDouble();
                  return DownloadListItemWidget(
                    index: index,
                    showReorder: false,
                    title: item['title'] as String? ?? '',
                    coverUrl: item['coverUrl'] as String? ?? '',
                    subtitle: _sessionSubtitle(
                      item['guide'] as String?,
                      formatTrackLength(
                        ((item['durationMs'] as num? ?? 0) / 60000)
                            .round()
                            .toString(),
                      ),
                    ),
                    status: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _transferStatus(
                          status,
                          busy:
                              checking ||
                              state == 'sending' ||
                              state == 'removing',
                          waiting: !checking && state == 'queued',
                        ),
                        if (!checking && state == 'sending')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(
                              value: progress != null && progress > 0
                                  ? progress
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    trailing: checking || state == 'removing'
                        ? const SizedBox(width: 48)
                        : PopupMenuButton<String>(
                            onSelected: (action) => action == 'retry'
                                ? _sendToWatch(source!)
                                : _removeFromWatch(item),
                            itemBuilder: (_) => [
                              if (state == 'failed' && source != null)
                                PopupMenuItem(
                                  value: 'retry',
                                  child: Text(l10n.retry),
                                ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  state == 'queued' || state == 'sending'
                                      ? l10n.cancelWatchTransfer
                                      : l10n.removeFromWatch,
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _watchStatus(Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    return switch (item['state']) {
      'ready' => l10n.readyOnWatch,
      'sending' => l10n.sendingToWatch,
      'removing' => l10n.watchRemovalPending,
      'failed' =>
        item['error'] == 'simulator_transfer_unavailable'
            ? l10n.watchSimulatorTransferUnavailable
            : item['error'] == 'storage_full'
            ? l10n.watchStorageFull
            : l10n.watchTransferFailed,
      _ => l10n.waitingForWatch,
    };
  }

  String _sessionSubtitle(String? guide, String duration) {
    final name = guide?.trim();
    return name == null || name.isEmpty || name.toLowerCase() == 'none'
        ? duration
        : '$name — $duration';
  }

  String _transferError(Object error) {
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      PlatformException(code: 'storage_full') => l10n.watchStorageFull,
      PlatformException(code: 'simulator_transfer_unavailable') =>
        l10n.watchSimulatorTransferUnavailable,
      _ => l10n.watchTransferFailed,
    };
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
