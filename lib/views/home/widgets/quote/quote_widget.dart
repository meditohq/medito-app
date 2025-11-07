import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:medito/widgets/medito_huge_icon.dart';

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
          color: Theme.of(context).colorScheme.onSurface,
        );

    final authorStyle = quoteStyle?.copyWith(
      color: quoteStyle.color?.withAlpha(((0.8).clamp(0.0, 1.0) * 255).round()),
      fontSize: 16,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        height16,
        Padding(
          padding: const EdgeInsets.only(left: padding16, right: padding16),
          child: Row(
            children: [
              Text(
                AppLocalizations.of(context)!.dailyQuote,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFamily: teachers,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      height: 28 / 24,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
        height8,
        Card(
          margin: const EdgeInsets.symmetric(horizontal: padding16),
          child: Padding(
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
                    icon: MeditoIcon(
                      assetName: Platform.isIOS
                          ? MeditoIcons.shareIos
                          : MeditoIcons.shareAndroid,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(((0.8).clamp(0.0, 1.0) * 255).round()),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _shareQuote() {
    if (widget.data == null) return;

    final shareText =
        '${widget.data?.quote}\n- ${widget.data?.author}\n\n${AppLocalizations.of(context)!.shareStatsText}';
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
