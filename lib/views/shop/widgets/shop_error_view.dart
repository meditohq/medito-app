import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/shop/shop_navigation.dart';

/// Load failure with a retry and a way out to the web shop.
class ShopErrorView extends ConsumerStatefulWidget {
  const ShopErrorView({
    super.key,
    required this.onRetry,
    required this.surface,
    this.error,
    this.productSlug,
  });

  final VoidCallback onRetry;

  /// Which screen failed, for [AnalyticsEventConstants.shopLoadFailed]:
  /// 'grid' or 'product'.
  final String surface;

  /// The failure, classified into the event's error_kind.
  final Object? error;

  /// Opens this product on the web shop instead of the storefront home.
  final String? productSlug;

  @override
  ConsumerState<ShopErrorView> createState() => _ShopErrorViewState();
}

class _ShopErrorViewState extends ConsumerState<ShopErrorView> {
  @override
  void initState() {
    super.initState();
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: AnalyticsEventConstants.shopLoadFailed,
          parameters: {
            'surface': widget.surface,
            AnalyticsEventConstants.paramErrorKind: widget.error == null
                ? 'unknown'
                : analyticsErrorKind(widget.error!),
            if (widget.productSlug != null) 'product_slug': widget.productSlug!,
          },
        );
  }

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
          ElevatedButton(onPressed: widget.onRetry, child: Text(l10n.retry)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => openShopInBrowser(slug: widget.productSlug),
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
