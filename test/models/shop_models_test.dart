import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/shop/shop_models.dart';

void main() {
  final page =
      jsonDecode(
            File(
              'test/fixtures/fourthwall_products_page.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final results = (page['results'] as List).cast<Map<String, dynamic>>();
  final shirt = ShopProduct.fromJson(results[0]);
  final mug = ShopProduct.fromJson(results[1]);
  final giftCard = ShopProduct.fromJson(results[2]);

  group('ShopProduct.fromJson', () {
    test('reads the fields the shop renders', () {
      expect(shirt.slug, 'sleepy-cat-t-shirt');
      expect(shirt.name, 'Sleepy Cat T-Shirt');
      expect(shirt.variants, hasLength(7));
      expect(shirt.images, isNotEmpty);
      expect(shirt.infoSections.map((s) => s.title), [
        'More details',
        'Quality Guarantee & Returns',
      ]);
      expect(shirt.createdAt, DateTime.utc(2025, 3, 23, 13, 12, 59, 16, 467));
    });

    test('parses colour swatches and sizes per variant', () {
      final v = shirt.variants.first;
      expect(v.color?.name, 'Lilac');
      expect(v.color?.swatch, '#eec9e2');
      expect(v.size, 'S');
      expect(v.label, 'Lilac, S');
      expect(v.price.value, 28);
      expect(v.price.currency, 'USD');
    });

    test('limited stock at zero is out of stock; unlimited is in stock', () {
      final goldM = shirt.variantsWhere('Gold', 'M');
      expect(goldM.inStock, isFalse);
      expect(shirt.variantsWhere('Gold', 'S').inStock, isTrue);
    });
  });

  group('options', () {
    test('colours keep shop order, deduplicated', () {
      expect(shirt.colors.map((c) => c.name), ['Lilac', 'Gold']);
    });

    test('apparel sizes sort in wearing order', () {
      expect(shirt.sizes, ['S', 'M', 'L', 'XL', '2XL']);
    });

    test('unrecognised sizes keep listing order', () {
      expect(mug.sizes, ['11oz', '15oz', '20 oz']);
    });

    test('variantFor matches colour and size', () {
      expect(
        shirt.variantFor(color: 'Lilac', size: '2XL')?.label,
        'Lilac, 2XL',
      );
      expect(shirt.variantFor(color: 'Gold', size: 'XL'), isNull);
    });

    test('variantFor prefers an in-stock variant for a partial choice', () {
      expect(shirt.variantFor(color: 'Gold')?.size, 'S');
    });

    test('products without colour or size pick by label', () {
      expect(giftCard.pickByLabel, isTrue);
      expect(giftCard.variants.map((v) => v.label).first, r'$10.00');
      expect(shirt.pickByLabel, isFalse);
      expect(mug.pickByLabel, isFalse);
    });
  });

  group('pricing', () {
    test('fromPrice is the cheapest variant and flags varied prices', () {
      expect(shirt.fromPrice?.value, 28);
      expect(shirt.hasVariedPrices, isTrue);
      expect(giftCard.fromPrice?.value, 10);
    });

    test('formats whole amounts without decimals', () {
      expect(
        const ShopMoney(value: 28, currency: 'USD').format('en_US'),
        r'$28',
      );
      expect(
        const ShopMoney(value: 25.07, currency: 'EUR').format('en_US'),
        '€25.07',
      );
      expect(
        const ShopMoney(value: 4492, currency: 'JPY').format('en_US'),
        '¥4,492',
      );
    });

    test('multiplies by quantity', () {
      final total = const ShopMoney(value: 13.5, currency: 'GBP') * 3;
      expect(total.value, 40.5);
      expect(total.currency, 'GBP');
    });
  });

  group('images', () {
    test('a variant with photos uses them; otherwise the product\'s', () {
      final lilac = shirt.variants.first;
      expect(shirt.imagesFor(lilac), same(lilac.images));
      expect(shirt.imagesFor(null), same(shirt.images));
    });

    test('showcase has one lead photo per colour', () {
      final showcase = shirt.showcaseImages;
      expect(showcase, hasLength(2));
      expect(showcase.first.url, shirt.variants.first.images.first.url);
    });
  });

  test('isNewAt uses the shop creation date with a 30-day window', () {
    final created = shirt.createdAt!;
    expect(shirt.isNewAt(created.add(const Duration(days: 29))), isTrue);
    expect(shirt.isNewAt(created.add(const Duration(days: 31))), isFalse);
  });

  group('decodeHtmlEntities', () {
    test('decodes numeric, hex and named entities', () {
      expect(decodeHtmlEntities('Women&#39;s T-Shirts'), "Women's T-Shirts");
      expect(decodeHtmlEntities('A &amp; B &#x2014; C'), 'A & B — C');
      expect(decodeHtmlEntities('no entities'), 'no entities');
      expect(decodeHtmlEntities('&bogus; stays'), '&bogus; stays');
    });
  });

  group('parseShopHtml', () {
    test('splits paragraphs and bullets and strips inline tags', () {
      final blocks = parseShopHtml(
        '<p>Soft <strong>cotton</strong>&nbsp;tee.</p>'
        '<ul><li>Regular fit</li><li>Unisex&nbsp;sizing</li></ul>',
      );
      expect(blocks.map((b) => b.text), [
        'Soft cotton tee.',
        'Regular fit',
        'Unisex sizing',
      ]);
      expect(blocks.map((b) => b.isBullet), [false, true, true]);
    });

    test('keeps bare text and drops empty tags', () {
      final blocks = parseShopHtml('Just text<p> </p>');
      expect(blocks.map((b) => b.text), ['Just text']);
    });
  });

  group('size chart', () {
    test('only clothing sizes count as apparel', () {
      expect(shirt.hasApparelSizes, isTrue);
      expect(mug.hasApparelSizes, isFalse);
      expect(giftCard.hasApparelSizes, isFalse);
    });

    test('parses the chart Fourthwall embeds in the product page', () {
      const html = '''
<div><script type="application/json" data-size-guide="json">
  [ { "label": "S", "Length": { "in": "25.0", "cm": "63.5" },
      "Width": { "in": "18.0", "cm": "45.72" } },
    { "label": "M", "Length": { "in": "26.0", "cm": "66.04" },
      "Width": { "in": "20.0", "cm": "50.8" } } ]
</script></div>''';
      final chart = parseSizeChartHtml(html)!;
      expect(chart.measures, ['Length', 'Width']);
      expect(chart.rows.map((r) => r.label), ['S', 'M']);
      expect(chart.rows.last.values['Width']?.cm, 50.8);
      expect(chart.rows.first.values['Length']?.inches, 25);
    });

    test('no chart, bad JSON, or sizes without measurements → null', () {
      expect(parseSizeChartHtml('<html></html>'), isNull);
      expect(
        parseSizeChartHtml('<script data-size-guide="json">[oops</script>'),
        isNull,
      );
      expect(
        parseSizeChartHtml(
          '<script data-size-guide="json">[{"label": "50x60"}]</script>',
        ),
        isNull,
      );
    });
  });

  test('BagItem round-trips through JSON', () {
    final item = BagItem(
      variantId: 'v1',
      productSlug: 'mug',
      productName: 'Mug',
      variantLabel: 'White, 11oz',
      unitPrice: const ShopMoney(value: 12, currency: 'USD'),
      quantity: 2,
      imageUrl: 'https://example.com/a.webp',
    );
    final back = BagItem.fromJson(jsonDecode(jsonEncode(item.toJson())));
    expect(back.variantId, 'v1');
    expect(back.quantity, 2);
    expect(back.total.value, 24);
    expect(back.imageUrl, item.imageUrl);
  });
}

extension on ShopProduct {
  ShopVariant variantsWhere(String color, String size) =>
      variants.firstWhere((v) => v.color?.name == color && v.size == size);
}
