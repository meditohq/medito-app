import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/services/shop/fourthwall_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/shop/product_screen.dart';
import 'package:medito/views/shop/shop_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// What a caller already knows about a product (e.g. the home tile), so the
/// product page can paint its title and photo before the full record loads.
class ShopProductPreview {
  const ShopProductPreview({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;
}

Future<void> openShop(BuildContext context, {required String source}) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ShopScreen(source: source)));
}

Future<void> openShopProduct(
  BuildContext context, {
  required String slug,
  required String source,
  ShopProduct? product,
  ShopProductPreview? preview,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductScreen(
        slug: slug,
        source: source,
        product: product,
        preview: preview,
      ),
    ),
  );
}

/// Opens Fourthwall's hosted checkout for the bag in an in-app browser sheet
/// (SFSafariViewController / Custom Tabs), which keeps Apple Pay, Google Pay
/// and saved-card and address autofill that an embedded web view would lose.
Future<void> startShopCheckout(WidgetRef ref) async {
  final bag = ref.read(shopBagProvider);
  if (bag.isEmpty) return;

  final currency = ref.read(shopCurrencyProvider);
  final uri = FourthwallService.checkoutUri(bag.items, currency: currency);

  ref
      .read(analyticsServiceProvider)
      .logEvent(
        name: AnalyticsEventConstants.shopCheckoutStarted,
        parameters: {
          'items': bag.items.length,
          'quantity': bag.quantity,
          'value': bag.subtotal?.value ?? 0,
          'currency': bag.subtotal?.currency ?? currency,
        },
      );
  ref.read(shopBagProvider.notifier).markCheckoutStarted();

  await _launch(uri);
}

/// The web shop, for when the API is unreachable.
Future<void> openShopInBrowser({String? slug}) => _launch(
  slug == null
      ? Uri.https(FourthwallService.shopDomain)
      : FourthwallService.productWebUri(slug),
);

Future<void> _launch(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
  } catch (e) {
    AppLogger.w('SHOP', 'In-app browser failed for $uri: $e');
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
