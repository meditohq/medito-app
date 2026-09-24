import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/views/player/start_session.dart';
import 'package:medito/widgets/snackbar_widget.dart';

/// Your Path control on the pack screen, built to get people into their next
/// session in one tap.
///
/// - Not Your Path: a "Show on Home" button that makes this pack Your Path.
///   It does only that — playing is the status row's job, one tap later.
/// - Your Path: a status row ("Your Path · 1 of 23", "Next: …") whose tap
///   plays that next session; the ⋯ button holds the explainer and Remove.
///
/// Only one pack can be Your Path at a time; setting a new one replaces the
/// previous. Hidden for packs that contain sub-packs and for the favourites
/// pseudo-pack: Up Next walks a flat list of tracks.
class PackPathButton extends ConsumerStatefulWidget {
  const PackPathButton({super.key, required this.pack});

  final PackModel pack;

  static const _favoritesPackId = 'favorites';

  @override
  ConsumerState<PackPathButton> createState() => _PackPathButtonState();
}

class _PackPathButtonState extends ConsumerState<PackPathButton> {
  bool _starting = false;

  PackModel get pack => widget.pack;

  @override
  Widget build(BuildContext context) {
    final trackItems = pack.items
        .where((item) => item.type == TypeConstants.track)
        .toList();
    final onlyTracks = trackItems.length == pack.items.length;
    if (trackItems.isEmpty ||
        !onlyTracks ||
        pack.id == PackPathButton._favoritesPackId) {
      return const SizedBox.shrink();
    }

    final isCurrent = ref.watch(upNextPackIdProvider) == pack.id;
    final completed = trackItems
        .where((item) => item.isCompleted == true)
        .length;
    // Same rule as upNextProvider, so this plays what Home would.
    final next = trackItems
        .where((item) => item.isCompleted != true)
        .firstOrNull;

    // Lives inside the description block (cardColor), separated from the
    // text by a hairline: part of the pack's header, not a row in the list.
    return Column(
      children: [
        Divider(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
          thickness: 0.5,
          height: 0.5,
        ),
        isCurrent
            ? _statusRow(context, next, completed, trackItems.length)
            : _showOnHomeButton(context),
      ],
    );
  }

  Widget _showOnHomeButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // Tonal, not filled: this is a shortcut, so it sits inside the header
    // rather than out-shouting the track list. Same 64px as the status row
    // so the header doesn't jump when it flips.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: FilledButton.icon(
        onPressed: () => _setAsPath(context, ref),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: onSurface.withValues(alpha: 0.08),
          disabledBackgroundColor: onSurface.withValues(alpha: 0.08),
          foregroundColor: onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: theme.textTheme.bodyLarge?.copyWith(
            fontFamily: googleSans,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: const Icon(Icons.home_outlined, size: 22),
        label: Text(l10n.showOnHome),
      ),
    );
  }

  Widget _statusRow(
    BuildContext context,
    PackItemsModel? next,
    int completed,
    int total,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final title = l10n.yourPathStatusTitle(completed, total);
    final subtitle = next != null
        ? l10n.yourPathNextSession(next.title)
        : l10n.yourPathAllDone;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: next != null
              ? () => _play(context, next)
              : () => _showCurrentSheet(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 4, 8),
            child: Row(
              children: [
                // Play, not a tick: a check here read as "pack completed"
                // right above the track completion ticks.
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: next != null
                        ? context.brandPurple
                        : onSurface.withValues(alpha: 0.08),
                  ),
                  alignment: Alignment.center,
                  child: _starting
                      ? SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.onBrandPurple,
                          ),
                        )
                      : Icon(
                          next != null
                              ? Icons.play_arrow_rounded
                              : Icons.route_outlined,
                          size: 20,
                          color: next != null
                              ? context.onBrandPurple
                              : onSurface,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontFamily: googleSans,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: googleSans,
                          fontSize: 12,
                          color: onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showCurrentSheet(context),
                  tooltip: l10n.yourPathOptions,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _play(BuildContext context, PackItemsModel next) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await startSession(context, ref, trackId: next.id, path: next.path);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _setAsPath(BuildContext context, WidgetRef ref) async {
    final previousId = ref.read(upNextPackIdProvider);

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.packPinned,
            parameters: {
              AnalyticsEventConstants.paramPackId: pack.id,
              AnalyticsEventConstants.paramPreviousPackId: previousId,
            },
          ),
    );

    // Only one pack can be Your Path, so this replaces the previous one —
    // progress lives in stats, so nothing is lost. Replacing is the surprising
    // part (Home stops showing what you were doing), so the snackbar names the
    // old pack and offers Undo.
    final prefs = ref.read(sharedPreferencesProvider);
    // Null when Home was on the default pack without an explicit choice; Undo
    // restores exactly that.
    final previousRaw = prefs.getString(SharedPreferenceConstants.upNextPackId);
    final previousTitle = previousId == pack.id
        ? null
        : ref.read(packProvider(packId: previousId)).value?.title;
    // Container, not ref: Undo can be tapped after leaving this screen.
    final container = ProviderScope.containerOf(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    await prefs.setString(SharedPreferenceConstants.upNextPackId, pack.id);
    ref.invalidate(upNextPackIdProvider);

    if (previousId == pack.id) return;
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    showSnackBar(
      context.mounted ? context : null,
      previousTitle != null
          ? l10n.showOnHomeReplaced(pack.title, previousTitle)
          : l10n.showOnHomeDone(pack.title),
      actionLabel: l10n.undo,
      onActionPressed: () async {
        if (previousRaw == null) {
          await prefs.remove(SharedPreferenceConstants.upNextPackId);
        } else {
          await prefs.setString(
            SharedPreferenceConstants.upNextPackId,
            previousRaw,
          );
        }
        container.invalidate(upNextPackIdProvider);
      },
    );
  }

  Future<void> _removeFromPath(WidgetRef ref) async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.packUnpinned,
            parameters: {AnalyticsEventConstants.paramPackId: pack.id},
          ),
    );

    // Removing falls back to the default pack (see upNextPackIdProvider).
    await ref
        .read(sharedPreferencesProvider)
        .remove(SharedPreferenceConstants.upNextPackId);
    ref.invalidate(upNextPackIdProvider);
  }

  void _showCurrentSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDefaultPack = pack.id == ConfigConstants.basicsPackId;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.bottomSheetTheme.backgroundColor,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.yourPathSheetTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isDefaultPack
                    ? l10n.yourPathDefaultNote
                    : l10n.yourPathSheetBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (!isDefaultPack) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _removeFromPath(ref);
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: theme.colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: ColorConstants.charcoal),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: Text(l10n.removeFromYourPath),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
