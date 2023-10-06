import 'dart:async';

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

class PackView extends ConsumerStatefulWidget {
  const PackView({Key? key, required this.id}) : super(key: key);

  final String id;

  @override
  ConsumerState<PackView> createState() => _FolderViewState();
}

class _FolderViewState extends ConsumerState<PackView>
    with AutomaticKeepAliveClientMixin<PackView> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var packs = ref.watch(PacksProvider(packId: widget.id));

    return Scaffold(
      body: packs.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (data) => _buildScaffoldWithData(context, data, ref),
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(
            PacksProvider(packId: widget.id),
          ),
          isLoading: packs.isLoading,
        ),
        loading: () => const FolderShimmerWidget(),
      ),
    );
  }

  RefreshIndicator _buildScaffoldWithData(
    BuildContext context,
    PackModel pack,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        return await ref.refresh(PacksProvider(packId: widget.id));
      },
      child: CollapsibleHeaderWidget(
        bgImage: pack.coverUrl,
        title: '${pack.title}',
        description: pack.description,
        selectableTitle: true,
        selectableDescription: true,
        children: pack.items
            .map(
              (e) => GestureDetector(
                onTap: () => _onListItemTap(e.id, e.type, e.path, ref.context),
                child: _buildListTile(
                  context,
                  e.title,
                  e.subtitle,
                  e.type,
                  pack.items.last == e,
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
    var hasSubtitle = subtitle.isNotNullAndNotEmpty();

    return Container(
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(width: 0.9, color: ColorConstants.softGrey),
              ),
      ),
      constraints: BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotNullAndNotEmpty())
                  Padding(
                    padding: EdgeInsets.only(top: hasSubtitle ? 8 : 0),
                    child: Text(
                      title!,
                      style: bodyLarge?.copyWith(
                        color: ColorConstants.walterWhite,
                        fontFamily: DmSans,
                        height: 2,
                      ),
                    ),
                  ),
                if (hasSubtitle)
                  Flexible(
                    child: Text(
                      subtitle!,
                      style: bodyLarge?.copyWith(
                        fontFamily: DmMono,
                        height: 2,
                        color: ColorConstants.newGrey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _getIcon(type),
        ],
      ),
    );
  }

  Widget _getIcon(String type) {
    return type == TypeConstants.LINK
        ? SvgPicture.asset(AssetConstants.icLink)
        : SizedBox();
  }

  void _onListItemTap(
    String? id,
    String? type,
    String? path,
    BuildContext context,
  ) {
    checkConnectivity().then((value) async {
      if (value) {
        var location = GoRouter.of(context).location;
        if (type == TypeConstants.PACK) {
          if (location.contains('pack2')) {
            unawaited(context.push(getPathFromString(
              RouteConstants.pack3Path,
              [location.split('/')[2], widget.id, id.toString()],
            )));
          } else {
            unawaited(context.push(getPathFromString(
              RouteConstants.pack2Path,
              [widget.id, id.toString()],
            )));
          }
        } else if (type == TypeConstants.EMAIL) {
          var deviceAppAndUserInfo =
              await ref.read(deviceAppAndUserInfoProvider.future);
          var _info =
              '${StringConstants.debugInfo}\n$deviceAppAndUserInfo\n${StringConstants.writeBelowThisLine}';

          await launchEmailSubmission(
            path.toString(),
            body: _info,
          );
        } else {
          unawaited(context.push(
            getPathFromString(
              type,
              [id.toString()],
            ),
            extra: {'url': path ?? ''},
          ));
        }
      } else {
        createSnackBar(StringConstants.checkConnection, context);
      }
    });
  }

  @override
  bool get wantKeepAlive => true;
}
