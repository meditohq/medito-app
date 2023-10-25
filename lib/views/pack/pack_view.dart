import 'dart:async';

import 'package:Medito/views/pack/widgets/pack_dismissible_widget.dart';
import 'package:Medito/views/pack/widgets/pack_item_widget.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    var packs = ref.watch(packProvider(packId: widget.id));

    return Scaffold(
      body: packs.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (data) => _buildScaffoldWithData(data, ref),
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(packProvider(packId: widget.id)),
          isLoading: packs.isLoading,
        ),
        loading: () => const FolderShimmerWidget(),
      ),
    );
  }

  RefreshIndicator _buildScaffoldWithData(
    PackModel pack,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(packProvider(packId: widget.id)),
      child: CollapsibleHeaderWidget(
        bgImage: pack.coverUrl,
        title: '${pack.title}',
        description: pack.description,
        selectableTitle: true,
        selectableDescription: true,
        children: [
          for (var e in pack.items)
            GestureDetector(
              onTap: () => _onListItemTap(e.id, e.type, e.path, ref.context),
              child: _buildListTile(
                e,
                pack.items.last == e,
              ),
            ),
          BottomPaddingWidget(),
        ],
      ),
    );
  }

  Widget _buildListTile(
    PackItemsModel item,
    bool isLast,
  ) {
    //ignore: prefer-conditional-expressions
    if (item.type == TypeConstants.TRACK && item.isCompleted == false) {
      return PackDismissibleWidget(
        child: PackItemWidget(isLast: isLast, item: item),
        onUpdateCb: () {
          ref.read(packProvider(packId: widget.id).notifier).markComplete(
                audioFileId: item.path.getIdFromPath(),
                trackId: item.id,
              );
        },
      );
    } else {
      return PackItemWidget(isLast: isLast, item: item);
    }
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
