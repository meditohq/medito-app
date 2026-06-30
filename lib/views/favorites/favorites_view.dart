import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/pack/widgets/pack_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:medito/utils/utils.dart';

enum FavoritesFilter {
  all,
  tracks,
  packs;

  String label(BuildContext context) => switch (this) {
    FavoritesFilter.all => AppLocalizations.of(context)!.all,
    FavoritesFilter.tracks => AppLocalizations.of(context)!.tracks,
    FavoritesFilter.packs => AppLocalizations.of(context)!.packs,
  };

  String emptyStateMessage(BuildContext context) => switch (this) {
    FavoritesFilter.tracks => AppLocalizations.of(context)!.noFavoriteTracksYet,
    FavoritesFilter.packs => AppLocalizations.of(context)!.noFavoritePacksYet,
    FavoritesFilter.all => AppLocalizations.of(context)!.noFavoritesYet,
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
    await ref.read(favoritesNotifierProvider.notifier).refreshFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(favoritesNotifierProvider);
    final statsState = ref.watch(statsProvider);

    return Scaffold(
      appBar: MeditoAppBarSmall(
        title: AppLocalizations.of(context)!.favorites,
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
            AppLocalizations.of(context)!.someThingWentWrong,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _onRefresh,
            child: Text(
              AppLocalizations.of(context)!.retry,
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
              _currentFilter.emptyStateMessage(context),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.addItemsToFavoritesMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacityValue(0.7),
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
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = favorites[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onItemTap(item, context),
            child: Column(
              children: [
                PackItemWidget(item: _buildPackItemModel(item, statsState)),
                if (index < favorites.length - 1)
                  Divider(
                    color: Theme.of(context).colorScheme.outline,
                    thickness: 0.5,
                    height: 1,
                  ),
              ],
            ),
          ),
        );
      }, childCount: favorites.length),
    );
  }

  PackItemsModel _buildPackItemModel(
    FavoriteItem item,
    AsyncValue<LocalAllStats> statsState,
  ) {
    final isTrack = item.type == FavoriteItemType.track;
    final isCompleted = isTrack
        ? statsState.whenOrNull(
                data: (stats) =>
                    stats.tracksChecked?.contains(item.id) ?? false,
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
        filter.label(context),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (selected) {
        if (selected) setState(() => _currentFilter = filter);
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      iconTheme: IconThemeData(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
