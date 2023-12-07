import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TilesWidget extends ConsumerWidget {
  const TilesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stats = ref.watch(remoteStatsProvider);

    return stats.when(
      skipLoadingOnRefresh: false,
      data: (data) => _buildTiles(context, data.tiles),
      error: (err, stack) => Expanded(
        child: MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(remoteStatsProvider),
        ),
      ),
      loading: () => TilesShimmerWidget(),
    );
  }

  Padding _buildTiles(BuildContext context, List<TilesModel> data) {
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
          );
        }).toList(),
      ),
    );
  }
}
