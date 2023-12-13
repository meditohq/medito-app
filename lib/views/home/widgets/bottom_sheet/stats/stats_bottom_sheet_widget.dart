import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../row_item_widget.dart';
import '../share_btn/share_btn_widget.dart';

class StatsBottomSheetWidget extends ConsumerWidget {
  const StatsBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stats = ref.watch(remoteStatsProvider);
    var globalKey = GlobalKey();

    return Container(
      decoration: bottomSheetBoxDecoration,
      padding: EdgeInsets.only(bottom: getBottomPadding(context)),
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            height16,
            HandleBarWidget(),
            height16,
            stats.when(
              skipLoadingOnRefresh: false,
              data: (data) => _statsList(context, globalKey, data),
              error: (err, stack) => Expanded(
                child: MeditoErrorWidget(
                  message: err.toString(),
                  onTap: () => ref.refresh(remoteStatsProvider),
                ),
              ),
              loading: () => SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Column _statsList(
    BuildContext context,
    GlobalKey key,
    StatsModel stats,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: key,
          child: Container(
            color: ColorConstants.onyx,
            child: Column(
              children: stats.allStats.map((e) {
                return RowItemWidget(
                  iconCodePoint: e.icon,
                  iconColor: e.color,
                  trailingIconSize: 20,
                  title: e.title,
                  subTitle: e.subtitle,
                  hasUnderline: e.title != stats.allStats.last.title,
                  isTrailingIcon: false,
                  titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: DmSans,
                      ),
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
    );
  }
}
