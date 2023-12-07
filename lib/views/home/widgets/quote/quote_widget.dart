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
          fontFamily: DmSerif,
          color: ColorConstants.walterWhite,
        );

    return response.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (data) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: padding20),
          child: Column(
            children: [
              Text(
                data.text,
                style: fontStyle,
                textAlign: TextAlign.center,
              ),
              Text(
                '— ${data.author}',
                style: fontStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchQuoteProvider),
        isLoading: response.isLoading,
      ),
      loading: () => const QuoteShimmerWidget(),
    );
  }
}
