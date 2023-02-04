import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:flutter/material.dart';

class StackHeaderComponent extends StatelessWidget {
  const StackHeaderComponent(
      {this.title, this.description, this.imageUrl, Key? key})
      : super(key: key);

  final String? title;
  final String? description;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.3,
          child: Stack(
            children: [
              if (imageUrl != null) buildHeroImage(imageUrl!),
              _buildMeditoRoundCloseButton(),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 80,
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(boxShadow: [
                    BoxShadow(
                        color: MeditoColors.almostBlack.withOpacity(0.4),
                        offset: Offset(0, 10),
                        blurRadius: 10,
                        spreadRadius: 20)
                  ]),
                ),
              ),
              if (title != null) _buildTitleText(context, title!),
            ],
          ),
        ),
        if (description != null) _buildDescription(context, description!)
      ],
    );
  }

  Container _buildDescription(BuildContext context, String description) {
    return Container(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              child: Text(
                description,
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SafeArea _buildMeditoRoundCloseButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: MeditoRoundCloseButton(),
      ),
    );
  }

  Align _buildTitleText(BuildContext context, String title) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          bottom: 12.0,
        ),
        child: Text(
          title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).primaryTextTheme.headline4?.copyWith(
              fontFamily: 'Clash Display', color: MeditoColors.walterWhite),
        ),
      ),
    );
  }

  Image buildHeroImage(String imageUrl) {
    return Image.asset(
      imageUrl,
      fit: BoxFit.fill,
    );
  }
}

class MeditoRoundCloseButton extends StatelessWidget {
  const MeditoRoundCloseButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () {
        router.pop();
      },
      color: Colors.black38,
      padding: EdgeInsets.all(16),
      shape: CircleBorder(),
      child: Icon(
        Icons.close,
        color: Colors.white,
      ),
    );
  }
}
