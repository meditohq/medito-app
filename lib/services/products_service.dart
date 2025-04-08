import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:xml2json/xml2json.dart';

class ProductsService {
  static const String _productsFeedUrl =
      'https://shop.medito.app/.well-known/merchant-center/rss.xml';

  Future<ProductsResponse> fetchProducts() async {
    dev.log('ProductsService: Starting to fetch products');
    try {
      final response = await http.get(Uri.parse(_productsFeedUrl));

      dev.log(
          'ProductsService: Received response with status ${response.statusCode}');

      if (response.statusCode != 200) {
        dev.log('ProductsService: Error status code: ${response.statusCode}');
        throw const ServerError();
      }

      dev.log('ProductsService: Response body length: ${response.body.length}');
      final productResponse = _parseRssResponse(response.body);
      dev.log(
          'ProductsService: Parsed ${productResponse.products.length} products');
      return productResponse;
    } catch (e) {
      dev.log('ProductsService: Error fetching products: ${e.toString()}',
          error: e);
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
          'ProductsService: Channel data has keys: ${channelData.keys.toList()}');

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
          .where((item) =>
              item is Map<String, dynamic> &&
              item.containsKey('g\$id') &&
              item.containsKey('g\$title'))
          .toList();
      dev.log(
          'ProductsService: After filtering, ${filteredItems.length} valid items');

      if (filteredItems.isNotEmpty) {
        dev.log(
            'ProductsService: Sample item keys: ${filteredItems.first.keys.toList()}');
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
          products.add(ProductModel.fromRss(item));
        } catch (e) {
          dev.log('ProductsService: Error creating product model: $e');
          // Skip this product if there's an error
        }
      }

      dev.log('ProductsService: Final product count: ${products.length}');
      if (products.isNotEmpty) {
        dev.log(
            'ProductsService: First product: ${products.first.name}, price: ${products.first.price}');
      }

      return ProductsResponse(products: products);
    } catch (e) {
      dev.log('ProductsService: Error parsing data: ${e.toString()}',
          error: e, stackTrace: StackTrace.current);
      throw UnknownError(
          message: 'Error parsing products data: ${e.toString()}');
    }
  }
}
