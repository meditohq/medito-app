import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackButtonsWidget extends StatelessWidget {
  final TrackModel trackModel;
  const TrackButtonsWidget({super.key, required this.trackModel});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: trackModel.audio.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _guideName(context, trackModel.audio[i].guideName),
            _gridList(i),
            SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _guideName(BuildContext context, String? guideName) {
    if (guideName != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guideName,
            style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                  color: ColorConstants.walterWhite,
                ),
          ),
          height8,
        ],
      );
    }

    return SizedBox();
  }

  GridView _gridList(
    int i,
  ) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (BuildContext context, int index) {
        return _getGridItem(trackModel.audio[i].files[index]);
      },
      itemCount: trackModel.audio[i].files.length,
    );
  }

  Consumer _getGridItem(
    TrackFilesModel file,
  ) {
    return Consumer(
      builder: (context, ref, child) => InkWell(
        onTap: () => _handleTap(ref, file),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            color: ColorConstants.onyx,
            borderRadius: BorderRadius.all(
              Radius.circular(14),
            ),
          ),
          child: Center(
            child: Text(
              '${convertDurationToMinutes(milliseconds: file.duration)} mins',
              style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: DmMono,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(
    WidgetRef ref,
    TrackFilesModel file,
  ) async {
    final audioProvider = ref.read(audioPlayerNotifierProvider);
    audioProvider.clearAssetCache();
    await ref
        .read(playerProvider.notifier)
        .addCurrentlyPlayingTrackInPreference(
          trackModel: trackModel,
          file: file,
        );
    ref.read(pageviewNotifierProvider).gotoNextPage();
  }
}
