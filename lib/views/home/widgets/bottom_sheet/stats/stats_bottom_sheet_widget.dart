import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../models/stats/stats_model.dart';
import '../row_item_widget.dart';
import '../share_btn/share_btn_widget.dart';

class StatsBottomSheetWidget extends ConsumerWidget {
  const StatsBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stats = ref.watch(fetchStatsProvider);
    var globalKey = GlobalKey();

    return SafeArea(
      child: Container(
        decoration: bottomSheetBoxDecoration,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              height16,
              const HandleBarWidget(),
              height16,
              stats.when(
                skipLoadingOnRefresh: false,
                data: (data) => _statsList(context, globalKey, data),
                error: (err, stack) => Expanded(
                  child: MeditoErrorWidget(
                    message: err.toString(),
                    onTap: () => ref.refresh(fetchStatsProvider),
                  ),
                ),
                loading: () => const SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ],
          ),
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
              children: stats.all.map((e) {
                return RowItemWidget(
                  icon: IconType.fromString(e.icon),
                  iconColor: e.color,
                  trailingIconSize: 20,
                  title: e.title,
                  subTitle: e.subtitle,
                  hasUnderline: e.title != stats.all.last.title,
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
