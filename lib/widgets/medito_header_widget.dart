import 'package:Medito/utils/navigation_extra.dart';
import 'package:flutter/material.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget(this.title, this.description, this.imageUrl, {Key? key})
      : super(key: key);

  final title;
  final description;
  final imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.3,
          child: Stack(
            children: [
              buildHeroImage(imageUrl),
              _buildMeditoRoundCloseButton(),
              _buildTitleText(context),
            ],
          ),
        ),
        if (description != null && description != '') _buildDescription(context)
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              description ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeditoRoundCloseButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: MeditoRoundCloseButton(),
      ),
    );
  }

  Widget _buildTitleText(BuildContext context) {
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
          style: Theme.of(context).primaryTextTheme.headline4,
        ),
      ),
    );
  }

  Widget buildHeroImage(String imageUrl) {
    // return Image.asset(
    //   'assets/images/dalle.png',
    //   fit: BoxFit.fill,
    // );
    return Container();
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
