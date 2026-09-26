import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/views/home/widgets/products/products_widget.dart';

/// Home's shop row. The catalogue page is heavy (~330KB over the wire), and
/// the row usually sits below the fold, so nothing is fetched until the row
/// is within a screen or so of the viewport.
class HomeProductsSection extends ConsumerStatefulWidget {
  const HomeProductsSection({super.key});

  @override
  ConsumerState<HomeProductsSection> createState() =>
      _HomeProductsSectionState();
}

class _HomeProductsSectionState extends ConsumerState<HomeProductsSection> {
  bool _near = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_near) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_check);
      _position = position?..addListener(_check);
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_near || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = MediaQuery.sizeOf(context).height;
    if (top < screen * 2) {
      _position?.removeListener(_check);
      setState(() => _near = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(HomeWidgetType.products.name);
    // Before we're close, reserve the row's space without fetching.
    if (!_near) return ProductsWidget(key: key, products: null);

    final products = ref.watch(homeShopProductsProvider);
    return products.when(
      skipLoadingOnRefresh: true,
      loading: () => ProductsWidget(key: key, products: null),
      error: (_, _) => const SizedBox.shrink(),
      data: (home) => home.products.isEmpty
          ? const SizedBox.shrink()
          : ProductsWidget(
              key: key,
              products: home.curated
                  ? home.products
                  : dailyShuffle(home.products),
            ),
    );
  }
}

/// Varies the order day to day without reshuffling on every rebuild.
List<ShopProduct> dailyShuffle(List<ShopProduct> products, [DateTime? now]) {
  final day = (now ?? DateTime.now()).difference(DateTime(2024)).inDays;
  return List.of(products)..shuffle(Random(day));
}
