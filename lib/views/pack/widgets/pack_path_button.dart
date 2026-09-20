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

/// Full-width "Set as Your Path" button on the pack screen.
///
/// Replaces the old pin icon in the bottom action bar, which read as a second
/// favourite. Only one pack can be Your Path at a time; setting a new one
/// replaces the previous, and the snackbar says so.
///
/// Hidden for packs that contain sub-packs and for the favourites pseudo-pack:
/// Up Next walks a flat list of tracks.
class PackPathButton extends ConsumerWidget {
  const PackPathButton({super.key, required this.pack});

  final PackModel pack;

  static const _favoritesPackId = 'favorites';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackItems = pack.items
        .where((item) => item.type == TypeConstants.track)
        .toList();
    final onlyTracks = trackItems.length == pack.items.length;
    if (trackItems.isEmpty || !onlyTracks || pack.id == _favoritesPackId) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final isCurrent = ref.watch(upNextPackIdProvider) == pack.id;

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final completed = trackItems
        .where((item) => item.isCompleted == true)
        .length;

    final title = isCurrent ? l10n.upNextTitle : l10n.setAsYourPath;
    final subtitle = isCurrent
        ? l10n.yourPathRowSubtitle(completed, trackItems.length)
        : l10n.setAsYourPathSubtitle;

    // Lives inside the description block (cardColor), separated from the
    // text by a hairline: part of the pack's header, not a row in the list.
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => isCurrent
              ? _showCurrentSheet(context, ref)
              : _setAsPath(context, ref),
          child: Column(
            children: [
              Divider(
                color: onSurface.withValues(alpha: 0.08),
                thickness: 0.5,
                height: 0.5,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? context.brandPurple
                            : onSurface.withValues(alpha: 0.08),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isCurrent ? Icons.check_rounded : Icons.route_outlined,
                        size: 17,
                        color: isCurrent ? context.onBrandPurple : onSurface,
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
                              fontFamily: dmSans,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: dmSans,
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: onSurface.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    // The row flipping to its "Your Path" state is the confirmation; no
    // snackbar. Only one pack can be Your Path, so this replaces the previous
    // one — progress lives in stats, so nothing is lost.
    await ref
        .read(sharedPreferencesProvider)
        .setString(SharedPreferenceConstants.upNextPackId, pack.id);
    ref.invalidate(upNextPackIdProvider);
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

  void _showCurrentSheet(BuildContext context, WidgetRef ref) {
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
