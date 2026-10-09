import 'dart:math' as math;

import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/views/pack/widgets/pack_item_widget.dart';
import 'package:medito/views/pack/widgets/pack_path_button.dart';
import 'package:medito/views/player/widgets/bottom_actions/pack_view_bottom_bar.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/tags/widgets/tag_chips.dart';
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
  // The inline play button and the Stack it docks into, measured on scroll.
  final _playButtonKey = GlobalKey();
  final _bodyKey = GlobalKey();

  /// Where the inline play button's slot sits at scroll offset 0. The slot's
  /// on-screen top is always this minus the offset (content below the app bar
  /// moves 1:1 with scrolling), so the floating button can be placed from the
  /// current offset without waiting a frame for a measurement.
  double? _playSlotTopAtZero;

  /// SliverAppBar.large's collapsed toolbar height (Material 3).
  static const _collapsedAppBarHeight = 64.0;
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
      body: AdaptivePageBody(
        maxWidth: 960,
        child: packAsyncValue.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (data) {
            final playable = PackPathButton.isPlayable(data);
            if (playable) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => mounted ? _measurePlaySlot() : null,
              );
            }
            final slotTop = _playSlotTopAtZero;
            final offset = _scrollController.hasClients
                ? _scrollController.offset
                : 0.0;
            return Stack(
              key: _bodyKey,
              children: [
                _buildScaffoldWithData(
                  data,
                  ref,
                  floatingPlay: playable && slotTop != null,
                ),
                // One button, drawn above the app bar: it rides with the
                // content, then sticks straddling the collapsed bar's edge
                // (Spotify-style). No swap between copies, so no jump.
                if (playable && slotTop != null)
                  Positioned(
                    top: math.max(slotTop - offset, _dockedPlayTop),
                    right: PackPathButton.rightInset,
                    child: PackPlayButton(pack: data),
                  ),
              ],
            );
          },
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
      ),
    );
  }

  void _scrollListener() {
    setState(() => {});
  }

  /// Re-measures the play slot after layout (description, tags or text scale
  /// can move it); only rebuilds when it actually moved.
  void _measurePlaySlot() {
    final slot = _playButtonKey.currentContext?.findRenderObject();
    final body = _bodyKey.currentContext?.findRenderObject();
    if (slot is! RenderBox || body is! RenderBox || !slot.attached) return;
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final atZero = slot.localToGlobal(Offset.zero, ancestor: body).dy + offset;
    final previous = _playSlotTopAtZero;
    if (previous == null || (previous - atZero).abs() > 0.5) {
      setState(() => _playSlotTopAtZero = atZero);
    }
  }

  double get _dockedPlayTop =>
      MediaQuery.paddingOf(context).top +
      _collapsedAppBarHeight -
      PackPathButton.buttonSize / 2;

  RefreshIndicator _buildScaffoldWithData(
    PackModel pack,
    WidgetRef ref, {
    bool floatingPlay = false,
  }) {
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
              // Description surface with the play button on its lower edge.
              PackPathButton(
                pack: pack,
                buttonKey: _playButtonKey,
                // The floating copy takes over once the slot is measured.
                hideButton: floatingPlay,
                child: Column(
                  children: [
                    DescriptionWidget(
                      description: pack.description ?? '',
                      endReserve: PackPathButton.endReserve,
                    ),
                    _packTags(pack),
                  ],
                ),
              ),
              ..._listItems(pack, ref),
              _markAllButton(pack),
              height32,
            ]),
          ),
        ],
      ),
    );
  }

  /// Tags shared by most of the pack's tracks; nothing when unavailable.
  Widget _packTags(PackModel pack) {
    final trackIds = pack.items
        .where((item) => item.type == TypeConstants.track)
        .map((item) => item.id)
        .toList();
    if (trackIds.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: PackTagChips(
        trackIds: trackIds,
        // Right inset clears the play button on the header's lower edge.
        padding: const EdgeInsets.fromLTRB(
          20,
          0,
          20 + PackPathButton.endReserve,
          16,
        ),
      ),
    );
  }

  List<Widget> _listItems(PackModel pack, WidgetRef ref) {
    return pack.items
        .map(
          (packItem) => GestureDetector(
            onTap: () =>
                _onListItemTap(packItem.id, packItem.type, ref.context),
            child: _buildListTile(packItem, pack.items.last == packItem),
          ),
        )
        .toList();
  }

  Widget _buildListTile(PackItemsModel item, bool isLast) {
    return Column(
      children: [
        // Rows open a session, pack or link; without the role they read as
        // plain text.
        Semantics(
          button: true,
          child: InkWell(
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
    final trackItems = pack.items
        .where((item) => item.type == TypeConstants.track)
        .toList();
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
            foregroundColor: context.brandAccent,
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
                    color: context.brandAccent,
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
