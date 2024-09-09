import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/widgets/widgets.dart';
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

  Widget _buildMain(
    WidgetRef ref,
    List<PackItemsModel> packs,
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
                    : _buildGridView(packs, ref),
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
    List<PackItemsModel> packs,
    WidgetRef ref,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the width of each grid item
        double itemWidth = (constraints.maxWidth - padding16 * 3) / 2;

        // Define a maximum height for each grid item
        double maxItemHeight = 140.0; // Adjust this value as needed

        // Calculate the aspect ratio based on the item width and the max height
        double childAspectRatio = itemWidth / maxItemHeight;

        return GridView.builder(
          itemCount: packs.length,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + padding16,
            left: padding16,
            right: padding16,
            bottom: padding16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: padding16,
            mainAxisSpacing: padding16,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            var element = packs[index];

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxItemHeight,
              ),
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
      },
    );
  }

  ExploreInitialPageShimmerWidget _buildLoadingWidget() =>
      const ExploreInitialPageShimmerWidget();
}
