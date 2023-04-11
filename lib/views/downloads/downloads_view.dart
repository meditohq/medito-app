import 'package:Medito/components/components.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/duration_extensions.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/view_model/player/download/audio_downloader_viewmodel.dart';
import 'package:Medito/view_model/session/session_viewmodel.dart';
import 'package:Medito/views/empty_widget.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:Medito/views/packs/pack_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class DownloadsView extends ConsumerStatefulWidget {
  @override
  ConsumerState<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends ConsumerState<DownloadsView>
    with SingleTickerProviderStateMixin {
  final key = GlobalKey<AnimatedListState>();
  var scaffoldKey = GlobalKey<ScaffoldState>();
  List<SessionModel> downloadedSessions = [];

  @override
  Widget build(BuildContext context) {
    final downloadedSessions = ref.watch(downloadedSessionsProvider);

    return Scaffold(
      appBar: MeditoAppBarWidget(
        title: StringConstants.DOWNLOADS,
        isTransparent: true,
        hasCloseButton: true,
      ),
      key: scaffoldKey,
      body: downloadedSessions.when(
        skipLoadingOnRefresh: false,
        data: (data) {
          if (data.isEmpty) {
            return _getEmptyWidget();
          }

          return _getDownloadList(data);
        },
        error: (err, stack) => ErrorComponent(
          message: err.toString(),
          onTap: () => ref.refresh(downloadedSessionsProvider),
        ),
        loading: () => SessionShimmerComponent(),
      ),
    );
  }

  Widget _getDownloadList(List<SessionModel> sessions) {
    // In order for the Dismissible action still to work on the list items,
    // the default ReorderableListView is used (instead of the .builder one)
    return ReorderableListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          var reorderedItem = sessions.removeAt(oldIndex);
          sessions.insert(newIndex, reorderedItem);
          // To ensure, that the new list order is saved
          ref.read(addSessionListInPreferenceProvider(sessions: sessions));
        });
      },
      children: sessions.map((item) => _getSlidingItem(item, context)).toList(),
    );
  }

  Widget _getEmptyWidget() => EmptyStateWidget(
        message: StringConstants.EMPTY_DOWNLOADS_MESSAGE,
        image: SvgPicture.asset(
          AssetConstants.dalle,
          height: 168,
          width: 178,
        ),
      );

  Widget _getSlidingItem(SessionModel item, BuildContext context) {
    return InkWell(
      // This (additional) key is required in order for the ReorderableListView to distinguish between the different list items
      key: ValueKey('${item.id}-${item.audio.first.files.first.id}'),
      onTap: () {
        _openPlayer(item, context);
      },
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.endToStart,
        background: _getDismissibleBackgroundWidget(),
        onDismissed: (direction) {
          if (mounted) {
            ref.watch(audioDownloaderProvider).deleteSessionAudio(
                  '${item.id}-${item.audio.first.files.first.id}${getFileExtension(item.audio.first.files.first.path)}',
                );
            ref.read(deleteSessionFromPreferenceProvider(
              sessionModel: item,
              file: item.audio.first.files.first,
            ).future);
          }
          createSnackBar(
            '"${item.title}" ${StringConstants.REMOVED.toLowerCase()}',
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

  PackListItemWidget _getListItemWidget(SessionModel item) {
    var audioLength =
        Duration(milliseconds: item.audio.first.files.first.duration)
            .inMinutes
            .toString();

    return PackListItemWidget(
      PackImageListItemData(
        title: item.title,
        subtitle:
            '${item.audio.first.guideName} — ${_getDuration(audioLength)}',
        cover: item.coverUrl,
        coverSize: 70,
      ),
    );
  }

  String _getDuration(String? length) => formatSessionLength(length);

  void _openPlayer(SessionModel sessionModel, BuildContext context) {
    context.go(
      GoRouter.of(context).location + PlayerPath,
      extra: {
        'sessionModel': sessionModel,
        'file': sessionModel.audio.first.files.first,
      },
    );
  }

  void showSwipeToDeleteTip() {
    createSnackBar(
      StringConstants.SWIPE_TO_DELETE,
      context,
      color: ColorConstants.walterWhite,
    );
  }
}
