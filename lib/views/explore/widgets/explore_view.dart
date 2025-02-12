import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/providers/explore/track_search_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/widgets/track_card_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ExploreView extends ConsumerStatefulWidget {
  final FocusNode searchFocusNode;

  const ExploreView({super.key, required this.searchFocusNode});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void unfocusSearch() {
    widget.searchFocusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = value;
        if (_searchQuery.isEmpty) ref.invalidate(explorePacksProvider);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(explorePacksProvider);
    });
  }

  Future<void> _refreshExploreList() async {
    if (_searchQuery.isEmpty) {
      ref.invalidate(explorePacksProvider);
    } else {
      ref.invalidate(searchTracksProvider(_searchQuery));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          edgeOffset: 150,
          onRefresh: _refreshExploreList,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: ColorConstants.ebony,
                expandedHeight: 134.0,
                collapsedHeight: 0,
                toolbarHeight: 0,
                floating: true,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: padding16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HomeHeaderWidget(
                            greeting: StringConstants.explore),
                        const SizedBox(height: 18.0),
                        SearchBox(
                          controller: _searchController,
                          focusNode: widget.searchFocusNode,
                          onChanged: _onSearchChanged,
                          onClear: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 18.0),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ExploreContentWidget(
                  searchQuery: _searchQuery,
                  onPackTapped: unfocusSearch,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExploreContentWidget extends ConsumerWidget {
  final String searchQuery;
  final VoidCallback onPackTapped;

  const ExploreContentWidget({
    super.key,
    required this.searchQuery,
    required this.onPackTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (searchQuery.isEmpty) {
      final explorePacks = ref.watch(explorePacksProvider);
      return explorePacks.when(
        data: (packs) => packs.isEmpty
            ? const Center(child: Text('No packs available'))
            : _buildPackList(context, ref, packs),
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          isScaffold: false,
          onTap: () => ref.invalidate(explorePacksProvider),
        ),
        loading: () => const LoadingWidget(),
      );
    } else {
      final searchResults = ref.watch(searchTracksProvider(searchQuery));
      return searchResults.when(
        data: (tracks) => _buildTrackList(context, ref, tracks),
        error: (err, stack) => Container(),
        loading: () => const LoadingWidget(),
      );
    }
  }

  Widget _buildTrackList(
      BuildContext context, WidgetRef ref, List<TrackItem> tracks) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = MediaQuery.of(context).size.shortestSide >= 600;
        return isWideScreen
            ? _buildGridView(ref, context, tracks, constraints)
            : _buildListView(ref, context, tracks);
      },
    );
  }

  Widget _buildPackList(
      BuildContext context, WidgetRef ref, List<PackItem> packItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        var itemWidth =
            (constraints.maxWidth - (crossAxisCount + 1) * padding16) /
                crossAxisCount;

        return MasonryGridView.count(
          padding: const EdgeInsets.only(
            left: padding16,
            right: padding16,
            top: padding16,
          ),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: padding16,
          crossAxisSpacing: padding16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: packItems.length,
          itemBuilder: (context, index) {
            var item = packItems[index];

            return SizedBox(
              width: itemWidth,
              child: PackCardWidget(
                title: item.title,
                subTitle: item.subtitle,
                coverUrlPath: item.coverUrl,
                onTap: () {
                  onPackTapped();
                  handleNavigation(
                    TypeConstants.pack,
                    [item.id, item.path],
                    context,
                    ref: ref,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridView(WidgetRef ref, BuildContext context,
      List<TrackItem> items, BoxConstraints constraints) {
    var itemWidth = (constraints.maxWidth - padding16) / 2;

    return Wrap(
      spacing: 0,
      runSpacing: padding16,
      children: items.map((item) {
        return SizedBox(
          width: itemWidth,
          child: Padding(
            padding: const EdgeInsets.only(left: padding16),
            child: TrackCardWidget(
              title: item.title,
              subTitle: item.subtitle,
              coverUrlPath: item.coverUrl,
              onTap: () {
                onPackTapped();
                handleNavigation(
                  TypeConstants.track,
                  [item.id, item.path],
                  context,
                  ref: ref,
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildListView(
    WidgetRef ref,
    BuildContext context,
    List<TrackItem> items,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(padding16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        var item = items[index];
        return TrackCardWidget(
          title: item.title,
          subTitle: item.subtitle,
          coverUrlPath: item.coverUrl,
          onTap: () {
            onPackTapped();
            handleNavigation(
              TypeConstants.track,
              [item.id, item.path],
              context,
              ref: ref,
            );
          },
        );
      },
    );
  }
}

class SearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final TextEditingController controller;
  final FocusNode focusNode;

  const SearchBox({
    super.key,
    required this.onChanged,
    required this.onClear,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: StringConstants.searchMeditations,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: onClear,
        ),
        filled: true,
        fillColor: ColorConstants.white.withOpacity(0.1),
      ),
      style: const TextStyle(color: ColorConstants.white),
      onChanged: onChanged,
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 100,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(ColorConstants.white),
        ),
      ),
    );
  }
}
