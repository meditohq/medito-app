import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml2json/xml2json.dart';

final dev = const AppLoggerAdapter('PRODUCTS_SERVICE');

class ProductsService {
  static const String _productsFeedUrl =
      'https://shop.medito.app/.well-known/merchant-center/rss.xml';
  static const String _cachedProductDataKey = 'cachedProductData';

  Future<ProductsResponse> fetchProducts() async {
    dev.log('ProductsService: Starting to fetch products');
    try {
      final response = await http.get(Uri.parse(_productsFeedUrl));

      dev.log(
        'ProductsService: Received response with status ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        dev.log('ProductsService: Error status code: ${response.statusCode}');
        throw const ServerError();
      }

      dev.log('ProductsService: Response body length: ${response.body.length}');
      final productResponse = _parseRssResponse(response.body);
      dev.log(
        'ProductsService: Parsed ${productResponse.products.length} products',
      );

      // Update product cache and set firstSeenDate using copyWith
      await _updateProductCacheAndSetFirstSeen(productResponse.products);

      return productResponse;
    } catch (e) {
      dev.log(
        'ProductsService: Error fetching products: ${e.toString()}',
        error: e,
      );
      if (e is AppError) rethrow;
      throw ServerError(message: 'Error fetching products: ${e.toString()}');
    }
  }

  ProductsResponse _parseRssResponse(String xmlString) {
    try {
      // Parse XML to JSON
      dev.log('ProductsService: Starting to parse XML');
      final xml2json = Xml2Json();
      xml2json.parse(xmlString);

      // Using GData format for better compatibility with Google feed format
      final jsonString = xml2json.toGData();
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      dev.log('ProductsService: Successfully parsed XML to JSON');

      // Extract items from RSS feed with the correct structure
      final channelData = jsonData['rss']['channel'];
      dev.log(
        'ProductsService: Channel data has keys: ${channelData.keys.toList()}',
      );

      // Handle empty response
      if (!channelData.containsKey('item')) {
        dev.log('ProductsService: No items found in response');
        return ProductsResponse(products: []);
      }

      final items = channelData['item'];
      dev.log('ProductsService: Items type: ${items.runtimeType}');

      // Convert to our model format
      // Ensure items is a list even if there's only one item
      final itemsList = items is List ? items : [items];
      dev.log('ProductsService: Found ${itemsList.length} items');

      // Filter out empty items and malformed data
      final filteredItems = itemsList
          .where(
            (item) =>
                item is Map<String, dynamic> &&
                item.containsKey('g\$id') &&
                item.containsKey('g\$title'),
          )
          .toList();
      dev.log(
        'ProductsService: After filtering, ${filteredItems.length} valid items',
      );

      if (filteredItems.isNotEmpty) {
        dev.log(
          'ProductsService: Sample item keys: ${filteredItems.first.keys.toList()}',
        );
      }

      // Add proper g: prefix mappings for our model
      final List<Map<String, dynamic>> formattedItems = [];

      for (var item in filteredItems) {
        try {
          Map<String, dynamic> formattedItem = {};

          item.forEach((key, value) {
            try {
              if (key.startsWith('g\$')) {
                // Extract the field name after g$
                final fieldName = key.substring(2);
                // Convert to g:fieldName format
                if (value is Map && value.containsKey('\$t')) {
                  formattedItem['g:$fieldName'] = value['\$t'];
                } else {
                  formattedItem['g:$fieldName'] = value.toString();
                }
              } else {
                formattedItem[key] = value;
              }
            } catch (e) {
              dev.log('ProductsService: Error processing field $key: $e');
              // Skip this field if there's an error
            }
          });

          if (formattedItem.containsKey('g:id') &&
              formattedItem.containsKey('g:title') &&
              formattedItem.containsKey('g:price')) {
            formattedItems.add(formattedItem);
          }
        } catch (e) {
          dev.log('ProductsService: Error formatting item: $e');
          // Skip this item if there's an error
          continue;
        }
      }

      dev.log('ProductsService: Formatted ${formattedItems.length} items');

      List<ProductModel> products = [];
      for (var item in formattedItems) {
        try {
          // Create model without firstSeenDate initially
          products.add(ProductModel.fromRss(item));
        } catch (e) {
          dev.log('ProductsService: Error creating product model: $e');
          // Skip this product if there's an error
        }
      }

      dev.log('ProductsService: Final product count: ${products.length}');
      if (products.isNotEmpty) {
        dev.log(
          'ProductsService: First product: ${products.first.name}, price: ${products.first.price}',
        );
      }

      return ProductsResponse(products: products);
    } catch (e) {
      dev.log(
        'ProductsService: Error parsing data: ${e.toString()}',
        error: e,
        stackTrace: StackTrace.current,
      );
      throw UnknownError(
        message: 'Error parsing products data: ${e.toString()}',
      );
    }
  }

  // Updated method to handle caching and set firstSeenDate
  Future<void> _updateProductCacheAndSetFirstSeen(
    List<ProductModel> currentProducts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataJson = prefs.getString(_cachedProductDataKey);
      Map<String, String> cachedData = {}; // Store ID -> ISO 8601 Date String

      if (cachedDataJson != null) {
        try {
          final Map<String, dynamic> decodedData = json.decode(cachedDataJson);
          // Ensure values are strings before casting
          cachedData = decodedData.map(
            (key, value) => MapEntry(key, value.toString()),
          );
          dev.log(
            'ProductsService: Loaded ${cachedData.length} cached product entries',
          );
        } catch (e) {
          dev.log(
            'ProductsService: Error decoding cached data: $e, resetting cache.',
          );
          await prefs.remove(_cachedProductDataKey); // Clear corrupted cache
        }
      }

      final Map<String, String> newCacheData = {};
      final now = DateTime.now();
      final nowString = now.toIso8601String();

      for (int i = 0; i < currentProducts.length; i++) {
        final product = currentProducts[i];
        final productId = product.id;

        if (cachedData.containsKey(productId)) {
          // Product exists in cache, use existing firstSeenDate
          final cachedDateString = cachedData[productId]!;
          try {
            final firstSeenDate = DateTime.parse(cachedDateString);
            currentProducts[i] = product.copyWith(firstSeenDate: firstSeenDate);
            newCacheData[productId] =
                cachedDateString; // Keep existing date in new cache
          } catch (e) {
            // Handle potential parse error, treat as new
            dev.log(
              'ProductsService: Error parsing cached date for $productId: $e. Treating as new.',
            );
            currentProducts[i] = product.copyWith(firstSeenDate: now);
            newCacheData[productId] = nowString;
          }
        } else {
          // New product, set firstSeenDate to now
          currentProducts[i] = product.copyWith(firstSeenDate: now);
          newCacheData[productId] = nowString; // Add new product to cache
        }
      }

      // Update the cache with the potentially modified product data map
      final newCachedDataJson = json.encode(newCacheData);
      await prefs.setString(_cachedProductDataKey, newCachedDataJson);
      dev.log(
        'ProductsService: Updated cache with ${newCacheData.length} product entries',
      );
    } catch (e) {
      dev.log(
        'ProductsService: Error updating product cache: $e',
        error: e,
        stackTrace: StackTrace.current,
      );
      // Log and continue without cache update on error
    }
  }

  // --- Functionality to handle tap ---
  // This function should be called from the UI/ViewModel when a product is tapped.
  // It removes the firstSeenDate from the cache for that product, effectively marking it as not new.
  Future<void> markProductAsSeen(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataJson = prefs.getString(_cachedProductDataKey);
      if (cachedDataJson == null) return; // No cache exists

      Map<String, dynamic> cachedData = json.decode(cachedDataJson);

      if (cachedData.containsKey(productId)) {
        cachedData[productId] = DateTime(1970).toIso8601String();
        final updatedCacheJson = json.encode(cachedData);
        await prefs.setString(_cachedProductDataKey, updatedCacheJson);
      }
    } catch (e) {
      dev.log('ProductsService: Error marking product as seen: $e', error: e);
    }
  }
}
