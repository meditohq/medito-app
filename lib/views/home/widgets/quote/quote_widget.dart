import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/home/home_model.dart';

class QuoteWidget extends ConsumerWidget {
  const QuoteWidget({super.key, required this.data});

  final HomeQuoteModel? data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fontStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: SourceSerif,
          fontWeight: FontWeight.w500,
          fontSize: fontSize16,
          height: 1.4,
          color: ColorConstants.walterWhite,
        );

    var quote = data?.text;
    var author = data?.author;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: ColorConstants.onyx,
      ),
      margin: const EdgeInsets.symmetric(horizontal: padding20),
      padding: const EdgeInsets.all(padding16),
      child: SelectionArea(
        child: Column(
          children: [
            if (quote != null)
              Text(
                quote,
                style: fontStyle,
                textAlign: TextAlign.center,
              )
            else
              Container(),
            height4,
            if (author != null)
              Text(
                '— $author',
                style: fontStyle,
                textAlign: TextAlign.center,
              )
            else
              Container(),
          ],
        ),
      ),
    );
  }
}
