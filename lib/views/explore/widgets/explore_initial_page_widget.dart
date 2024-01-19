import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExploreInitialPageWidget extends ConsumerWidget {
  const ExploreInitialPageWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var allPacks = ref.watch(fetchAllPacksProvider);

    return allPacks.when(
      skipLoadingOnRefresh: false,
      data: (data) => _buildMain(ref, data),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchAllPacksProvider),
      ),
      loading: () => _buildLoadingWidget(),
    );
  }

  Column _buildMain(
    WidgetRef ref,
    List<PackItemsModel> packs,
  ) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(fetchAllPacksProvider),
            child: ListView.builder(
              itemCount: packs.length,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                top: padding20,
                left: padding16,
                right: padding16,
                bottom: padding16,
              ),
              itemBuilder: (context, index) {
                var element = packs[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: padding16),
                  child: PackCardWidget(
                    title: element.title,
                    subTitle: element.subtitle,
                    coverUrlPath: element.coverUrl,
                    onTap: () => handleNavigation(
                      context: context,
                      element.type,
                      [element.id.toString(), element.path],
                      ref: ref,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  ExploreInitialPageShimmerWidget _buildLoadingWidget() =>
      const ExploreInitialPageShimmerWidget();
}
