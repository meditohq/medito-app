import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/widgets/widgets.dart';

class ExploreView extends ConsumerWidget {
  const ExploreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorConstants.ebony,
        toolbarHeight: 92.0,
        title: const Column(
          children: [
            HomeHeaderWidget(greeting: StringConstants.explore),
            SizedBox(height: 18.0),
          ],
        ),
        elevation: 0.0,
      ),
      body: const ExploreInitialPageWidget(),
    );
  }
}

class ExploreInitialPageWidget extends ConsumerWidget {
  const ExploreInitialPageWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var allPacks = ref.watch(fetchAllPacksProvider);

    return allPacks.when(
      data: (data) => _buildMain(ref, data),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchAllPacksProvider),
      ),
      loading: () => const ExploreInitialPageShimmerWidget(),
    );
  }

  Widget _buildMain(WidgetRef ref, List<PackItemsModel> packs) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(fetchAllPacksProvider),
          child: isPortrait
              ? _buildListView(context, packs, ref)
              : _buildGridView(packs, ref),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context, List<PackItemsModel> packs, WidgetRef ref) {
    return ListView.builder(
      itemCount: packs.length,
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).padding.top + padding16,
        horizontal: padding16,
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

  Widget _buildGridView(List<PackItemsModel> packs, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var itemWidth = (constraints.maxWidth - padding16 * 3) / 2;
        var maxItemHeight = 140.0;

        return GridView.builder(
          itemCount: packs.length,
          padding: EdgeInsets.symmetric(
            vertical: MediaQuery.of(context).padding.top + padding16,
            horizontal: padding16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: padding16,
            mainAxisSpacing: padding16,
            childAspectRatio: itemWidth / maxItemHeight,
          ),
          itemBuilder: (context, index) {
            var element = packs[index];
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxItemHeight),
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
}
