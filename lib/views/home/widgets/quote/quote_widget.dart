import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/home/widgets/quote/quote_share_sheet.dart';
import 'package:medito/widgets/medito_icon.dart';

class QuoteWidget extends ConsumerStatefulWidget {
  const QuoteWidget({super.key, required this.data});

  final HomeQuoteModel? data;

  @override
  ConsumerState<QuoteWidget> createState() => QuoteWidgetState();
}

class QuoteWidgetState extends ConsumerState<QuoteWidget> {
  @override
  Widget build(BuildContext context) {
    // Wrap in Material + InkWell instead of GestureDetector so users get a
    // ripple on tap — that, plus the share pill below, is what tells them
    // the quote is interactive.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.data == null ? null : _shareQuote,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 8,
            ),
            child: _buildQuoteContent(),
          ),
        ),
      ),
    );
  }

  void _shareQuote() {
    final data = widget.data;
    if (data == null) return;

    // Fire-and-forget — analytics shouldn't block navigation.
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.quoteShareOpened,
        parameters: {
          AnalyticsEventConstants.paramQuoteId: data.id,
          AnalyticsEventConstants.paramQuoteAuthor: data.author,
        },
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuoteShareScreen(data: data),
      ),
    );
  }

  Widget _buildQuoteContent() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.data?.quote != null)
            Text(
              widget.data!.quote,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: sourceSerif,
                fontWeight: FontWeight.w300,
                fontSize: 18,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (widget.data?.author != null) ...[
            height12,
            // Author line with a small share glyph appended after a thin gap.
            // Just enough of a hint that the quote is tappable, without the
            // weight of a labeled button.
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '— ${widget.data!.author}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: dmSans,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                MeditoIcon(
                  assetName: Platform.isIOS
                      ? MeditoIcons.shareIos
                      : MeditoIcons.shareAndroid,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                  semanticLabel: AppLocalizations.of(context)!.tapToShare,
                ),
              ],
            ),
          ],
        ],
    );
  }
}
