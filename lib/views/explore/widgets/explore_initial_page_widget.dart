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
      data: (data) => _buildMain(ref, data, context),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchAllPacksProvider),
      ),
      loading: () => _buildLoadingWidget(),
    );
  }

  Widget _buildMain(
      WidgetRef ref,
      List<PackItemsModel> packs,
      BuildContext context,
      ) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.refresh(fetchAllPacksProvider),
                child: isPortrait
                    ? _buildListView(context, packs, ref)
                    : _buildGridView(context, packs, ref),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListView(
      BuildContext context,
      List<PackItemsModel> packs,
      WidgetRef ref,
      ) {
    return ListView.builder(
      itemCount: packs.length,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + padding16,
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
              element.type,
              [element.id.toString(), element.path],
              context,
              ref: ref,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(
      BuildContext context,
      List<PackItemsModel> packs,
      WidgetRef ref,
      ) {
    return GridView.builder(
      itemCount: packs.length,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + padding16,
        left: padding16,
        right: padding16,
        bottom: padding16,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: padding16,
        mainAxisSpacing: padding16,
        childAspectRatio: 8 / 2,
      ),
      itemBuilder: (context, index) {
        var element = packs[index];

        return PackCardWidget(
          title: element.title,
          subTitle: element.subtitle,
          coverUrlPath: element.coverUrl,
          onTap: () => handleNavigation(
            element.type,
            [element.id.toString(), element.path],
            context,
            ref: ref,
          ),
        );
      },
    );
  }

  ExploreInitialPageShimmerWidget _buildLoadingWidget() =>
      const ExploreInitialPageShimmerWidget();
}
