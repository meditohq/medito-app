import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackgroundImageComponent extends ConsumerWidget {
  const BackgroundImageComponent({Key? key, required this.imageUrl})
      : super(key: key);
  final String imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
    var scrollProportion =
        ref.watch(pageviewNotifierProvider).scrollProportion.toDouble();
    var opacity = (1 - scrollProportion) * 0.40;

    print(opacity);

    return Stack(
      children: [
        Container(
          height: size.height,
          color: Color.lerp(
            ColorConstants.greyIsTheNewBlack,
            ColorConstants.greyIsTheNewGrey,
            scrollProportion,
          ),
        ),
        AnimatedOpacity(
          opacity: opacity,
          duration: Duration(milliseconds: 250),
          child: SizedBox(
            height: size.height,
            child: NetworkImageComponent(
              url: imageUrl,
              isCache: true,
            ),
          ),
        ),
      ],
    );
  }
}
