import 'package:flutter/material.dart';

import '../../constants/styles/widget_styles.dart';
import '../markdown_widget.dart';

class DescriptionWidget extends StatelessWidget {
  const DescriptionWidget({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    if (description == '') {
      return Container();
    }

    return Container(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: MarkdownWidget(
          body: description,
          selectable: true,
          textAlign: WrapAlignment.start,
          p: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontFamily: dmSans,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          a: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
