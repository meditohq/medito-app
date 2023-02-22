import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/view_model/folder/folder_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class FolderView extends ConsumerWidget {
  const FolderView({Key? key, required this.id}) : super(key: key);

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var folders = ref.watch(FoldersProvider(folderId: 28));
    return Scaffold(
      body: folders.when(
        skipLoadingOnRefresh: false,
        data: (data) => _buildScaffoldWithData(context, data, ref),
        error: (err, stack) => ErrorComponent(
          message: err.toString(),
          onTap: () async => await ref.refresh(FoldersProvider(folderId: 28)),
        ),
        loading: () => _buildLoadingWidget(),
      ),
    );
  }

  Widget _buildLoadingWidget() => const FolderShimmerComponent();

  RefreshIndicator _buildScaffoldWithData(
      BuildContext context, FolderModel folder, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        return await ref.refresh(FoldersProvider(folderId: 28));
      },
      child: CollapsibleHeaderComponent(
        bgImage: AssetConstants.dalle,
        title: '${folder.name}',
        description: folder.description,
        children: folder.items
            .map(
              (e) => GestureDetector(
                onTap: () => _onListItemTap(e.id, e.type, e.path, ref.context),
                child: _buildListTile(
                  context,
                  e.name,
                  e.subtitle,
                  e.type,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Container _buildListTile(
      BuildContext context, String? title, String? subtitle, String type) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
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
              if (title != null)
                Text(
                  title,
                  style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                      color: ColorConstants.walterWhite,
                      fontFamily: DmSans,
                      height: 2),
                ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                        fontFamily: DmMono,
                        height: 2,
                        color: ColorConstants.newGrey,
                      ),
                )
            ],
          ),
          if (type != TypeConstants.SESSION) _getIcon(type)
        ],
      ),
    );
  }

  void _onListItemTap(
      int? id, String? type, String? path, BuildContext context) {
    checkConnectivity().then((value) {
      if (value) {
        var location = GoRouter.of(context).location;
        if (type == TypeConstants.FOLDER) {
          if (location.contains('folder2')) {
            context.go(getPathFromString(
                Folder3Path, [location.split('/')[2], this.id, id.toString()]));
          } else {
            context
                .go(getPathFromString(Folder2Path, [this.id, id.toString()]));
          }
        } else if (type == TypeConstants.LINK) {
          context.go(location + webviewPath, extra: {'url': path!});
          // context.go(getPathFromString('url', [path.toString()]));
        } else {
          context.go(location + getPathFromString(type, [id.toString()]));
        }
      } else {
        createSnackBar(StringConstants.CHECK_CONNECTION, context);
      }
    });
  }

  Widget _getIcon(String type) {
    if (type == TypeConstants.FOLDER) {
      return SvgPicture.asset(AssetConstants.icForward);
    } else if (type == TypeConstants.LINK) {
      return SvgPicture.asset(AssetConstants.icLink);
    }
    return SizedBox();
  }
}
