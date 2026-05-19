import 'package:medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';

import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/home/up_next_provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/favorites/favorite_item.dart';
import '../../../../models/pack/pack_model.dart';
import '../../../../providers/favorites/favorites_provider.dart';
import '../../../../widgets/add_to_siri_util.dart';
import '../../../../widgets/medito_icon.dart';
import '../../../../widgets/snackbar_widget.dart';
import 'animated_favourite_icon.dart';
import 'bottom_action_bar.dart';

class PackViewBottomBar extends ConsumerWidget {
  final String packId;
  final String packName;
  final VoidCallback onBackPressed;

  const PackViewBottomBar({
    super.key,
    required this.packId,
    required this.packName,
    required this.onBackPressed,
  });

  void _sharePack(BuildContext context) {
    final deepLink = 'https://medito.app/packs/$packId';
    final shareText =
        AppLocalizations.of(context)!.sharePackText(packName, deepLink);
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
                    title: '${AppLocalizations.of(context)!.open} $packName',
                    id: packId,
                    url: 'org.meditofoundation://packs/$packId',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packData = ref.watch(packProvider(packId: packId));
    final favoritesState = ref.watch(favoritesNotifierProvider);
    final currentUpNextPackId = ref.watch(upNextPackIdProvider);
    final isDefaultPack = packId == ConfigConstants.basicsPackId;

    return packData.when(
      data: (pack) {
        final containsOnlyTracks = pack.items.every(
          (item) => item.type == TypeConstants.track,
        );
        return favoritesState.when(
          data: (favorites) {
            final isFavorite = favorites.any((item) => item.id == packId);
            final isUpNext = currentUpNextPackId == packId;
            return _buildBottomBar(
              context,
              ref,
              pack,
              isFavorite,
              isUpNext,
              containsOnlyTracks,
              isDefaultPack,
            );
          },
          loading: () {
            final isUpNext = currentUpNextPackId == packId;
            return _buildBottomBar(
              context,
              ref,
              pack,
              false,
              isUpNext,
              containsOnlyTracks,
              isDefaultPack,
            );
          },
          error: (error, stack) {
            final isUpNext = currentUpNextPackId == packId;
            return _buildBottomBar(
              context,
              ref,
              pack,
              false,
              isUpNext,
              containsOnlyTracks,
              isDefaultPack,
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    PackModel pack,
    bool isFavorite,
    bool isUpNext,
    bool containsOnlyTracks,
    bool isDefaultPack,
  ) {
    var favouriteColour = isFavorite
        ? context.brandPurple
        : Theme.of(context).colorScheme.onSurface;
    var pinColour = isUpNext
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
        onTap: onBackPressed,
        semanticLabel: l10n.goBack,
      ),
      rightCenterItem: BottomActionBarItem(
        child: MeditoIcon(
          assetName:
              Platform.isIOS ? MeditoIcons.shareIos : MeditoIcons.shareAndroid,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: Platform.isIOS
            ? () => _showBottomSheet(context)
            : () => _sharePack(context),
        semanticLabel: l10n.share,
      ),
      leftCenterItem: containsOnlyTracks
          ? BottomActionBarItem(
              child: MeditoIcon(
                assetName: isUpNext ? MeditoIcons.pinSolid : MeditoIcons.pin,
                color: pinColour,
              ),
              onTap: () => _onPinTap(context, ref, isUpNext, isDefaultPack),
              semanticLabel:
                  isUpNext ? l10n.unpinFromUpNext : l10n.pinToUpNext,
            )
          : null,
      rightItem: BottomActionBarItem(
        child: AnimatedFavouriteIcon(
          isFavorite: isFavorite,
          color: favouriteColour,
        ),
        semanticLabel:
            isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
        onTap: () {
          if (isFavorite) {
            ref
                .read(favoritesNotifierProvider.notifier)
                .removeFromFavorites(packId);
          } else {
            ref.read(favoritesNotifierProvider.notifier).addToFavorites(
                  FavoriteItem(
                    id: packId,
                    title: packName,
                    coverUrl: pack.coverUrl,
                    subtitle: pack.subtitle,
                    type: FavoriteItemType.pack,
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  ),
                );
          }
        },
      ),
    );
  }

  Future<void> _onPinTap(
    BuildContext context,
    WidgetRef ref,
    bool isUpNext,
    bool isDefaultPack,
  ) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final l10n = AppLocalizations.of(context)!;

    if (isUpNext && !isDefaultPack) {
      // Unpin: set back to default pack
      await prefs.remove(SharedPreferenceConstants.upNextPackId);
      ref.invalidate(upNextPackIdProvider);
      if (context.mounted) showSnackBar(context, l10n.packUnpinnedFromUpNext);
    } else if (!isUpNext) {
      // Pin: set this pack as up next
      await prefs.setString(SharedPreferenceConstants.upNextPackId, packId);
      ref.invalidate(upNextPackIdProvider);
      if (context.mounted) showSnackBar(context, l10n.packSetAsUpNext);
    }
    // If isUpNext && isDefaultPack, do nothing (can't unpin default)
  }
}
