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
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: ColorConstants.ebony,
            expandedHeight: 164.0,
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
                    const HomeHeaderWidget(greeting: StringConstants.explore),
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
    var exploreItems = ref.watch(exploreListProvider(searchQuery));

    return exploreItems.when(
      data: (data) => _buildContent(context, ref, data),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(exploreListProvider(searchQuery)),
      ),
      loading: () => const ExploreResultShimmerWidget(),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<ExploreListItem> items) {
    var packItems = items.whereType<PackItem>().toList();
    var trackItems = items.whereType<TrackItem>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (packItems.isNotEmpty) _buildPackList(context, ref, packItems),
        if (trackItems.isNotEmpty) _buildExploreList(context, ref, trackItems),
      ],
    );
  }

  Widget _buildPackList(
      BuildContext context, WidgetRef ref, List<PackItem> packItems) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: padding16),
      itemCount: packItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        var item = packItems[index];

        return PackCardWidget(
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
        );
      },
    );
  }

  Widget _buildExploreList(
      BuildContext context, WidgetRef ref, List<ExploreListItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen =
            MediaQuery.of(context).orientation == Orientation.landscape ||
                MediaQuery.of(context).size.shortestSide >= 600;

        return isWideScreen
            ? _buildGridView(context, items, ref, constraints)
            : _buildListView(context, items, ref);
      },
    );
  }

  Widget _buildListView(
      BuildContext context, List<ExploreListItem> items, WidgetRef ref) {
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

  Widget _buildGridView(BuildContext context, List<ExploreListItem> items,
      WidgetRef ref, BoxConstraints constraints) {
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
