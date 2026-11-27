import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:medito/widgets/adaptive/adaptive_content.dart';
import 'package:medito/widgets/adaptive/adaptive_cover_split.dart';
import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
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
import 'package:medito/utils/session_origin.dart';

class PackView extends ConsumerStatefulWidget {
  const PackView({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PackView> createState() => _PackViewState();
}

class _PackViewState extends ConsumerState<PackView>
    with AutomaticKeepAliveClientMixin<PackView> {
  final ScrollController _scrollController = ScrollController();

  /// The track list's own controller in the two-pane layout. Separate from
  /// [_scrollController] so the two layouts never share one controller while
  /// a fold or resize swaps them.
  final ScrollController _wideListController = ScrollController();

  /// Marks where the track list starts in the single-column layout.
  final _listStartKey = GlobalKey();

  /// [_listStartKey]'s top at scroll offset 0, kept from the last time it was
  /// laid out (it is unmounted once scrolled far away).
  double? _listTopAtZero;
  bool? _wide;

  /// How far the track list was scrolled when the layout last swapped, to be
  /// re-applied to the new layout once it is laid out.
  double? _pendingListScroll;
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
    ref.listenManual(
      packProvider(packId: widget.id),
      (_, next) => _recordCompletion(next.value),
      fireImmediately: true,
    );
  }

  // Deferred: providers can't be modified while the widget tree is building.
  // The setter is idempotent, so repeated updates never loop.
  void _recordCompletion(PackModel? pack) {
    // Before stats load every item reads as incomplete, which would wipe a
    // correctly recorded pack.
    if (pack == null || !ref.read(statsProvider).hasValue) return;
    final complete = isPackFullyComplete(pack);
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(locallyCompletedPacksProvider.notifier)
          .setComplete(pack, complete);
    });
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'PackView',
      parameters: {'packid': widget.id},
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _wideListController.dispose();
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
      // Two panes: the cover runs the full height and the bar floats over it.
      extendBody: AdaptiveCoverSplit.isWide(MediaQuery.sizeOf(context).width),
      bottomNavigationBar: packAsyncValue.when(
        data: (pack) => PackViewBottomBar(
          packId: widget.id,
          packName: pack.title,
          onBackPressed: popContext,
        ),
        loading: () => backButton,
        error: (_, _) => backButton,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => _body(
          packAsyncValue,
          wide: AdaptiveCoverSplit.isWide(constraints.maxWidth),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<PackModel> packAsyncValue, {required bool wide}) {
    return AdaptivePageBody(
      maxWidth: wide ? AdaptiveCoverSplit.maxWidth : 960,
      child: packAsyncValue.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (data) {
          _keepListScrollAcrossLayouts(wide);
          if (wide) return _buildWide(data);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => mounted ? _measureListTop() : null,
          );
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
              // Screen readers use the hidden inline copy instead, which
              // reads in place rather than after the whole list.
              if (playable && slotTop != null)
                Positioned(
                  top: math.max(slotTop - offset, _dockedPlayTop),
                  right: PackPathButton.rightInset,
                  child: ExcludeSemantics(child: PackPlayButton(pack: data)),
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
        loading: () => FolderShimmerWidget(wide: wide),
      ),
    );
  }

  /// Full-height cover with a title, description and play card on the left;
  /// the track list scrolls on its own on the right.
  Widget _buildWide(PackModel pack) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AdaptiveCoverSplit.coverWidth(constraints.maxWidth),
            // Built under the Scaffold so its insets include the action bar
            // floating over the cover.
            child: AdaptiveContent(
              child: Builder(builder: (context) => _wideHeader(context, pack)),
            ),
          ),
          Expanded(
            // Rows stop at the status bar and the floating action bar instead
            // of scrolling under them.
            child: SafeArea(
              left: false,
              right: false,
              child: AdaptiveContent(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    controller: _wideListController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      ..._listItems(pack, ref),
                      _markAllButton(pack),
                      height32,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The cover fills the pane (covers are 3:4 portrait and at least as tall
  /// as the pane in pixels, so it needs no softening); title, description and
  /// play button sit on a frosted card at its foot (the announcement card's
  /// glass).
  Widget _wideHeader(BuildContext context, PackModel pack) {
    final playable = PackPathButton.isPlayable(pack);
    final completed = pack.items
        .where((item) => item.isCompleted == true)
        .length;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final description = pack.description ?? '';
    // A short window (a phone on its side) has little cover to show: the play
    // button moves up beside the title so the card covers less of it.
    final compact = MediaQuery.sizeOf(context).height < 600;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(20);
    final card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.72),
            borderRadius: radius,
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(pack.title, style: context.text.title),
                      ),
                    ),
                    if (playable && compact) ...[
                      const SizedBox(width: 12),
                      PackPlayButton(pack: pack),
                    ],
                  ],
                ),
              ),
              if (description.isEmpty)
                height20
              else
                // Not DescriptionWidget: its opaque surface would hide the glass.
                Padding(
                  padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, 20),
                  child: MarkdownWidget(
                    body: description,
                    selectable: true,
                    textAlign: WrapAlignment.start,
                    p: context.text.body,
                    a: context.text.body.copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              _packTags(pack, endReserve: 0),
              if (playable) ...[
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: PackPlayButton(pack: pack),
                    ),
                  ),
                // Same progress edge as the single-column header.
                SizedBox(
                  height: 3,
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: pack.items.isEmpty
                          ? 0
                          : completed / pack.items.length,
                      backgroundColor: onSurface.withValues(alpha: 0.08),
                      color: context.brandAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: ColorConstants.onyx),
        NetworkImageWidget(
          url: pack.coverUrl ?? '',
          shouldCache: true,
          errorWidget: const SizedBox(),
        ),
        const CoverBarFade(),
        Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 20,
              20,
              MediaQuery.paddingOf(context).bottom + 8,
            ),
            child: card,
          ),
        ),
      ],
    );
  }

  Widget _headerContent(PackModel pack) => Column(
    children: [
      DescriptionWidget(
        description: pack.description ?? '',
        endReserve: PackPathButton.endReserve,
      ),
      _packTags(pack),
    ],
  );

  Future<void> _refresh() async {
    if (widget.id == 'favorites') {
      // If this is the favorites screen, refresh the favorites list from the server
      await ref.read(favoritesNotifierProvider.notifier).syncWithServer();
    }
    return ref.refresh(packDataProvider(packId: widget.id));
  }

  /// The single-column list scrolls together with its header; the two-pane
  /// list scrolls alone. When a fold, unfold or resize swaps the layouts,
  /// carry over how far the track list itself was scrolled so the same rows
  /// stay in view.
  void _keepListScrollAcrossLayouts(bool wide) {
    final wasWide = _wide;
    _wide = wide;
    if (wasWide != null && wasWide != wide) {
      final from = wasWide ? _wideListController : _scrollController;
      final offset = from.hasClients ? from.offset : 0.0;
      final listTop = _listTopAtZero;
      _pendingListScroll = wasWide
          ? offset
          : (listTop == null ? 0.0 : offset - (listTop - _pinnedBarBottom));
    }
    if (_pendingListScroll == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final listScroll = _pendingListScroll;
      if (!mounted || listScroll == null) return;
      final to = wide ? _wideListController : _scrollController;
      if (!to.hasClients) return;
      if (!wide) _measureListTop();
      final listTop = _listTopAtZero;
      if (!wide && listTop == null) return;
      _pendingListScroll = null;
      if (listScroll <= 0) return;
      final target = wide
          ? listScroll
          : listScroll + listTop! - _pinnedBarBottom;
      to.jumpTo(target.clamp(0.0, to.position.maxScrollExtent));
    });
  }

  /// Bottom edge of the collapsed app bar: where the visible track list
  /// starts once the single-column header has scrolled away.
  double get _pinnedBarBottom =>
      MediaQuery.paddingOf(context).top + _collapsedAppBarHeight;

  void _measureListTop() {
    final marker = _listStartKey.currentContext?.findRenderObject();
    final body = _bodyKey.currentContext?.findRenderObject();
    if (marker is! RenderBox || body is! RenderBox || !marker.attached) return;
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    _listTopAtZero =
        marker.localToGlobal(Offset.zero, ancestor: body).dy + offset;
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
      onRefresh: _refresh,
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
                child: _headerContent(pack),
              ),
              SizedBox(key: _listStartKey),
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
  Widget _packTags(
    PackModel pack, {
    double endReserve = PackPathButton.endReserve,
  }) {
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
        padding: EdgeInsets.fromLTRB(20, 0, 20 + endReserve, 16),
      ),
    );
  }

  List<Widget> _listItems(PackModel pack, WidgetRef ref) {
    // The row's InkWell handles the tap; an outer GestureDetector here added
    // a second tap target over the same row.
    return pack.items
        .map(
          (packItem) => _buildListTile(packItem, pack.items.last == packItem),
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
    handleNavigation(
      type,
      [id],
      context,
      ref: ref,
      sessionSource: SessionOrigin.packTrackRow,
      sessionPackId: widget.id,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
