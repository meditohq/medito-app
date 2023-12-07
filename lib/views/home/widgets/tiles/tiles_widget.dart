import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bottom_sheet/stats/stats_bottom_sheet_widget.dart';

class TilesWidget extends ConsumerWidget {
  const TilesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stats = ref.watch(remoteStatsProvider);

    return stats.when(
      skipLoadingOnRefresh: false,
      data: (data) => _buildTiles(context, ref, data.tiles),
      error: (err, stack) => Expanded(
        child: MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(remoteStatsProvider),
          isLoading: stats.isLoading,
          isScaffold: false,
        ),
      ),
      loading: () => TilesShimmerWidget(),
    );
  }

  Padding _buildTiles(
    BuildContext context,
    WidgetRef ref,
    List<TilesModel> data,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: data.map((e) {
          var fontStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: DmSerif,
                color: ColorConstants.getColorFromString(e.color),
              );

          return Expanded(
            child: InkWell(
              onTap: () => onTapTile(context, ref),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: ColorConstants.onyx,
                ),
                width: MediaQuery.of(context).size.width,
                padding: EdgeInsets.all(padding16),
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      IconData(formatIcon(e.icon), fontFamily: materialIcons),
                      size: 24,
                    ),
                    height8,
                    Text(
                      e.title,
                      style: fontStyle,
                    ),
                    height4,
                    Text(
                      e.subtitle,
                      style: fontStyle,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void onTapTile(BuildContext context, WidgetRef ref) {
    ref.invalidate(remoteStatsProvider);
    ref.read(remoteStatsProvider);
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14.0),
          topRight: Radius.circular(14.0),
        ),
      ),
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: ColorConstants.onyx,
      builder: (BuildContext context) {
        return StatsBottomSheetWidget();
      },
    );
  }
}
