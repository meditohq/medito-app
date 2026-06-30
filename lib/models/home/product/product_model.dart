import 'package:medito/utils/logger.dart';

final dev = const AppLoggerAdapter('PRODUCT_MODEL');

class ProductModel {
  final String id;
  final String name;
  final String? description;
  final String? url;
  final double price;
  final String currency;
  final String? imageUrl;
  final String? size;
  final String? color;
  final String? itemGroupId;
  final DateTime? firstSeenDate;

  bool get isNew =>
      firstSeenDate != null &&
      DateTime.now().difference(firstSeenDate!).inDays < 7;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.url,
    required this.price,
    required this.currency,
    this.imageUrl,
    this.size,
    this.color,
    this.itemGroupId,
    this.firstSeenDate,
  });

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? url,
    double? price,
    String? currency,
    String? imageUrl,
    String? size,
    String? color,
    String? itemGroupId,
    DateTime? firstSeenDate,
    bool? isNew,
  }) {
    DateTime? finalFirstSeenDate;
    if (firstSeenDate == null && this.firstSeenDate != null && isNew == null) {
      finalFirstSeenDate = this.firstSeenDate;
    } else {
      finalFirstSeenDate = firstSeenDate;
    }

    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      url: url ?? this.url,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      size: size ?? this.size,
      color: color ?? this.color,
      itemGroupId: itemGroupId ?? this.itemGroupId,
      firstSeenDate: finalFirstSeenDate,
    );
  }

  factory ProductModel.fromRss(Map<String, dynamic> json) {
    try {
      // Handle Google Merchant Center format with g: prefix
      final priceString = json['g:price'] as String?;
      final price = _parsePrice(priceString);
      final currency = _parseCurrency(priceString) ?? 'USD';

      return ProductModel(
        id: json['g:id']?.toString() ?? '',
        name: _cleanCdataContent(_extractStringValue(json, 'g:title')),
        description: _extractStringValue(json, 'g:description'),
        url: _extractStringValue(json, 'g:link'),
        price: price,
        currency: currency,
        imageUrl: _extractStringValue(json, 'g:image_link'),
        size: _extractStringValue(json, 'g:size'),
        color: _extractStringValue(json, 'g:color'),
        itemGroupId: _extractStringValue(json, 'g:item_group_id'),
        firstSeenDate: null,
      );
    } catch (e) {
      dev.log('ProductModel: Error creating from RSS: $e');
      // Return a minimal valid product in case of error
      return ProductModel(
        id: json['g:id']?.toString() ?? 'unknown',
        name: json['g:title']?.toString() ?? 'Unknown Product',
        price: 0.0,
        currency: 'USD',
        firstSeenDate: null,
      );
    }
  }

  static String _cleanCdataContent(String input) {
    // Clean up CDATA content which may appear as {__cdata: actual content}
    if (input.contains('{__cdata:')) {
      final startIndex = input.indexOf('{__cdata:') + 9;
      final endIndex = input.indexOf('}', startIndex);
      if (endIndex > startIndex) {
        return input.substring(startIndex, endIndex).trim();
      }
    }
    return input;
  }

  static String _extractStringValue(Map<String, dynamic> json, String key) {
    try {
      final value = json[key];
      if (value == null) return '';

      if (value is String) {
        return value;
      } else if (value is Map && value.containsKey('\$t')) {
        return value['\$t']?.toString() ?? '';
      } else {
        return value.toString();
      }
    } catch (e) {
      dev.log('ProductModel: Error extracting $key: $e');
      return '';
    }
  }

  static double _parsePrice(String? priceString) {
    if (priceString == null) return 0.0;

    try {
      // Extract numeric part from format like "10.00 USD"
      final numericPart = priceString.split(' ').first;
      return double.tryParse(numericPart) ?? 0.0;
    } catch (e) {
      dev.log('ProductModel: Error parsing price: $e');
      return 0.0;
    }
  }

  static String? _parseCurrency(String? priceString) {
    if (priceString == null) return null;

    try {
      // Extract currency part from format like "10.00 USD"
      final parts = priceString.split(' ');
      return parts.length > 1 ? parts.last : null;
    } catch (e) {
      dev.log('ProductModel: Error parsing currency: $e');
      return 'USD';
    }
  }
}

class ProductGroupModel {
  final String groupId;
  final String name;
  final String? description;
  final String? url;
  final String? imageUrl;
  final String? color;
  final List<ProductModel> variants;
  final List<String> allImageUrls;
  final String? displayImageUrl;

  ProductGroupModel({
    required this.groupId,
    required this.name,
    this.description,
    this.url,
    this.imageUrl,
    this.color,
    required this.variants,
    required this.allImageUrls,
    this.displayImageUrl,
  });

  // Base price is the lowest price among variants
  double get basePrice {
    if (variants.isEmpty) return 0.0;
    return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  }

  // Currency from the first variant (should be the same for all)
  String get currency {
    if (variants.isEmpty) return 'USD';
    return variants.first.currency;
  }
}

class ProductsResponse {
  final List<ProductModel> products;

  ProductsResponse({required this.products});

  factory ProductsResponse.fromRss(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>?;

    final products =
        items
            ?.map((item) => ProductModel.fromRss(item as Map<String, dynamic>))
            .toList() ??
        [];

    return ProductsResponse(products: products);
  }
}
