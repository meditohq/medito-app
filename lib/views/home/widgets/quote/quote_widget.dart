import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';

class QuoteWidget extends ConsumerWidget {
  const QuoteWidget({super.key, required this.data});

  final HomeQuoteModel? data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: SourceSerif,
          fontWeight: FontWeight.w300,
          fontSize: 18,
          height: 1.4,
          color: ColorConstants.white,
        );

    final authorStyle = quoteStyle?.copyWith(
      color: ColorConstants.white.withOpacity(0.6),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: ColorConstants.onyx,
      ),
      margin: const EdgeInsets.symmetric(horizontal: padding16),
      padding: const EdgeInsets.all(padding16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildBackgroundIcon(),
          _buildQuoteContent(quoteStyle, authorStyle),
        ],
      ),
    );
  }

  Widget _buildBackgroundIcon() {
    return Positioned(
      top: -30,
      right: -20,
      child: Opacity(
        opacity: 0.07,
        child: HugeIcon(
          icon: Icons.format_quote,
          color: ColorConstants.white,
          size: 100,
        ),
      ),
    );
  }

  Widget _buildQuoteContent(TextStyle? quoteStyle, TextStyle? authorStyle) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data?.quote != null)
            Padding(
              padding: const EdgeInsets.only(right: 60.0),
              child: Text(
                data!.quote,
                style: quoteStyle,
              ),
            ),
          if (data?.author != null) ...[
            height4,
            Text(
              data!.author,
              style: authorStyle,
            ),
          ],
        ],
      ),
    );
  }
}
