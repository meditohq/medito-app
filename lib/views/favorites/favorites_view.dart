import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/pack/widgets/pack_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';

enum FavoritesFilter {
  all,
  tracks,
  packs,
}

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView> {
  FavoritesFilter _currentFilter = FavoritesFilter.all;
  final ScrollController _scrollController = ScrollController();

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
          data: (favorites) {
            final filteredFavorites = _filterFavorites(favorites);

            return CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _buildFilterChip(FavoritesFilter.all),
                              _buildFilterChip(FavoritesFilter.tracks),
                              _buildFilterChip(FavoritesFilter.packs),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filteredFavorites.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentFilter == FavoritesFilter.tracks
                                ? StringConstants.noFavoriteTracksYet
                                : _currentFilter == FavoritesFilter.packs
                                    ? StringConstants.noFavoritePacksYet
                                    : StringConstants.noFavoritesYet,
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
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredFavorites[index];
                        return Column(
                          children: [
                            GestureDetector(
                              onTap: () => _onItemTap(item, context),
                              child: PackItemWidget(
                                item: PackItemsModel(
                                  id: item.id,
                                  title: item.title,
                                  subtitle: item.subtitle ?? '',
                                  coverUrl: item.coverUrl,
                                  type: item.type == FavoriteItemType.track
                                      ? TypeConstants.track
                                      : TypeConstants.pack,
                                  path: item.type == FavoriteItemType.track
                                      ? 'tracks/${item.id}'
                                      : 'packs/${item.id}',
                                  isCompleted: false,
                                ),
                              ),
                            ),
                            if (index < filteredFavorites.length - 1)
                              const Divider(
                                color: ColorConstants.charcoal,
                                thickness: 2,
                                height: 2,
                              ),
                          ],
                        );
                      },
                      childCount: filteredFavorites.length,
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
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
          ),
        ),
      ),
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
    switch (_currentFilter) {
      case FavoritesFilter.all:
        return favorites;
      case FavoritesFilter.tracks:
        return favorites
            .where((item) => item.type == FavoriteItemType.track)
            .toList();
      case FavoritesFilter.packs:
        return favorites
            .where((item) => item.type == FavoriteItemType.pack)
            .toList();
    }
  }

  Widget _buildFilterChip(FavoritesFilter filter) {
    final isSelected = _currentFilter == filter;
    final label = switch (filter) {
      FavoritesFilter.all => StringConstants.all,
      FavoritesFilter.tracks => StringConstants.tracks,
      FavoritesFilter.packs => StringConstants.packs,
    };

    return ChoiceChip(
      label: Text(
        label,
        style: const TextStyle(
          color: ColorConstants.white,
        ),
      ),
      selected: isSelected,
      selectedColor: ColorConstants.softGrey,
      iconTheme: const IconThemeData(color: ColorConstants.white),
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentFilter = filter);
        }
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
}
