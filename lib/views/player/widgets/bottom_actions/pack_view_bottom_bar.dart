import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/widgets/add_to_siri_util.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:share_plus/share_plus.dart';

import 'animated_favourite_icon.dart';
import 'bottom_action_bar.dart';

class PackViewBottomBar extends ConsumerStatefulWidget {
  final String packId;
  final String packName;
  final VoidCallback onBackPressed;

  const PackViewBottomBar({
    super.key,
    required this.packId,
    required this.packName,
    required this.onBackPressed,
  });

  @override
  ConsumerState<PackViewBottomBar> createState() => _PackViewBottomBarState();
}

class _PackViewBottomBarState extends ConsumerState<PackViewBottomBar> {
  final _favoriteController = FavoriteIconController();

  @override
  void dispose() {
    _favoriteController.dispose();
    super.dispose();
  }

  void _sharePack(BuildContext context) {
    final deepLink = 'https://medito.app/packs/${widget.packId}';
    final shareText = AppLocalizations.of(
      context,
    )!.sharePackText(widget.packName, deepLink);
    SharePlus.instance.share(ShareParams(text: shareText));
  }

  void _showOverflowMenu(BuildContext context, PackModel pack) {
    showModalBottomSheet(
      showDragHandle: true,
      context: context,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (consumerContext, ref, _) {
            final batchState = ref.watch(batchDownloadProvider);
            final downloadedTracks =
                ref.watch(downloadedTracksProvider).asData?.value ?? [];
            final isFullyDownloaded = pack.isFullyDownloaded(downloadedTracks);
            final downloadedCount = pack.downloadedTrackCount(downloadedTracks);
            final isDownloading = batchState.isPackDownloading(widget.packId);
            final l10n = AppLocalizations.of(consumerContext)!;

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pack.canDownloadAll) ...[
                    if (isDownloading) ...[
                      ListTile(
                        leading: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            value: batchState.total > 0
                                ? batchState.completed / batchState.total
                                : null,
                            color: consumerContext.brandAccent,
                          ),
                        ),
                        title: Text(
                          l10n.downloadingPack(
                            batchState.completed,
                            batchState.total,
                          ),
                          style: Theme.of(consumerContext).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(
                                  consumerContext,
                                ).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      _buildBottomSheetTile(
                        consumerContext,
                        iconWidget: Icon(
                          Icons.stop_circle_outlined,
                          color: Theme.of(consumerContext).colorScheme.error,
                          size: 20,
                        ),
                        title: l10n.stopDownloading,
                        textColor: Theme.of(consumerContext).colorScheme.error,
                        onTap: () {
                          ref
                              .read(batchDownloadProvider.notifier)
                              .cancelDownload();
                          Navigator.pop(bottomSheetContext);
                        },
                      ),
                    ] else if (isFullyDownloaded) ...[
                      ListTile(
                        leading: MeditoIcon(
                          assetName: MeditoIcons.checkCircleSolid,
                          color: consumerContext.brandAccent,
                          size: 20,
                        ),
                        title: Text(
                          l10n.allDownloaded,
                          style: Theme.of(consumerContext).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(
                                  consumerContext,
                                ).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      _buildBottomSheetTile(
                        consumerContext,
                        iconWidget: Icon(
                          Icons.delete_outline,
                          color: Theme.of(consumerContext).colorScheme.error,
                          size: 20,
                        ),
                        title: l10n.deletePackDownloads,
                        textColor: Theme.of(consumerContext).colorScheme.error,
                        onTap: () async {
                          Navigator.pop(bottomSheetContext);
                          await ref
                              .read(batchDownloadProvider.notifier)
                              .deletePackDownloads(pack);
                          if (context.mounted) {
                            scaffoldMessengerKey.currentState
                                ?.hideCurrentSnackBar();
                            showSnackBar(context, l10n.packDownloadsDeleted);
                          }
                        },
                      ),
                    ] else ...[
                      _buildBottomSheetTile(
                        consumerContext,
                        iconAsset: MeditoIcons.downloadCircleNew,
                        title: downloadedCount > 0
                            ? l10n.downloadRemaining
                            : l10n.downloadAll,
                        subtitle: downloadedCount > 0
                            ? l10n.packDownloadedCount(
                                downloadedCount,
                                pack.items.length,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          ref
                              .read(batchDownloadProvider.notifier)
                              .startPackDownload(pack);
                        },
                      ),
                    ],
                  ],
                  if (Platform.isIOS)
                    _buildBottomSheetTile(
                      consumerContext,
                      iconAsset: MeditoIcons.siri,
                      title: l10n.addToSiri,
                      onTap: () {
                        addToSiri(
                          title: '${l10n.open} ${widget.packName}',
                          id: widget.packId,
                          url: 'org.meditofoundation://packs/${widget.packId}',
                        );
                        Navigator.pop(bottomSheetContext);
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  ListTile _buildBottomSheetTile(
    BuildContext context, {
    String? iconAsset,
    Widget? iconWidget,
    required String title,
    String? subtitle,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final defaultColor = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading:
          iconWidget ??
          (iconAsset != null
              ? MeditoIcon(
                  assetName: iconAsset,
                  color: textColor ?? defaultColor,
                  size: 20,
                )
              : null),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: textColor ?? defaultColor),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }

  void _toggleFavorite(bool isFavorite, PackModel pack) {
    final notifier = ref.read(favoritesNotifierProvider.notifier);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: isFavorite
                ? AnalyticsEventConstants.packUnfavourited
                : AnalyticsEventConstants.packFavourited,
            parameters: {AnalyticsEventConstants.paramPackId: widget.packId},
          ),
    );
    _favoriteController
        .trigger(
          () => isFavorite
              ? notifier.removeFromFavorites(widget.packId)
              : notifier.addToFavorites(
                  FavoriteItem(
                    id: widget.packId,
                    title: widget.packName,
                    coverUrl: pack.coverUrl,
                    subtitle: pack.subtitle,
                    type: FavoriteItemType.pack,
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  ),
                ),
          direction: isFavorite
              ? FavoriteToggleDirection.remove
              : FavoriteToggleDirection.add,
        )
        .then((_) {
          // The star alone is easy to miss; say what happened.
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          // Replace rather than queue, so a quick re-tap reads the end state.
          scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
          showSnackBar(
            context,
            isFavorite ? l10n.removedFromFavorites : l10n.addedToFavorites,
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final packData = ref.watch(packProvider(packId: widget.packId));
    final favoritesState = ref.watch(favoritesNotifierProvider);
    final batchState = ref.watch(batchDownloadProvider);

    return packData.when(
      data: (pack) {
        final isFavorite = favoritesState.maybeWhen(
          data: (favorites) =>
              favorites.any((item) => item.id == widget.packId),
          orElse: () => false,
        );
        return _buildBottomBar(context, pack, isFavorite, batchState);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    PackModel pack,
    bool isFavorite,
    BatchDownloadState batchState,
  ) {
    final favouriteColour = isFavorite
        ? context.brandAccent
        : Theme.of(context).colorScheme.onSurface;

    final l10n = AppLocalizations.of(context)!;
    final isDownloading = batchState.isPackDownloading(widget.packId);

    return BottomActionBar(
      layout: BottomActionBarLayout.compactRight,
      leftItem: BottomActionBarItem(
        child: MeditoIcon(
          assetName: MeditoIcons.arrowLeft,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: widget.onBackPressed,
        semanticLabel: l10n.goBack,
      ),
      rightCenterItem: BottomActionBarItem(
        child: MeditoIcon(
          assetName: Platform.isIOS
              ? MeditoIcons.shareIos
              : MeditoIcons.shareAndroid,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: () => _sharePack(context),
        semanticLabel: l10n.share,
      ),
      leftCenterItem: BottomActionBarItem(
        child: AnimatedFavouriteIcon(
          isFavorite: isFavorite,
          color: favouriteColour,
          controller: _favoriteController,
        ),
        semanticLabel: isFavorite
            ? l10n.removeFromFavorites
            : l10n.addToFavorites,
        onTap: () => _toggleFavorite(isFavorite, pack),
      ),
      rightItem: !pack.canDownloadAll && !Platform.isIOS
          ? null
          : BottomActionBarItem(
              child: isDownloading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        value: batchState.total > 0
                            ? batchState.completed / batchState.total
                            : null,
                        color: context.brandAccent,
                      ),
                    )
                  : Icon(
                      Icons.more_vert,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              onTap: () => _showOverflowMenu(context, pack),
              semanticLabel: l10n.overflowMenu,
            ),
    );
  }
}
