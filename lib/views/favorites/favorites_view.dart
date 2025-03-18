import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/pack/widgets/pack_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';

enum FavoritesFilter {
  all,
  tracks,
  packs;

  String get label => switch (this) {
        FavoritesFilter.all => StringConstants.all,
        FavoritesFilter.tracks => StringConstants.tracks,
        FavoritesFilter.packs => StringConstants.packs,
      };

  String get emptyStateMessage => switch (this) {
        FavoritesFilter.tracks => StringConstants.noFavoriteTracksYet,
        FavoritesFilter.packs => StringConstants.noFavoritePacksYet,
        FavoritesFilter.all => StringConstants.noFavoritesYet,
      };
}

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => FavoritesViewState();
}

class FavoritesViewState extends ConsumerState<FavoritesView> {
  FavoritesFilter _currentFilter = FavoritesFilter.all;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref
        .read(favoritesNotifierProvider.notifier)
        .loadFavoritesFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(favoritesNotifierProvider);
    final statsState = ref.watch(statsProvider);

    return Scaffold(
      appBar: const MeditoAppBarSmall(
        title: StringConstants.favorites,
        hasBackButton: true,
      ),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: favoritesState.when(
          data: (favorites) => _buildFavoritesContent(favorites, statsState),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState(),
        ),
      ),
    );
  }

  Widget _buildFavoritesContent(
    List<FavoriteItem> favorites,
    AsyncValue<LocalAllStats> statsState,
  ) {
    final filteredFavorites = _filterFavorites(favorites);

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildFilterChips(),
        if (filteredFavorites.isEmpty)
          _buildEmptyState()
        else
          _buildFavoritesList(filteredFavorites, statsState),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            StringConstants.someThingWentWrong,
            style: const TextStyle(color: ColorConstants.white),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _onRefresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                children: FavoritesFilter.values
                    .map((filter) => _buildFilterChip(filter))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentFilter.emptyStateMessage,
              style: const TextStyle(color: ColorConstants.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              StringConstants.addItemsToFavoritesMessage,
              style: TextStyle(
                color: ColorConstants.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(
    List<FavoriteItem> favorites,
    AsyncValue<LocalAllStats> statsState,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = favorites[index];
          return Column(
            children: [
              GestureDetector(
                onTap: () => _onItemTap(item, context),
                child: PackItemWidget(
                  item: _buildPackItemModel(item, statsState),
                ),
              ),
              if (index < favorites.length - 1)
                const Divider(
                  color: ColorConstants.charcoal,
                  thickness: 2,
                  height: 2,
                ),
            ],
          );
        },
        childCount: favorites.length,
      ),
    );
  }

  PackItemsModel _buildPackItemModel(
    FavoriteItem item,
    AsyncValue<LocalAllStats> statsState,
  ) {
    final isTrack = item.type == FavoriteItemType.track;
    final isCompleted = isTrack
        ? statsState.whenOrNull(
              data: (stats) => stats.tracksChecked?.contains(item.id) ?? false,
            ) ??
            false
        : false;

    return PackItemsModel(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle ?? '',
      coverUrl: item.coverUrl,
      type: isTrack ? TypeConstants.track : TypeConstants.pack,
      path: isTrack ? 'tracks/${item.id}' : 'packs/${item.id}',
      isCompleted: isCompleted,
    );
  }

  Widget _buildFilterChip(FavoritesFilter filter) {
    final isSelected = _currentFilter == filter;

    return ChoiceChip(
      label: Text(
        filter.label,
        style: const TextStyle(color: ColorConstants.white),
      ),
      selected: isSelected,
      selectedColor: ColorConstants.softGrey,
      iconTheme: const IconThemeData(color: ColorConstants.white),
      onSelected: (selected) {
        if (selected) setState(() => _currentFilter = filter);
      },
      backgroundColor: ColorConstants.onyx,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ColorConstants.softGrey),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      labelStyle: const TextStyle(color: ColorConstants.white),
    );
  }

  void _onItemTap(FavoriteItem item, BuildContext context) {
    handleNavigation(
      item.type == FavoriteItemType.track
          ? TypeConstants.track
          : TypeConstants.pack,
      [item.id],
      context,
      ref: ref,
    );
  }

  List<FavoriteItem> _filterFavorites(List<FavoriteItem> favorites) {
    return switch (_currentFilter) {
      FavoritesFilter.all => favorites,
      FavoritesFilter.tracks =>
        favorites.where((item) => item.type == FavoriteItemType.track).toList(),
      FavoritesFilter.packs =>
        favorites.where((item) => item.type == FavoriteItemType.pack).toList(),
    };
  }
}
