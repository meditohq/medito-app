import 'package:medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';

import 'package:medito/constants/icons/medito_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/favorites/favorite_item.dart';
import '../../../../models/track/track.dart';
import '../../../../providers/favorites/favorites_provider.dart';
import '../../../../providers/meditation/track_provider.dart';
import '../../../../widgets/add_to_siri_util.dart';
import '../../../../widgets/medito_icon.dart';
import 'animated_favourite_icon.dart';
import 'bottom_action_bar.dart';

class TrackViewBottomBar extends ConsumerStatefulWidget {
  final String trackId;
  final String trackTitle;
  final String? coverUrl;
  final VoidCallback onBackPressed;

  const TrackViewBottomBar({
    super.key,
    required this.trackId,
    required this.trackTitle,
    this.coverUrl,
    required this.onBackPressed,
  });

  @override
  ConsumerState<TrackViewBottomBar> createState() => _TrackViewBottomBarState();
}

class _TrackViewBottomBarState extends ConsumerState<TrackViewBottomBar> {
  final _favoriteController = FavoriteIconController();

  @override
  void dispose() {
    _favoriteController.dispose();
    super.dispose();
  }

  void _shareTrack(BuildContext context) {
    final deepLink = 'https://medito.app/tracks/${widget.trackId}';
    final shareText = AppLocalizations.of(
      context,
    )!.shareTrackText(widget.trackTitle, deepLink);
    SharePlus.instance.share(ShareParams(text: shareText));
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      showDragHandle: true,
      context: context,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Platform.isIOS)
              _buildBottomSheetTile(
                context,
                iconAsset: MeditoIcons.siri,
                title: AppLocalizations.of(context)!.addToSiri,
                onTap: () {
                  addToSiri(
                    title:
                        '${AppLocalizations.of(context)!.open} ${widget.trackTitle}',
                    id: widget.trackId,
                    url: 'org.meditofoundation://tracks/${widget.trackId}',
                  );
                  Navigator.pop(context);
                },
              ),
            _buildBottomSheetTile(
              context,
              iconAsset: Platform.isIOS
                  ? MeditoIcons.shareIos
                  : MeditoIcons.shareAndroid,
              title: AppLocalizations.of(context)!.share,
              onTap: () {
                _shareTrack(context);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  ListTile _buildBottomSheetTile(
    BuildContext context, {
    required String iconAsset,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: MeditoIcon(
        assetName: iconAsset,
        color: Theme.of(context).colorScheme.onSurface,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      onTap: onTap,
    );
  }

  void _toggleFavorite(bool isFavorite, Track track) {
    final notifier = ref.read(favoritesNotifierProvider.notifier);
    _favoriteController.trigger(
      () => isFavorite
          ? notifier.removeFromFavorites(widget.trackId)
          : notifier.addToFavorites(
              FavoriteItem(
                id: widget.trackId,
                title: widget.trackTitle,
                coverUrl: widget.coverUrl ?? track.coverUrl,
                subtitle: track.subtitle,
                type: FavoriteItemType.track,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ),
            ),
      direction: isFavorite
          ? FavoriteToggleDirection.remove
          : FavoriteToggleDirection.add,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackState = ref.watch(tracksProvider(trackId: widget.trackId));
    final favoritesState = ref.watch(favoritesNotifierProvider);

    const dailyMeditationId = 'BmTFAyYt8jVMievZ'; // from back end :(
    final isDailyMeditation = widget.trackId == dailyMeditationId;

    return trackState.when(
      data: (track) {
        return favoritesState.when(
          data: (favorites) {
            final isFavorite = favorites.any(
              (item) => item.id == widget.trackId,
            );
            return _buildBottomBar(
              context,
              track,
              isFavorite,
              isDailyMeditation,
            );
          },
          loading: () =>
              _buildBottomBar(context, track, false, isDailyMeditation),
          error: (error, stack) =>
              _buildBottomBar(context, track, false, isDailyMeditation),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    Track track,
    bool isFavorite,
    bool isDailyMeditation,
  ) {
    final colour = isFavorite
        ? context.brandPurple
        : Theme.of(context).colorScheme.onSurface;

    final l10n = AppLocalizations.of(context)!;

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
        onTap: Platform.isIOS
            ? () => _showBottomSheet(context)
            : () => _shareTrack(context),
        semanticLabel: l10n.shareTrack,
      ),
      rightItem: isDailyMeditation
          ? null
          : BottomActionBarItem(
              child: AnimatedFavouriteIcon(
                isFavorite: isFavorite,
                color: colour,
                controller: _favoriteController,
              ),
              semanticLabel: isFavorite
                  ? l10n.removeFromFavorites
                  : l10n.addToFavorites,
              onTap: () => _toggleFavorite(isFavorite, track),
            ),
    );
  }
}
