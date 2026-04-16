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

const _kCardBorderRadius = 24.0;
const _kCardAspectRatio = 2 / 3;
const _kBannerFontSize = 16.0;

class CarouselWidget extends ConsumerStatefulWidget {
  final List<HomeCarouselModel> carouselItems;

  const CarouselWidget({super.key, required this.carouselItems});

  @override
  ConsumerState<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends ConsumerState<CarouselWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _cardWidth(Size screenSize) {
    final isWide = screenSize.width > screenSize.height ||
        screenSize.shortestSide >= 600;
    return isWide ? screenSize.width / 5.0 : screenSize.width / 3.2;
  }

  @override
  Widget build(BuildContext context) {
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
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: padding16 / 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.carouselItems.asMap().entries.map((entry) {
              return _buildCarouselItem(context, ref, entry.key, entry.value);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    HomeCarouselModel item,
  ) {
    final cardWidth = _cardWidth(MediaQuery.of(context).size);

    return Padding(
      padding: EdgeInsets.only(
        left: index == 0 ? padding16 : padding16 / 2,
        right: padding16 / 2,
      ),
      child: SizedBox(
        width: cardWidth,
        child: _buildBanner(item, _buildCard(context, item, ref)),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    HomeCarouselModel item,
    WidgetRef ref,
  ) {
    final cardColor = Theme.of(context).cardColor;

    return Semantics(
      label: item.title,
      button: true,
      child: GestureDetector(
        onTap: () {
          handleNavigation(
            item.type,
            [item.path.toString().getIdFromPath(), item.path],
            context,
            ref: ref,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(_kCardBorderRadius),
            border: Border.all(
              color: Color.lerp(cardColor, Colors.white, 0.3) ?? cardColor,
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kCardBorderRadius),
            child: AspectRatio(
              aspectRatio: _kCardAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageWidget(url: item.coverUrl, shouldCache: true),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(_kCardBorderRadius),
      child: Banner(
        message: item.bannerLabel ?? AppLocalizations.of(context)!.neww,
        location: BannerLocation.topStart,
        color: bannerColor,
        textStyle: TextStyle(
          color: parseColor(item.bannerLabelColor),
          fontSize: _kBannerFontSize,
          fontWeight: FontWeight.bold,
        ),
        child: child,
      ),
    );
  }
}
