import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../row_item_widget.dart';
import 'package:share_plus/share_plus.dart';

import '../share_btn/share_btn_widget.dart';

class StatsBottomSheetWidget extends ConsumerWidget {
  const StatsBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stats = ref.watch(remoteStatsProvider);
    var globalKey = GlobalKey();

    return DraggableSheetWidget(
      initialChildSize: 0.7,
      maxChildSize: 0.8,
      expand: false,
      child: (scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            height16,
            HandleBarWidget(),
            height16,
            stats.when(
              skipLoadingOnRefresh: false,
              data: (data) =>
                  _statsList(context, scrollController, globalKey, data),
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
    BuildContext context,
    ScrollController scrollController,
    GlobalKey key,
    StatsModel stats,
  ) {
    return Expanded(
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            RepaintBoundary(
              key: key,
              child: Container(
                color: ColorConstants.onyx,
                child: Column(
                  children: stats.all.map((e) {
                    return RowItemWidget(
                      iconCodePoint: e.icon,
                      iconColor: e.color,
                      iconSize: 20,
                      title: e.title,
                      subTitle: e.subtitle,
                      hasUnderline: e.title != stats.all.last.title,
                      isTrailingIcon: false,
                      titleStyle: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontSize: 18),
                    );
                  }).toList(),
                ),
              ),
            ),
            ShareBtnWidget(
              globalKey: key,
              shareText: StringConstants.shareStatsText,
            ),
          ],
        ),
      ),
    );
  }
}
