import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/constants/strings/string_constants.dart';

class CarouselWidget extends ConsumerWidget {
  final List<HomeCarouselModel> carouselItems;

  const CarouselWidget({Key? key, required this.carouselItems})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: carouselItems.asMap().entries.map((entry) {
            int index = entry.key;
            HomeCarouselModel item = entry.value;
            return _buildCarouselItem(context, ref, index, item);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCarouselItem(
      BuildContext context, WidgetRef ref, int index, HomeCarouselModel item) {
    final screenSize = MediaQuery.of(context).size;
    final isHorizontal = screenSize.width > screenSize.height;
    final isTablet = screenSize.shortestSide >= 600;

    double cardWidth;
    if (isHorizontal || isTablet) {
      cardWidth = (screenSize.width / 2) - (3 * padding16);
    } else {
      cardWidth = screenSize.width - (3 * padding16);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: index == 0 ? padding16 : padding16 / 2,
        right: index == carouselItems.length - 1 ? padding16 : padding16 / 2,
      ),
      child: SizedBox(
        width: cardWidth,
        child: _buildBanner(
          item,
          Card(
            margin: EdgeInsets.zero,
            color: ColorConstants.onyx,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(item.coverUrl, fit: BoxFit.cover),
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
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                            fontFamily: DmSans,
                            fontSize: 16,
                            height: 1.1,
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
      borderRadius: BorderRadius.circular(30),
      child: Banner(
        message: bannerLabel ?? StringConstants.neww,
        location: BannerLocation.topStart,
        color: bannerColor,
        textStyle: TextStyle(
          color: parseColor(item.bannerLabelColor),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        child: child,
      ),
    );
  }

  Widget _buildButtons(
      HomeCarouselModel item, BuildContext context, WidgetRef ref) {
    return Row(
      children: item.buttons!.map((button) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: parseColor(button.color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () => handleNavigation(
                  button.type,
                  [button.path],
                  context,
                  ref: ref,
                ),
                child: Text(
                  button.title,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: DmSans,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
