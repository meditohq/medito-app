import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:medito/services/products_service.dart';
import 'package:medito/utils/logger.dart';

final productsServiceProvider = Provider<ProductsService>((ref) {
  return ProductsService();
});

final productsProvider = FutureProvider<List<ProductGroupModel>>((ref) async {
  AppLogger.d('PRODUCTS_PROVIDER', 'Loading products');
  final service = ref.watch(productsServiceProvider);
  try {
    final response = await service.fetchProducts();
    AppLogger.d(
      'PRODUCTS_PROVIDER',
      'Loaded ${response.products.length} raw products',
    );

    // --- New Grouping Logic ---
    final Map<String, Map<String, dynamic>> tempGroups = {};

    for (final product in response.products) {
      // Use name + url as the unique key for a base product
      final key = '${product.name}${product.url ?? ''}';
      final imageUrl = product.imageUrl;

      if (!tempGroups.containsKey(key)) {
        // Initialize group if key doesn't exist
        tempGroups[key] = {
          'firstProduct': product, // Keep the first instance for base data
          'images': <String>{}, // Use a Set for unique images
        };
      }

      // Add image URL if it's valid and not already present
      if (imageUrl != null && imageUrl.isNotEmpty) {
        tempGroups[key]?['images'].add(imageUrl);
      }
    }

    // Convert the grouped data into ProductGroupModel list
    final groupedProducts = <ProductGroupModel>[];
    tempGroups.forEach((key, data) {
      final firstProduct = data['firstProduct'] as ProductModel;
      final imageSet = data['images'] as Set<String>;
      final allImages = imageSet.toList();

      // Shuffle the collected images for this group
      allImages.shuffle();

      groupedProducts.add(
        ProductGroupModel(
          groupId: key, // Use the name+url key as groupId
          name: firstProduct.name,
          description: firstProduct.description,
          url: firstProduct.url,
          // Pass minimal variant info based on first product
          variants: [firstProduct],
          allImageUrls: allImages, // Pass the shuffled images
          // Set displayImageUrl to the first shuffled image, or fallback
          displayImageUrl: allImages.isNotEmpty
              ? allImages.first
              : firstProduct.imageUrl,
          // Keep other fields derived from the first product
          imageUrl: firstProduct.imageUrl,
          color: firstProduct.color,
        ),
      );
    });
    // --- End New Grouping Logic ---

    AppLogger.d(
      'PRODUCTS_PROVIDER',
      'Grouped into ${groupedProducts.length} unique display products',
    );

    return groupedProducts; // Return the correctly grouped and shuffled list
  } catch (e) {
    AppLogger.e('PRODUCTS_PROVIDER', 'Error loading products', e);
    return [];
  }
});

final refreshProductsProvider = FutureProvider<List<ProductGroupModel>>((
  ref,
) async {
  AppLogger.d('PRODUCTS_PROVIDER', 'Refreshing products');
  ref.invalidate(productsProvider);
  try {
    final products = await ref.watch(productsProvider.future);
    AppLogger.d(
      'PRODUCTS_PROVIDER',
      'Refreshed ${products.length} product groups',
    );

    return products;
  } catch (e) {
    AppLogger.e('PRODUCTS_PROVIDER', 'Error refreshing products', e);
    return [];
  }
});
