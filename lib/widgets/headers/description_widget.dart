import 'package:flutter/material.dart';

import '../../constants/colors/color_constants.dart';
import '../../constants/styles/widget_styles.dart';
import '../markdown_widget.dart';
class DescriptionWidget extends StatelessWidget {
  const DescriptionWidget({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    var bodyLarge = Theme.of(context).primaryTextTheme.bodyLarge;
    if (description == '') {
      return Container();
    }

    return Container(
      color: ColorConstants.onyx,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: MarkdownWidget(
          body: description,
          selectable: true,
          textAlign: WrapAlignment.start,
          p: bodyLarge?.copyWith(
            color: ColorConstants.white,
            fontFamily: dmSans,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          a: bodyLarge?.copyWith(
            color: ColorConstants.white,
            fontFamily: dmSans,
            decoration: TextDecoration.underline,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
