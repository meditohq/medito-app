import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/shop/shop_navigation.dart';

/// Load failure with a retry and a way out to the web shop.
class ShopErrorView extends StatelessWidget {
  const ShopErrorView({super.key, required this.onRetry, this.productSlug});

  final VoidCallback onRetry;

  /// Opens this product on the web shop instead of the storefront home.
  final String? productSlug;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.shopLoadError,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: Text(l10n.retry)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => openShopInBrowser(slug: productSlug),
            style: TextButton.styleFrom(
              textStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(l10n.shopOpenInBrowser),
          ),
        ],
      ),
    );
  }
}
