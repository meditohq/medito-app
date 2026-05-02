// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';

import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/network_image_widget.dart';
import '../home_gradient_border.dart';

const _kCardBorderRadius = 20.0;
const _kBannerFontSize = 16.0;
const _kCarouselHeight = 180.0;

class CarouselWidget extends ConsumerStatefulWidget {
  final List<HomeCarouselModel> carouselItems;

  const CarouselWidget({super.key, required this.carouselItems});

  @override
  ConsumerState<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends ConsumerState<CarouselWidget> {
  final CarouselController _controller = CarouselController();
  bool _showLeftGradient = false;
  bool _showRightGradient = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showLeft =
        _controller.hasClients && _controller.position.pixels > 10;
    final showRight = _controller.hasClients &&
        _controller.position.pixels <
            _controller.position.maxScrollExtent - 10;
    if (showLeft != _showLeftGradient || showRight != _showRightGradient) {
      setState(() {
        _showLeftGradient = showLeft;
        _showRightGradient = showRight;
      });
    }

    _checkIndexChange();
  }

  void _checkIndexChange() {
    if (!_controller.hasClients) return;

    final itemCount = widget.carouselItems.length + 2;
    final maxExtent = _controller.position.maxScrollExtent;
    final pixels = _controller.position.pixels;
    final itemWidth = maxExtent / (itemCount - 1);
    final newIndex = (pixels / itemWidth).round().clamp(0, itemCount - 1);

    if (newIndex != _currentIndex && newIndex < widget.carouselItems.length) {
      _currentIndex = newIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >
            MediaQuery.of(context).size.height ||
        MediaQuery.of(context).size.shortestSide >= 600;

    final flexWeights = isWide ? [4, 3, 3, 3] : [4, 3, 2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: padding16),
          child: Text(
            AppLocalizations.of(context)!.carouselTitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFamily: teachers,
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  height: 28 / 24,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
        height8,
        Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _kCarouselHeight,
              ),
              child: CarouselView.weighted(
                controller: _controller,
                itemSnapping: true,
                flexWeights: flexWeights,
                consumeMaxWeight: false,
                padding: const EdgeInsets.only(left: padding16),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kCardBorderRadius),
                ),
                onTap: (index) => _onItemTap(index),
                children: [
                  ...widget.carouselItems.map((item) {
                    return _buildCarouselItem(context, item);
                  }),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                ],
              ),
            ),
            if (_showLeftGradient)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 32,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor,
                          Theme.of(context)
                              .scaffoldBackgroundColor
                              .withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_showRightGradient)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 32,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor,
                          Theme.of(context)
                              .scaffoldBackgroundColor
                              .withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _onItemTap(int index) {
    final item = widget.carouselItems[index];
    handleNavigation(
      item.type,
      [item.path.toString().getIdFromPath(), item.path],
      context,
      ref: ref,
    );
  }

  Widget _buildCarouselItem(BuildContext context, HomeCarouselModel item) {
    final cardColor = Theme.of(context).cardColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.55;

    return Semantics(
      label: item.title,
      button: true,
      child: _buildBanner(
        item,
        HomeGradientBorder(
          backgroundColor: cardColor,
          borderRadius: _kCardBorderRadius,
          borderWidth: 0.5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              OverflowBox(
                maxWidth: imageWidth,
                minWidth: imageWidth,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: imageWidth,
                  child:
                      NetworkImageWidget(url: item.coverUrl, shouldCache: true),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 36, 10, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: dmSans,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: Colors.white,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(HomeCarouselModel item, Widget child) {
    if (item.showBanner != true) return child;

    final bannerColor = item.bannerColor != null
        ? parseColor(item.bannerColor!)
        : context.brandPurple;

    return Banner(
      message: item.bannerLabel ?? AppLocalizations.of(context)!.neww,
      location: BannerLocation.topStart,
      color: bannerColor,
      textStyle: TextStyle(
        color: parseColor(item.bannerLabelColor),
        fontSize: _kBannerFontSize,
        fontWeight: FontWeight.bold,
      ),
      child: child,
    );
  }
}
