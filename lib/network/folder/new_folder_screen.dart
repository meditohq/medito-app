import 'package:Medito/network/folder/new_folder_response.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/strings/string_constants.dart';
import '../../utils/utils.dart';
import '../../components/header/stack_header_component.dart';
import 'folder_provider.dart';

class NewFolderScreen extends ConsumerWidget {
  const NewFolderScreen({Key? key, required this.id}) : super(key: key);

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var value = ref.watch(folderDataProvider(id: id, skipCache: false));
    return value.when(
        data: (data) => buildScaffoldWithData(data, ref),
        error: (err, stack) => Text(err.toString()),
        loading: () => _buildLoadingWidget());
  }

  Widget _buildLoadingWidget() =>
      const Center(child: CircularProgressIndicator());

  Scaffold buildScaffoldWithData(NewFolderResponse? folder, WidgetRef ref) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          return await ref.refresh(folderDataProvider(id: id, skipCache: true));
        },
        child: ListView(
          children: [
            StackHeaderComponent(
              title: folder?.data?.title,
              description: folder?.data?.description,
            ),
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              itemCount: folder?.data?.items?.length ?? 0,
              shrinkWrap: true,
              itemBuilder: (BuildContext context, int i) {
                var title = folder?.data?.items?[i].item?.title;
                var subtitle = folder?.data?.items?[i].item?.subtitle;

                return GestureDetector(
                  onTap: () => _onListItemTap(folder?.data?.items?[i].item?.id,
                      folder?.data?.items?[i].item?.type, ref.context),
                  child: _buildListTile(title, subtitle, true),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(String? title, String? subtitle, bool showIcon) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) Text(title),
              if (subtitle != null)
                Column(children: [
                  Container(height: 8),
                  Text(subtitle),
                ])
            ],
          ),
          showIcon ? Icon(_getIcon(), color: Colors.white) : Container()
        ],
      ),
    );
  }

  void _onListItemTap(int? id, String? type, BuildContext context) {
    checkConnectivity().then((value) {
      if (value) {
        var location = GoRouter.of(context).location;
        if (type == 'folder') {
          if (location.contains('folder2')) {
            context.go(getPathFromString(
                Folder3Path, [location.split('/')[2], this.id, id.toString()]));
          } else {
            context
                .go(getPathFromString(Folder2Path, [this.id, id.toString()]));
          }
        } else {
          context.go(location + getPathFromString(type, [id.toString()]));
        }
      } else {
        createSnackBar(CHECK_CONNECTION, context);
      }
    });
  }

  IconData _getIcon() {
    return Icons.check_circle_outline_sharp;
    // return Icons.article_outlined;
    // return Icons.arrow_forward_ios_sharp;
  }
}
