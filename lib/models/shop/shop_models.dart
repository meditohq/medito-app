import 'dart:convert';

import 'package:intl/intl.dart';

/// Models for the Fourthwall Storefront API
/// (https://docs.fourthwall.com/storefront/overview). Parsed by hand: the
/// payloads are large and we only keep the fields the shop pages render.

class ShopMoney {
  const ShopMoney({required this.value, required this.currency});

  final double value;
  final String currency;

  factory ShopMoney.fromJson(Map<String, dynamic> json) => ShopMoney(
    value: (json['value'] as num).toDouble(),
    currency: json['currency'] as String,
  );

  Map<String, dynamic> toJson() => {'value': value, 'currency': currency};

  ShopMoney operator *(int quantity) =>
      ShopMoney(value: value * quantity, currency: currency);

  /// Localised price, e.g. "$28", "€25.07", "¥4,492". Whole amounts drop the
  /// decimals so a grid of "$28.00" doesn't read like a receipt.
  String format([String? locale]) {
    final whole = value == value.roundToDouble();
    final formatter = NumberFormat.simpleCurrency(
      locale: locale,
      name: currency,
      decimalDigits: whole ? 0 : null,
    );
    return formatter.format(value);
  }
}

class ShopImage {
  const ShopImage({required this.url, this.width, this.height});

  final String url;
  final int? width;
  final int? height;

  double get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : 1;

  factory ShopImage.fromJson(Map<String, dynamic> json) => ShopImage(
    url: (json['transformedUrl'] ?? json['url']) as String,
    width: json['width'] as int?,
    height: json['height'] as int?,
  );
}

class ShopColor {
  const ShopColor({required this.name, this.swatch});

  final String name;

  /// Hex like "#eec9e2"; null when the shop didn't set one.
  final String? swatch;
}

class ShopVariant {
  const ShopVariant({
    required this.id,
    required this.label,
    required this.price,
    this.compareAtPrice,
    this.color,
    this.size,
    this.inStock = true,
    this.images = const [],
  });

  final String id;

  /// Fourthwall's own summary of the options, e.g. "Lilac, S" or "$25.00".
  final String label;
  final ShopMoney price;
  final ShopMoney? compareAtPrice;
  final ShopColor? color;
  final String? size;
  final bool inStock;
  final List<ShopImage> images;

  factory ShopVariant.fromJson(Map<String, dynamic> json) {
    final attributes = (json['attributes'] as Map?)?.cast<String, dynamic>();
    final color = (attributes?['color'] as Map?)?.cast<String, dynamic>();
    final size = (attributes?['size'] as Map?)?.cast<String, dynamic>();
    final stock = (json['stock'] as Map?)?.cast<String, dynamic>();
    final compareAt = json['compareAtPrice'] as Map?;

    return ShopVariant(
      id: json['id'] as String,
      label: decodeHtmlEntities(
        (attributes?['description'] as String?) ?? json['name'] as String,
      ),
      price: ShopMoney.fromJson(
        (json['unitPrice'] as Map).cast<String, dynamic>(),
      ),
      compareAtPrice: compareAt == null
          ? null
          : ShopMoney.fromJson(compareAt.cast<String, dynamic>()),
      color: color == null
          ? null
          : ShopColor(
              name: color['name'] as String,
              swatch: color['swatch'] as String?,
            ),
      size: size?['name'] as String?,
      inStock:
          stock?['type'] != 'LIMITED' || ((stock?['inStock'] as int?) ?? 0) > 0,
      images: _images(json['images']),
    );
  }
}

class ShopInfoSection {
  const ShopInfoSection({required this.title, required this.bodyHtml});

  final String title;
  final String bodyHtml;
}

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.slug,
    required this.name,
    this.descriptionHtml = '',
    this.images = const [],
    this.variants = const [],
    this.infoSections = const [],
    this.soldOut = false,
    this.createdAt,
  });

  final String id;
  final String slug;
  final String name;
  final String descriptionHtml;
  final List<ShopImage> images;
  final List<ShopVariant> variants;
  final List<ShopInfoSection> infoSections;
  final bool soldOut;
  final DateTime? createdAt;

  static const _newWindow = Duration(days: 30);

  /// Added to the shop recently. Keyed off Fourthwall's creation date so a
  /// fresh install doesn't badge the whole catalogue as new.
  bool isNewAt(DateTime now) =>
      createdAt != null && now.difference(createdAt!) < _newWindow;

  bool get isAvailable => !soldOut && variants.any((v) => v.inStock);

  /// Cheapest variant price; sizes like 2XL cost more.
  ShopMoney? get fromPrice {
    if (variants.isEmpty) return null;
    return variants
        .map((v) => v.price)
        .reduce((a, b) => a.value <= b.value ? a : b);
  }

  bool get hasVariedPrices =>
      variants.map((v) => v.price.value).toSet().length > 1;

  /// Colours in the order the shop lists them.
  List<ShopColor> get colors {
    final seen = <String>{};
    return [
      for (final v in variants)
        if (v.color != null && seen.add(v.color!.name)) v.color!,
    ];
  }

  /// Sizes in wearing order (XS → 5XL) where recognised, otherwise as listed.
  List<String> get sizes {
    final seen = <String>{};
    final sizes = [
      for (final v in variants)
        if (v.size != null && seen.add(v.size!)) v.size!,
    ];
    final ranked = sizes.every(_sizeRank.containsKey);
    if (ranked) sizes.sort((a, b) => _sizeRank[a]!.compareTo(_sizeRank[b]!));
    return sizes;
  }

  /// Clothing sizes (S, M, L…) rather than mug volumes or print dimensions:
  /// the products whose web pages carry a measurement chart.
  bool get hasApparelSizes =>
      sizes.length > 1 && sizes.every(_sizeRank.containsKey);

  /// Variants that differ by neither colour nor size (e.g. gift card
  /// amounts) are picked by their label instead.
  bool get pickByLabel =>
      colors.isEmpty && sizes.isEmpty && variants.length > 1;

  /// Best match for a colour/size choice, preferring one in stock.
  ShopVariant? variantFor({String? color, String? size}) {
    final matches = variants.where(
      (v) =>
          (color == null || v.color?.name == color) &&
          (size == null || v.size == size),
    );
    if (matches.isEmpty) return null;
    return matches.firstWhere((v) => v.inStock, orElse: () => matches.first);
  }

  /// Gallery for the selected variant, falling back to the product's own.
  List<ShopImage> imagesFor(ShopVariant? variant) =>
      (variant != null && variant.images.isNotEmpty) ? variant.images : images;

  /// One lead image per colour so the home tile can cycle through them.
  List<ShopImage> get showcaseImages {
    final perColor = <ShopImage>[];
    final seen = <String>{};
    for (final v in variants) {
      if (v.color == null || v.images.isEmpty) continue;
      if (seen.add(v.color!.name)) perColor.add(v.images.first);
    }
    if (perColor.length > 1) return perColor;
    return images.isEmpty ? perColor : [images.first];
  }

  ShopImage? get leadImage => images.isNotEmpty
      ? images.first
      : variants.expand((v) => v.images).firstOrNull;

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    final state = (json['state'] as Map?)?['type'];
    final created = json['createdAt'] as String?;
    return ShopProduct(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: decodeHtmlEntities(json['name'] as String),
      descriptionHtml: (json['description'] as String?) ?? '',
      images: _images(json['images']),
      variants: [
        for (final v in (json['variants'] as List? ?? const []))
          ShopVariant.fromJson((v as Map).cast<String, dynamic>()),
      ],
      infoSections: [
        for (final s in (json['additionalInformation'] as List? ?? const []))
          if ((s as Map)['bodyHtml'] is String)
            ShopInfoSection(
              title: decodeHtmlEntities(s['title'] as String? ?? ''),
              bodyHtml: s['bodyHtml'] as String,
            ),
      ],
      soldOut: state == 'SOLD_OUT',
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }
}

class ShopCollection {
  const ShopCollection({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;

  factory ShopCollection.fromJson(Map<String, dynamic> json) => ShopCollection(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: decodeHtmlEntities(json['name'] as String),
  );
}

/// A line in the bag. Keeps enough of the product to render without a
/// network round trip; the price is refreshed whenever the catalogue loads.
class BagItem {
  const BagItem({
    required this.variantId,
    required this.productSlug,
    required this.productName,
    required this.variantLabel,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
  });

  final String variantId;
  final String productSlug;
  final String productName;
  final String variantLabel;
  final ShopMoney unitPrice;
  final int quantity;
  final String? imageUrl;

  ShopMoney get total => unitPrice * quantity;

  BagItem copyWith({int? quantity, ShopMoney? unitPrice}) => BagItem(
    variantId: variantId,
    productSlug: productSlug,
    productName: productName,
    variantLabel: variantLabel,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    imageUrl: imageUrl,
  );

  factory BagItem.fromJson(Map<String, dynamic> json) => BagItem(
    variantId: json['variantId'] as String,
    productSlug: json['productSlug'] as String,
    productName: json['productName'] as String,
    variantLabel: json['variantLabel'] as String,
    unitPrice: ShopMoney.fromJson(
      (json['unitPrice'] as Map).cast<String, dynamic>(),
    ),
    quantity: json['quantity'] as int,
    imageUrl: json['imageUrl'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'variantId': variantId,
    'productSlug': productSlug,
    'productName': productName,
    'variantLabel': variantLabel,
    'unitPrice': unitPrice.toJson(),
    'quantity': quantity,
    'imageUrl': imageUrl,
  };
}

const _sizeRank = {
  'XXS': 0,
  'XS': 1,
  'S': 2,
  'M': 3,
  'L': 4,
  'XL': 5,
  '2XL': 6,
  'XXL': 6,
  '3XL': 7,
  'XXXL': 7,
  '4XL': 8,
  '5XL': 9,
};

List<ShopImage> _images(Object? raw) => [
  for (final i in (raw as List? ?? const []))
    ShopImage.fromJson((i as Map).cast<String, dynamic>()),
];

/// Fourthwall returns some names HTML-escaped ("Women&#39;s T-Shirts").
String decodeHtmlEntities(String input) {
  if (!input.contains('&')) return input;
  return input.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (m) {
    final code = m[1]!;
    if (code.startsWith('#x') || code.startsWith('#X')) {
      final value = int.tryParse(code.substring(2), radix: 16);
      return value == null ? m[0]! : String.fromCharCode(value);
    }
    if (code.startsWith('#')) {
      final value = int.tryParse(code.substring(1));
      return value == null ? m[0]! : String.fromCharCode(value);
    }
    return _namedEntities[code] ?? m[0]!;
  });
}

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ndash': '–',
  'mdash': '—',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
  'hellip': '…',
};

/// A paragraph or bullet from a product's HTML description.
class ShopTextBlock {
  const ShopTextBlock(this.text, {this.isBullet = false});

  final String text;
  final bool isBullet;
}

/// Flattens the small subset of HTML Fourthwall descriptions use (<p>, <ul>,
/// <li>, <br>, inline tags) into paragraphs and bullets.
List<ShopTextBlock> parseShopHtml(String html) {
  final blocks = <ShopTextBlock>[];
  final normalised = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'\r'), '');
  final pattern = RegExp(
    // Bullets, paragraphs, loose text; any other tag (<ul>, <strong>…)
    // matches the last branch and is skipped.
    r'<li(?:\s[^>]*)?>(.*?)</li>|<p(?:\s[^>]*)?>(.*?)</p>|([^<]+)|<[^>]*>',
    caseSensitive: false,
    dotAll: true,
  );
  for (final match in pattern.allMatches(normalised)) {
    final isBullet = match[1] != null;
    final raw = match[1] ?? match[2] ?? match[3] ?? '';
    final text = decodeHtmlEntities(
      raw.replaceAll(RegExp(r'<[^>]+>'), ''),
    ).replaceAll(' ', ' ').trim();
    if (text.isNotEmpty) blocks.add(ShopTextBlock(text, isBullet: isBullet));
  }
  return blocks;
}

/// Garment measurements per size, from the supplier chart Fourthwall
/// renders on the web product page (not exposed by the Storefront API).
class ShopSizeChart {
  const ShopSizeChart({required this.measures, required this.rows});

  /// Measurement keys in chart order, e.g. Length, Width, SleeveLength.
  final List<String> measures;
  final List<ShopSizeRow> rows;
}

class ShopSizeRow {
  const ShopSizeRow({required this.label, required this.values});

  final String label;

  /// Measure key → (inches, centimetres).
  final Map<String, ({double inches, double cm})> values;
}

/// Pulls the size chart out of a shop.medito.app product page. Fourthwall
/// embeds it as `<script data-size-guide="json">[{label, Length: {in, cm}…}]`.
/// Returns null when there is no chart or it has no measurements (the
/// blanket's lists sizes only), so callers can fall back to the web page.
ShopSizeChart? parseSizeChartHtml(String html) {
  final match = RegExp(
    r'<script[^>]*data-size-guide="json"[^>]*>(.*?)</script>',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(match[1]!);
  } catch (_) {
    return null;
  }
  if (decoded is! List) return null;

  double? number(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  final measures = <String>[];
  final rows = <ShopSizeRow>[];
  for (final entry in decoded) {
    if (entry is! Map || entry['label'] is! String) continue;
    final values = <String, ({double inches, double cm})>{};
    for (final MapEntry(:key, :value) in entry.entries) {
      if (key == 'label' || value is! Map) continue;
      final inches = number(value['in']);
      final cm = number(value['cm']);
      if (inches == null || cm == null) continue;
      values['$key'] = (inches: inches, cm: cm);
      if (!measures.contains('$key')) measures.add('$key');
    }
    rows.add(ShopSizeRow(label: entry['label'] as String, values: values));
  }
  if (measures.isEmpty || rows.isEmpty) return null;
  return ShopSizeChart(measures: measures, rows: rows);
}
