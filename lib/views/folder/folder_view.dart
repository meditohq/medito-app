import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class FolderView extends ConsumerWidget {
  const FolderView({Key? key, required this.id}) : super(key: key);

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var folders = ref.watch(FoldersProvider(folderId: int.parse(id!)));

    return Scaffold(
      body: folders.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (data) => _buildScaffoldWithData(context, data, ref),
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(
            FoldersProvider(folderId: int.parse(id!)),
          ),
          isLoading: folders.isLoading,
        ),
        loading: () => const FolderShimmerWidget(),
      ),
    );
  }

  RefreshIndicator _buildScaffoldWithData(
    BuildContext context,
    FolderModel folder,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        return await ref.refresh(FoldersProvider(folderId: int.parse(id!)));
      },
      child: CollapsibleHeaderWidget(
        bgImage: folder.coverUrl,
        title: '${folder.title}',
        description: folder.description,
        children: folder.items
            .map(
              (e) => GestureDetector(
                onTap: () =>
                    _onListItemTap(ref, e.id, e.type, e.path, ref.context),
                child: _buildListTile(
                  context,
                  e.title,
                  e.subtitle,
                  e.type,
                  folder.items.last == e,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Container _buildListTile(
    BuildContext context,
    String? title,
    String? subtitle,
    String type,
    bool isLast,
  ) {
    var bodyLarge = Theme.of(context).primaryTextTheme.bodyLarge;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(width: 0.9, color: ColorConstants.softGrey),
              ),
      ),
      constraints: BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotNullAndNotEmpty())
                Text(
                  title!,
                  style: bodyLarge?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: DmSans,
                    height: 2,
                  ),
                ),
              if (subtitle.isNotNullAndNotEmpty())
                Text(
                  subtitle!,
                  style: bodyLarge?.copyWith(
                    fontFamily: DmMono,
                    height: 2,
                    color: ColorConstants.newGrey,
                  ),
                ),
            ],
          ),
          if (type != TypeConstants.MEDITATION) _getIcon(type),
        ],
      ),
    );
  }

  Widget _getIcon(String type) {
    if (type == TypeConstants.FOLDER) {
      return SvgPicture.asset(AssetConstants.icForward);
    } else if (type == TypeConstants.LINK) {
      return SvgPicture.asset(AssetConstants.icLink);
    }

    return SizedBox();
  }

  void _onListItemTap(
    WidgetRef ref,
    String? id,
    String? type,
    String? path,
    BuildContext context,
  ) {
    checkConnectivity().then((value) {
      if (value) {
        var location = GoRouter.of(context).location;
        if (type == TypeConstants.FOLDER) {
          if (location.contains('folder2')) {
            context.push(getPathFromString(
              RouteConstants.folder3Path,
              [location.split('/')[2], this.id, id.toString()],
            ));
          } else {
            context.push(getPathFromString(
              RouteConstants.folder2Path,
              [this.id, id.toString()],
            ));
          }
        } else if (type == TypeConstants.LINK) {
          context.push(
            location + RouteConstants.webviewPath,
            extra: {'url': path!},
          );
        } else {
          context.push(location + getPathFromString(type, [id.toString()]));
          if (type == TypeConstants.MEDITATION) {
            _handleTrackEvent(ref, id ?? '0');
          }
        }
      } else {
        createSnackBar(StringConstants.checkConnection, context);
      }
    });
  }

  void _handleTrackEvent(WidgetRef ref, String meditationId) {
    var meditationViewedModel =
        MeditationViewedModel(meditationId: meditationId);
    var event = EventsModel(
      name: EventTypes.meditationViewed,
      payload: meditationViewedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
