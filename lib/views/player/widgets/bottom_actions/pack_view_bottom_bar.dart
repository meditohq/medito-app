import 'package:medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';

import 'package:medito/constants/icons/medito_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/favorites/favorite_item.dart';
import '../../../../models/pack/pack_model.dart';
import '../../../../providers/favorites/favorites_provider.dart';
import '../../../../providers/pack/pack_provider.dart';
import '../../../../widgets/add_to_siri_util.dart';
import '../../../../widgets/medito_huge_icon.dart';
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

    return packData.when(
      data: (pack) {
        return favoritesState.when(
          data: (favorites) {
            final isFavorite = favorites.any((item) => item.id == packId);
            return _buildBottomBar(
              context,
              ref,
              pack,
              isFavorite,
            );
          },
          loading: () {
            return _buildBottomBar(
              context,
              ref,
              pack,
              false,
            );
          },
          error: (error, stack) {
            return _buildBottomBar(
              context,
              ref,
              pack,
              false,
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    PackModel pack,
    bool isFavorite,
  ) {
    var colour = isFavorite
        ? ColorConstants.lightPurple
        : Theme.of(context).colorScheme.onSurface;
    var icon =
        isFavorite ? MeditoIcons.starSolid : MeditoIcons.star;

    return BottomActionBar(
      layout: BottomActionBarLayout.compactRight,
      leftItem: BottomActionBarItem(
        child: MeditoIcon(
          assetName: MeditoIcons.arrowLeft,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: onBackPressed,
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
      ),
      rightItem: BottomActionBarItem(
        child: MeditoIcon(
          assetName: icon,
          color: colour,
        ),
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
}
