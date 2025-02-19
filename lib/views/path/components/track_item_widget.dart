import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/views/player/player_view.dart';

class TrackItemWidget extends ConsumerStatefulWidget {
  final PackItemsModel item;
  final int index;
  final bool isFirstUncompleted;

  const TrackItemWidget({
    required super.key,
    required this.item,
    required this.index,
    required this.isFirstUncompleted,
  });

  @override
  ConsumerState<TrackItemWidget> createState() => _TrackItemWidgetState();
}

class _TrackItemWidgetState extends ConsumerState<TrackItemWidget> {
  bool _isPressed = false;

  Future<void> handleItemTap(BuildContext context, WidgetRef ref) async {
    final guideNameAsync = ref.read(guideNamePreferenceProvider);
    final preferredDuration = ref.read(durationPreferenceProvider);
    final trackId = widget.item.id;
    final cachedTrack = ref.read(playerProvider);

    await PermissionHandler.requestMediaPlaybackPermission(context);

    TrackModel? trackState;

    if (cachedTrack?.id == trackId) {
      trackState = cachedTrack?.copyWith(title: widget.item.title);
    } else {
      trackState = await ref.read(tracksProvider(trackId: trackId).future);
    }

    final selectedAudio = _selectBestAudioMatch(
      trackState?.audio ?? [],
      guideName: guideNameAsync.value,
      preferredDuration: preferredDuration,
    );

    if (selectedAudio != null && trackState != null) {
      await ref.read(playerProvider.notifier).loadSelectedTrack(
            trackModel: trackState,
            file: selectedAudio.files.first,
          );
      _navigateToPlayer(context, ref);
    }
  }

  void _navigateToPlayer(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlayerView()),
    ).then((value) => ref.invalidate(packProvider));
  }

  TrackAudioModel? _selectBestAudioMatch(
    List<TrackAudioModel> audioList, {
    String? guideName,
    int? preferredDuration,
  }) {
    if (audioList.isEmpty) return null;

    List<TrackAudioModel> filtered = guideName != null
        ? audioList.where((a) => a.guideName == guideName).toList()
        : audioList;

    if (filtered.isEmpty) filtered = audioList;

    TrackAudioModel? closest;
    int? closestDiff;

    for (final audio in filtered) {
      final duration = audio.files.first.duration;
      final diff = (preferredDuration ?? duration) - duration;

      if (closest == null || diff.abs() < closestDiff!) {
        closest = audio;
        closestDiff = diff.abs();
      }
    }

    return closest ?? audioList.first;
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.item.isCompleted ?? false;
    final backgroundColor = isCompleted
        ? ColorConstants.lightPurple
        : widget.isFirstUncompleted
            ? ColorConstants.amber
            : Colors.grey[800];
    final effectiveColor =
        _isPressed ? backgroundColor?.withValues(alpha: 0.8) : backgroundColor;
    final textColor = (isCompleted || widget.isFirstUncompleted)
        ? Colors.white
        : Colors.grey[300];
    final text =
        (isCompleted || widget.isFirstUncompleted) ? widget.item.title : '';
    final locked = !isCompleted && !widget.isFirstUncompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => locked ? null : handleItemTap(context, ref),
        onTapDown: locked ? null : (_) => setState(() => _isPressed = true),
        onTapUp: locked ? null : (_) => setState(() => _isPressed = false),
        onTapCancel: locked ? null : () => setState(() => _isPressed = false),
        child: Container(
          width: locked ? 64 : 200,
          height: 64,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(8),
            border: widget.isFirstUncompleted
                ? Border.all(color: ColorConstants.white, width: 0.5)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: locked
                      ? const EdgeInsets.only(left: 0)
                      : const EdgeInsets.only(left: 8),
                  child: locked
                      ? HugeIcon(
                          icon: HugeIcons.strokeRoundedSquareLock02,
                          color: Colors.white,
                          size: 24,
                        )
                      : Text(
                          text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              if (isCompleted)
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: HugeIcon(
                    icon: HugeIcons.strokeStandardTick02,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
