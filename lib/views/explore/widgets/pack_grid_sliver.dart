import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/widgets/widgets.dart';

/// Two-column (three on tablets) masonry grid of pack cards, as a sliver.
/// Shared by the Explore tab and the search page.
class PackGridSliver extends ConsumerWidget {
  const PackGridSliver({super.key, required this.packs, this.onBeforeNavigate});

  final List<PackItem> packs;

  /// Runs before a card navigates, e.g. to dismiss the keyboard.
  final VoidCallback? onBeforeNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossAxisCount = (MediaQuery.sizeOf(context).width / 240)
        .floor()
        .clamp(2, 5);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(padding16, padding16, padding16, 0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: padding16,
        crossAxisSpacing: padding16,
        childCount: packs.length,
        itemBuilder: (context, index) {
          final item = packs[index];
          return RepaintBoundary(
            key: ValueKey('pack_${item.id}'),
            child: PackCardWidget(
              title: item.title,
              subTitle: item.subtitle,
              coverUrlPath: item.coverUrl,
              onTap: () {
                onBeforeNavigate?.call();
                handleNavigation(
                  TypeConstants.pack,
                  [item.id, item.path],
                  context,
                  ref: ref,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
