import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/theme/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EmptyStateWidget extends StatelessWidget {
  final String? message;
  final SvgPicture? image;
  const EmptyStateWidget({Key? key, this.message, this.image})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Text(message ?? '',
              textAlign: TextAlign.start,
              style: meditoTextTheme(context).subtitle1),
        ),
        Divider(
          color: MeditoColors.softGrey,
        ),
        Expanded(child: Center(child: image)),
      ],
    );
  }
}
