import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/logger.dart';

import '../../providers/home/home_provider.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/products_provider.dart';
import 'package:medito/providers/home/widget_order_provider.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/constants/constants.dart';
import 'widgets/announcement/announcement_widget.dart';
import 'widgets/editorial/carousel_widget.dart';
import 'widgets/header_widget.dart';
import 'widgets/products/products_widget.dart';
import 'widgets/quote/quote_widget.dart';
import 'widgets/shortcuts/shortcuts_items_widget.dart';

import '../../providers/home/announcement_provider.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final home = ref.watch(fetchHomeProvider);

    return home.when(
      loading: () => const HomeShimmerWidget(),
      error: (err, stack) {
        final error = err is AppError ? err : const UnknownError();

        return MeditoErrorWidget(
          error: error,
          onTap: () => _onRefresh(),
          isLoading: home.isLoading,
        );
      },
      data: (HomeModel homeData) {
        final widgetOrder = ref.watch(homeWidgetOrderProvider);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 56.0,
            title: HeaderWidget(
              greeting:
                  homeData.greeting ?? AppLocalizations.of(context)!.welcome,
              onStatsButtonTap: () => _onStatsButtonTapped(context),
            ),
            elevation: 0.0,
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                spacing: 20,
                children: [
                  _getAnnouncementBanner(),
                  ...widgetOrder.map((type) {
                    switch (type) {
                      case HomeWidgetType.shortcuts:
                        return ShortcutsItemsWidget(
                          key: ValueKey(type.name),
                          data: homeData.shortcuts,
                        );
                      case HomeWidgetType.carousel:
                        return CarouselWidget(
                          key: ValueKey(type.name),
                          carouselItems: homeData.carousel,
                        );
                      case HomeWidgetType.quote:
                        return QuoteWidget(
                          key: ValueKey(type.name),
                          data: homeData.todayQuote,
                        );
                      case HomeWidgetType.products:
                        return _getProductsWidget();
                    }
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _getProductsWidget() {
    final products = ref.watch(productsProvider);

    return products.when(
      loading: () {
        AppLogger.d('HomeView', 'Products are loading');
        return const SizedBox(height: 230);
      },
      error: (err, stack) {
        return const SizedBox.shrink();
      },
      data: (List<ProductGroupModel> productGroups) {
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

  Widget _getAnnouncementBanner() {
    final data = ref.watch(fetchLatestAnnouncementProvider);

    return data.when(
      loading: () => Container(),
      error: (err, stack) => Container(),
      data: (AnnouncementModel? announcement) {
        if (announcement == null ||
            announcement.text == null ||
            announcement.text == '') {
          return Container();
        }

        return AnnouncementWidget(
          announcement: announcement,
          onPressedDismiss: () {
            ref
                .read(dismissedAnnouncementProvider.notifier)
                .dismissAnnouncement(announcement.id!);
          },
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(fetchLatestAnnouncementProvider);
    await ref.read(fetchLatestAnnouncementProvider.future);
    ref.invalidate(refreshHomeAPIsProvider);
    await ref.read(refreshHomeAPIsProvider.future);
    ref.invalidate(refreshProductsProvider);
    await ref.read(refreshProductsProvider.future);
  }

  void _onStatsButtonTapped(BuildContext context) {
    handleNavigation(
      TypeConstants.route,
      [RouteConstants.stats],
      context,
      ref: ref,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
