import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/pack/widgets/pack_dismissible_widget.dart';
import 'package:medito/views/pack/widgets/pack_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/headers/description_widget.dart';

class PackView extends ConsumerStatefulWidget {
  const PackView({Key? key, required this.id}) : super(key: key);

  final String id;

  @override
  ConsumerState<PackView> createState() => _PackViewState();
}

class _PackViewState extends ConsumerState<PackView>
    with AutomaticKeepAliveClientMixin<PackView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var packs = ref.watch(packProvider(packId: widget.id));

    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(onBackPressed: () {
        Navigator.pop(context);
      }),
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

  void _scrollListener() {
    setState(() => {});
  }

  RefreshIndicator _buildScaffoldWithData(
    PackModel pack,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(packProvider(packId: widget.id)),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          MeditoAppBarLarge(
            scrollController: _scrollController,
            title: pack.title,
            hasLeading: false,
            coverUrl: pack.coverUrl,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              DescriptionWidget(description: pack.description),
              ..._listItems(pack, ref),
              height32,
            ]),
          ),
        ],
      ),
    );
  }

  List<Widget> _listItems(PackModel pack, WidgetRef ref) {
    return pack.items
        .map(
          (packItem) => GestureDetector(
            onTap: () => _onListItemTap(
              packItem.id,
              packItem.type,
              ref.context,
            ),
            child: _buildListTile(
              packItem,
              pack.items.last == packItem,
            ),
          ),
        )
        .toList();
  }

  Widget _buildListTile(
    PackItemsModel item,
    bool isLast,
  ) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            _onListItemTap(item.id, item.type, context);
          },
          splashColor: ColorConstants.charcoal,
          child: item.type == TypeConstants.pack
              ? PackItemWidget(item: item)
              : PackDismissibleWidget(
                  child: PackItemWidget(item: item),
                  onDismissed: () {
                    ref
                        .read(packProvider(packId: widget.id).notifier)
                        .toggleIsComplete(
                          audioFileId: item.path.getIdFromPath(),
                          trackId: item.id,
                          isComplete: item.isCompleted == true,
                        );
                  },
                ),
        ),
        if (!isLast)
          const Divider(
            color: ColorConstants.charcoal,
            thickness: 2,
            height: 2,
          ),
      ],
    );
  }

  void _onListItemTap(String id, String type, BuildContext context) {
    handleNavigation(type, [id], context, ref: ref);
  }

  @override
  bool get wantKeepAlive => true;
}
