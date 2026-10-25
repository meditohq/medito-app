import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/views/shop/widgets/shop_product_card.dart';

void main() {
  final page =
      jsonDecode(
            File(
              'test/fixtures/fourthwall_products_page.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final json = (page['results'] as List).cast<Map<String, dynamic>>().first;
  // Long enough to need both of the caption's name lines.
  final product = ShopProduct.fromJson({
    ...json,
    'name': 'Sleepy Cat Organic Cotton Relaxed Fit T-Shirt With Pocket',
  });

  // The grid sized captions at a fixed 74px, which overflowed from ~1.15×.
  for (final scale in [1.0, 1.15, 1.5]) {
    testWidgets('caption fits its grid tile at ${scale}x text', (tester) async {
      const tileWidth = 170.0;
      final scaler = TextScaler.linear(scale);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(textScaler: scaler),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: tileWidth,
                  height:
                      tileWidth / kShopPhotoAspect +
                      shopCardCaptionHeight(scaler),
                  child: ShopProductCard(product: product, onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
