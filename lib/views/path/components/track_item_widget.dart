// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/widgets/medito_icon.dart';

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
    final guideName = ref.read(guideNamePreferenceProvider);
    final preferredDuration = ref.read(durationPreferenceProvider);

    final track =
        await ref.read(tracksProvider(trackId: widget.item.id).future);
    final selection = TrackVariantSelector.resolve(
      track,
      guideName: guideName,
      durationMs: preferredDuration,
    );

    final request =
        PlaybackRequest.fromTrack(track, selection.voice, selection.file);
    await ref.read(playerProvider.notifier).play(request);
    _navigateToPlayer(context);
  }

  void _navigateToPlayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlayerView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.item.isCompleted ?? false;
    final backgroundColor = isCompleted
        ? context.brandPurple
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

    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: locked ? l10n.lockedContent : widget.item.title,
        button: !locked,
        enabled: !locked,
        child: GestureDetector(
        onTap: locked ? null : () => handleItemTap(context, ref),
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
                      ? MeditoIcon(
                          assetName: MeditoIcons.privacy,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        )
                      : Text(
                          text,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  child: MeditoIcon(
                    assetName: MeditoIcons.check,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
