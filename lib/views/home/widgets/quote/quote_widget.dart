import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteWidget extends ConsumerWidget {
  const QuoteWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var response = ref.watch(fetchQuoteProvider);

    return response.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (data) {
        return Text(data.text);
      },
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(homeProvider),
        isLoading: response.isLoading,
      ),
      loading: () => const QuoteShimmerWidget(),
    );
  }
}
