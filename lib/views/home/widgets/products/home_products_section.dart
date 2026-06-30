import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:medito/providers/home/products_provider.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/home/widgets/products/products_widget.dart';

class HomeProductsSection extends ConsumerWidget {
  const HomeProductsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);

    return products.when(
      loading: () {
        AppLogger.d('HomeProductsSection', 'Products are loading');
        return const SizedBox(height: 230);
      },
      error: (err, stack) {
        return const SizedBox.shrink();
      },
      data: (List<ProductGroupModel> productGroups) {
        if (productGroups.isEmpty) return const SizedBox.shrink();

        // Shuffle the order of product groups
        var shuffledProducts = List<ProductGroupModel>.from(productGroups)
          ..shuffle();

        return ProductsWidget(
          key: ValueKey(HomeWidgetType.products.name),
          productGroups: shuffledProducts,
        );
      },
    );
  }
}
