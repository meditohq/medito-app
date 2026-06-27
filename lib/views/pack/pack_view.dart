import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/views/pack/widgets/pack_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/pack_view_bottom_bar.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/headers/description_widget.dart';

class PackView extends ConsumerStatefulWidget {
  const PackView({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PackView> createState() => _PackViewState();
}

class _PackViewState extends ConsumerState<PackView>
    with AutomaticKeepAliveClientMixin<PackView> {
  final ScrollController _scrollController = ScrollController();
  final _analytics = FirebaseAnalyticsService();
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _logScreenView();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'PackView',
      parameters: {'packid': widget.id},
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final packAsyncValue = ref.watch(packProvider(packId: widget.id));

    void popContext() => Navigator.pop(context);

    // Create a reusable back button widget
    final backButton = SingleBackButtonActionBar(onBackPressed: popContext);

    return Scaffold(
      bottomNavigationBar: packAsyncValue.when(
        data: (pack) => PackViewBottomBar(
          packId: widget.id,
          packName: pack.title,
          onBackPressed: popContext,
        ),
        loading: () => backButton,
        error: (_, _) => backButton,
      ),
      body: packAsyncValue.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (data) => _buildScaffoldWithData(data, ref),
        error: (err, stack) {
          final error = err is AppError ? err : const UnknownError();
          return MeditoErrorWidget(
            error: error,
            onTap: () => ref.refresh(packDataProvider(packId: widget.id)),
            isLoading: packAsyncValue.isLoading,
          );
        },
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
      onRefresh: () async {
        if (widget.id == 'favorites') {
          // If this is the favorites screen, refresh the favorites list from the server
          await ref.read(favoritesNotifierProvider.notifier).syncWithServer();
        }
        return ref.refresh(packDataProvider(packId: widget.id));
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          MeditoAppBarLarge(
            scrollController: _scrollController,
            title: pack.title,
            hasLeading: false,
            coverUrl: pack.coverUrl ?? '',
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              DescriptionWidget(description: pack.description ?? ''),
              ..._listItems(pack, ref),
              _markAllButton(pack),
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
              : PackItemWidget(
                  item: item,
                  onSetComplete: (complete) => _setComplete(item, complete),
                ),
        ),
        if (!isLast)
          const Divider(
            color: ColorConstants.charcoal,
            thickness: 0.5,
            height: 1,
          ),
      ],
    );
  }

  Future<bool> _setComplete(PackItemsModel item, bool complete) {
    return ref
        .read(packProvider(packId: widget.id).notifier)
        .setIsComplete(trackId: item.id, complete: complete);
  }

  Future<void> _markAll(bool complete) async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await ref
          .read(packProvider(packId: widget.id).notifier)
          .markAll(complete: complete);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Widget _markAllButton(PackModel pack) {
    final trackItems =
        pack.items.where((item) => item.type == TypeConstants.track).toList();
    if (trackItems.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final allComplete = trackItems.every((item) => item.isCompleted == true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _markingAll ? null : () => _markAll(!allComplete),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: context.brandPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: ColorConstants.charcoal),
            ),
          ),
          icon: _markingAll
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.brandPurple,
                  ),
                )
              : Icon(allComplete ? Icons.remove_done : Icons.done_all),
          label: Text(
            allComplete ? l10n.markAllIncomplete : l10n.markAllComplete,
          ),
        ),
      ),
    );
  }

  void _onListItemTap(String id, String type, BuildContext context) {
    handleNavigation(type, [id], context, ref: ref);
  }

  @override
  bool get wantKeepAlive => true;
}
