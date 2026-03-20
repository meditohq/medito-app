import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/utils/utils.dart';

class QuoteWidget extends ConsumerStatefulWidget {
  const QuoteWidget({super.key, required this.data});

  final HomeQuoteModel? data;

  @override
  ConsumerState<QuoteWidget> createState() => QuoteWidgetState();
}

class QuoteWidgetState extends ConsumerState<QuoteWidget> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: padding24, horizontal: padding20),
            child: _buildQuoteContent(),
          ),
          Positioned(
            right: -12,
            bottom: -12,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: AppLocalizations.of(context)!.share,
              onPressed: _shareQuote,
              icon: MeditoIcon(
                assetName: Platform.isIOS
                    ? MeditoIcons.shareIos
                    : MeditoIcons.shareAndroid,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacityValue(0.8),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareQuote() {
    if (widget.data == null) return;

    final shareText =
        '${widget.data?.quote}\n- ${widget.data?.author}\n\n${AppLocalizations.of(context)!.shareStatsText}';
    SharePlus.instance.share(ShareParams(text: shareText));
  }

  Widget _buildQuoteContent() {
    return SelectionArea(
      child: Column(
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
            Text(
              '— ${widget.data!.author}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: dmSans,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
