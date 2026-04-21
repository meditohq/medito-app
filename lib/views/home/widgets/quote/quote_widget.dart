import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/views/home/widgets/quote/quote_share_sheet.dart';

class QuoteWidget extends ConsumerStatefulWidget {
  const QuoteWidget({super.key, required this.data});

  final HomeQuoteModel? data;

  @override
  ConsumerState<QuoteWidget> createState() => QuoteWidgetState();
}

class QuoteWidgetState extends ConsumerState<QuoteWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _shareQuote,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: padding24),
        child: _buildQuoteContent(),
      ),
    );
  }

  void _shareQuote() {
    if (widget.data == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuoteShareScreen(data: widget.data!),
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
    );
  }
}
