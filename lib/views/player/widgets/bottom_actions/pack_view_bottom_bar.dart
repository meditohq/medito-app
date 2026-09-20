import 'package:medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';

import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/providers/providers.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/favorites/favorite_item.dart';
import '../../../../models/pack/pack_model.dart';
import '../../../../providers/favorites/favorites_provider.dart';
import '../../../../widgets/add_to_siri_util.dart';
import '../../../../widgets/medito_icon.dart';
import '../../../../scaffold_messenger_key.dart';
import '../../../../widgets/snackbar_widget.dart';
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
                        '${AppLocalizations.of(context)!.open} ${widget.packName}',
                    id: widget.packId,
                    url: 'org.meditofoundation://packs/${widget.packId}',
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
                _sharePack(context);
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

  void _toggleFavorite(bool isFavorite, PackModel pack) {
    final notifier = ref.read(favoritesNotifierProvider.notifier);
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

    return packData.when(
      data: (pack) {
        final isFavorite = favoritesState.maybeWhen(
          data: (favorites) =>
              favorites.any((item) => item.id == widget.packId),
          orElse: () => false,
        );
        return _buildBottomBar(context, pack, isFavorite);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    PackModel pack,
    bool isFavorite,
  ) {
    final favouriteColour = isFavorite
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
            : () => _sharePack(context),
        semanticLabel: l10n.share,
      ),
      rightItem: BottomActionBarItem(
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
    );
  }
}
