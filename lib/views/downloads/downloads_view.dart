import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/duration_extensions.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/empty_widget.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:Medito/views/packs/pack_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadsView extends ConsumerStatefulWidget {
  @override
  ConsumerState<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends ConsumerState<DownloadsView>
    with SingleTickerProviderStateMixin {
  final key = GlobalKey<AnimatedListState>();
  var scaffoldKey = GlobalKey<ScaffoldState>();
  List<MeditationModel> downloadedMeditations = [];

  @override
  Widget build(BuildContext context) {
    final downloadedMeditations = ref.watch(downloadedMeditationsProvider);

    return Scaffold(
      appBar: MeditoAppBarWidget(
        title: StringConstants.downloads,
        isTransparent: true,
        hasCloseButton: true,
      ),
      key: scaffoldKey,
      body: downloadedMeditations.when(
        skipLoadingOnRefresh: false,
        data: (data) {
          if (data.isEmpty) {
            return _getEmptyWidget();
          }

          return _getDownloadList(data);
        },
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(downloadedMeditationsProvider),
        ),
        loading: () => MeditationShimmerWidget(),
      ),
    );
  }

  Widget _getDownloadList(List<MeditationModel> meditations) {
    // In order for the Dismissible action still to work on the list items,
    // the default ReorderableListView is used (instead of the .builder one)
    return ReorderableListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          var reorderedItem = meditations.removeAt(oldIndex);
          meditations.insert(newIndex, reorderedItem);
          // To ensure, that the new list order is saved
          ref.read(
            addMeditationListInPreferenceProvider(meditations: meditations),
          );
        });
      },
      children:
          meditations.map((item) => _getSlidingItem(item, context)).toList(),
    );
  }

  Widget _getEmptyWidget() => EmptyStateWidget(
        message: StringConstants.emptyDownloadsMessage,
      );

  Widget _getSlidingItem(MeditationModel item, BuildContext context) {
    return InkWell(
      // This (additional) key is required in order for the ReorderableListView to distinguish between the different list items
      key: ValueKey('${item.id}-${item.audio.first.files.first.id}'),
      onTap: () {
        _openPlayer(ref, item);
      },
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.endToStart,
        background: _getDismissibleBackgroundWidget(),
        onDismissed: (direction) {
          if (mounted) {
            ref.watch(audioDownloaderProvider).deleteMeditationAudio(
                  '${item.id}-${item.audio.first.files.first.id}${getFileExtension(item.audio.first.files.first.path)}',
                );
            ref.read(deleteMeditationFromPreferenceProvider(
              file: item.audio.first.files.first,
            ).future);
          }
          createSnackBar(
            '"${item.title}" ${StringConstants.removed.toLowerCase()}',
            context,
            color: ColorConstants.walterWhite,
          );
        },
        child: _getListItemWidget(item),
      ),
    );
  }

  Widget _getDismissibleBackgroundWidget() => Container(
        color: ColorConstants.moonlight,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Spacer(),
              Icon(
                Icons.delete,
                color: Colors.redAccent,
              ),
            ],
          ),
        ),
      );

  PackListItemWidget _getListItemWidget(MeditationModel item) {
    var audioLength =
        Duration(milliseconds: item.audio.first.files.first.duration)
            .inMinutes
            .toString();
    var guideName = item.audio.first.guideName;
    var duration = _getDuration(audioLength);
    var subTitle = guideName != null ? '$guideName — $duration' : '$duration';

    return PackListItemWidget(
      PackImageListItemData(
        title: item.title,
        subtitle: subTitle,
        cover: item.coverUrl,
        coverSize: 70,
      ),
    );
  }

  String _getDuration(String? length) => formatMeditationLength(length);

  void _openPlayer(
    WidgetRef ref,
    MeditationModel meditationModel,
  ) {
    ref.read(playerProvider.notifier).addCurrentlyPlayingMeditationInPreference(
          meditationModel: meditationModel,
          file: meditationModel.audio.first.files.first,
        );
    ref.read(pageviewNotifierProvider).gotoNextPage();
  }

  void showSwipeToDeleteTip() {
    createSnackBar(
      StringConstants.swipeToDelete,
      context,
      color: ColorConstants.walterWhite,
    );
  }
}
