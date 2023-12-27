import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteWidget extends ConsumerWidget {
  const QuoteWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var response = ref.watch(fetchQuoteProvider);
    var fontStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: SourceSerif,
          fontWeight: FontWeight.w500,
          fontSize: fontSize16,
          height: 1.4,
          color: ColorConstants.walterWhite,
        );

    return response.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: true,
      data: (data) {
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
                Text(
                  data.text,
                  style: fontStyle,
                  textAlign: TextAlign.center,
                ),
                height4,
                Text(
                  '— ${data.author}',
                  style: fontStyle,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchQuoteProvider),
        isLoading: response.isLoading,
        isScaffold: false,
      ),
      loading: () => const QuoteShimmerWidget(),
    );
  }
}
