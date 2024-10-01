import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/widgets/network_image_widget.dart';

const _kAutoScrollDelay = Duration(seconds: 10);
const _kScrollAnimationDuration = Duration(milliseconds: 500);
const _kCardBorderRadius = 30.0;
const _kCardAspectRatio = 16 / 9;
const _kTitleFontSize = 24.0;
const _kSubtitleFontSize = 16.0;
const _kButtonHeight = 48.0;
const _kButtonBorderRadius = 20.0;
const _kButtonFontSize = 14.0;
const _kBannerFontSize = 14.0;
const _kSmallSpacing = 8.0;

class CarouselWidget extends ConsumerStatefulWidget {
  final List<HomeCarouselModel> carouselItems;

  const CarouselWidget({Key? key, required this.carouselItems})
      : super(key: key);

  @override
  ConsumerState<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends ConsumerState<CarouselWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScroll() {
    Future.delayed(_kAutoScrollDelay, () {
      if (_scrollController.hasClients && widget.carouselItems.length > 1) {
        var context = this.context;
        var screenSize = MediaQuery.of(context).size;
        var isHorizontal = screenSize.width > screenSize.height;
        var isTablet = screenSize.shortestSide >= 600;
        var cardWidth = isHorizontal || isTablet
            ? (screenSize.width / 2) - (3 * padding16)
            : screenSize.width - (3 * padding16);

        _scrollController.animateTo(
          cardWidth + padding16,
          duration: _kScrollAnimationDuration,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        height16,
        const Padding(
          padding: EdgeInsets.only(left: padding16),
          child: Text(
            'Featured',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              fontFamily: Teachers,
              fontSize: 20,
              height: 28 / 24,
            ),
          ),
        ),
        height8,
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.carouselItems.asMap().entries.map((entry) {
                int index = entry.key;
                HomeCarouselModel item = entry.value;
                return _buildCarouselItem(context, ref, index, item);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselItem(
      BuildContext context, WidgetRef ref, int index, HomeCarouselModel item) {
    final screenSize = MediaQuery.of(context).size;
    final isHorizontal = screenSize.width > screenSize.height;
    final isTablet = screenSize.shortestSide >= 600;

    var cardWidth = isHorizontal || isTablet
        ? (screenSize.longestSide / 2) - (3 * padding16)
        : screenSize.width - (3 * padding16);

    return Padding(
      padding: EdgeInsets.only(
        left: index == 0 ? padding16 : padding16 / 2,
        right: index == widget.carouselItems.length - 1
            ? padding16
            : padding16 / 2,
      ),
      child: SizedBox(
        width: cardWidth,
        child: _buildBanner(
          item,
          GestureDetector(
            onTap: () {
              handleNavigation(
                item.type,
                [item.path?.getIdFromPath()],
                context,
                ref: ref,
              );
            },
            child: Card(
              margin: EdgeInsets.zero,
              color: ColorConstants.onyx,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kCardBorderRadius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kCardBorderRadius),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: _kCardAspectRatio,
                      child: NetworkImageWidget(
                          url: item.coverUrl, shouldCache: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(padding16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              fontFamily: SourceSerif,
                              fontSize: 24,
                              height: 28 / 24,
                            ),
                          ),
                          const SizedBox(height: _kSmallSpacing),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              fontFamily: Teachers,
                              fontSize: 16,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: padding20),
                          if (item.buttons != null && item.buttons!.isNotEmpty)
                            _buildButtons(item, context, ref),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(HomeCarouselModel item, Widget child) {
    if (item.showBanner != true) {
      return child;
    }

    final bannerColor = item.bannerColor != null
        ? parseColor(item.bannerColor!)
        : ColorConstants.lightPurple;
    var bannerLabel = item.bannerLabel;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_kCardBorderRadius),
      child: Banner(
        message: bannerLabel ?? StringConstants.neww,
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

  Widget _buildButtons(
      HomeCarouselModel item, BuildContext context, WidgetRef ref) {
    return Row(
      children: item.buttons!.asMap().entries.map((entry) {
        var index = entry.key;
        var button = entry.value;

        return Expanded(
          child: Row(
            children: [
              if (index > 0) const SizedBox(width: padding16),
              Expanded(
                child: SizedBox(
                  height: _kButtonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConstants.white,
                      foregroundColor: ColorConstants.onyx,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(_kButtonBorderRadius),
                      ),
                    ),
                    onPressed: () => handleNavigation(
                      button.type,
                      [button.path.getIdFromPath()],
                      context,
                      ref: ref,
                    ),
                    child: Text(
                      button.title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: Teachers,
                        fontSize: _kButtonFontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: ColorConstants.onyx,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
