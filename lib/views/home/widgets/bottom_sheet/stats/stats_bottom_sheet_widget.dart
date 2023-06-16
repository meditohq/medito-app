import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../row_item_widget.dart';

class StatsBottomSheetWidget extends ConsumerWidget {
  const StatsBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stats = ref.watch(remoteStatsProvider);

    return DraggableSheetWidget(
      initialChildSize: 1,
      child: (scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            height16,
            HandleBarWidget(),
            height16,
            stats.when(
              skipLoadingOnRefresh: false,
              data: (data) => _statsList(scrollController, data, ref),
              error: (err, stack) => Expanded(
                child: MeditoErrorWidget(
                  message: err.toString(),
                  onTap: () => ref.refresh(remoteStatsProvider),
                ),
              ),
              loading: () => Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Expanded _statsList(
    ScrollController scrollController,
    StatsModel stats,
    WidgetRef ref,
  ) {
    return Expanded(
      child: ListView.builder(
        controller: scrollController,
        itemCount: stats.all.length,
        itemBuilder: (BuildContext context, int index) {
          var all = stats.all[index];

          return RowItemWidget(
            iconCodePoint: all.icon,
            iconSize: 20,
            title: all.title,
            subTitle: all.subtitle,
            isShowUnderline: index < stats.all.length - 1,
            isTrailingIcon: false,
            titleStyle:
                Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 18),
          );
        },
      ),
    );
  }
}
