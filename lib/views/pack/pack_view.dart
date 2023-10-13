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
  ConsumerState<PackView> createState() => _PackViewState();
}

class _PackViewState extends ConsumerState<PackView>
    with AutomaticKeepAliveClientMixin<PackView> {
  @override
  void initState() {
    _handleTrackEvent(ref, widget.id);
    super.initState();
  }

  void _handleTrackEvent(WidgetRef ref, String packId) {
    var packViewedModel = PackViewedModel(packId: packId);
    var event = EventsModel(
      name: EventTypes.packViewed,
      payload: packViewedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

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
                  e.isCompleted,
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
    bool? isCompletedTrack,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                  Text(
                    title!,
                    style: bodyLarge?.copyWith(
                      color: ColorConstants.walterWhite,
                      fontFamily: DmSans,
                    ),
                  ),
                if (hasSubtitle)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: bodyLarge?.copyWith(
                          fontFamily: DmMono,
                          color: ColorConstants.newGrey,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _getIcon(type, isCompletedTrack: isCompletedTrack),
        ],
      ),
    );
  }

  Widget _getIcon(String type, {bool? isCompletedTrack}) {
    if (type == TypeConstants.LINK) {
      return SvgPicture.asset(AssetConstants.icLink);
    } else if (type == TypeConstants.TRACK &&
        isCompletedTrack != null &&
        isCompletedTrack) {
      return Icon(Icons.check_circle_outline_rounded);
    }

    return SizedBox();
  }

  void _onListItemTap(
    String? id,
    String? type,
    String? path,
    BuildContext context,
  ) {
    checkConnectivity().then((value) {
      if (value) {
        var location = GoRouter.of(context).location;
        if (type == TypeConstants.PACK) {
          if (location.contains('pack2')) {
            unawaited(handleNavigation(
              context: context,
              RouteConstants.pack3Path,
              [location.split('/')[2], widget.id, id.toString()],
            ));
          } else {
            unawaited(handleNavigation(
              context: context,
              RouteConstants.pack2Path,
              [widget.id, id.toString()],
            ));
          }
        } else {
          unawaited(handleNavigation(
            context: context,
            type,
            [id.toString(), path],
            ref: ref,
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
