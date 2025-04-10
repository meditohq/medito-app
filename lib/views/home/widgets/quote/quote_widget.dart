import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:share_plus/share_plus.dart';

class QuoteWidget extends ConsumerStatefulWidget {
  const QuoteWidget({super.key, required this.data});

  final HomeQuoteModel? data;

  @override
  ConsumerState<QuoteWidget> createState() => QuoteWidgetState();
}

class QuoteWidgetState extends ConsumerState<QuoteWidget> {
  @override
  Widget build(BuildContext context) {
    final quoteStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: sourceSerif,
          fontWeight: FontWeight.w300,
          fontSize: 18,
          height: 1.4,
          color: ColorConstants.white,
        );

    final authorStyle = quoteStyle?.copyWith(
      color: ColorConstants.white.withOpacity(0.6),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        height16,
        Padding(
          padding: const EdgeInsets.only(left: padding16, right: padding16),
          child: Row(
            children: [
              const Text(
                StringConstants.dailyQuote,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontFamily: teachers,
                  fontSize: 20,
                  height: 28 / 24,
                ),
              ),
            ],
          ),
        ),
        height8,
        Container(
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
              _buildQuoteContent(quoteStyle, authorStyle),
              Positioned(
                right: -12,
                bottom: -12,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _shareQuote,
                  icon: HugeIcon(
                    icon: Platform.isIOS
                        ? HugeIcons.solidRoundedShare03
                        : HugeIcons.solidRoundedShare08,
                    color: Colors.white.withOpacity(0.6),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _shareQuote() {
    if (widget.data == null) return;

    final shareText =
        '${widget.data?.quote}\n- ${widget.data?.author}\n\n${StringConstants.shareStatsText}';
    Share.share(shareText);
  }

  Widget _buildQuoteContent(TextStyle? quoteStyle, TextStyle? authorStyle) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.data?.quote != null)
            Padding(
              padding: const EdgeInsets.only(right: 60.0),
              child: Text(
                widget.data!.quote,
                style: quoteStyle,
              ),
            ),
          if (widget.data?.author != null) ...[
            height4,
            Text(
              widget.data!.author,
              style: authorStyle,
            ),
          ],
        ],
      ),
    );
  }
}
