import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'dart:async';

import '../../../providers/explore/track_search_provider.dart';

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
    var packsProvider = searchQuery.isNotEmpty
        ? searchPacksProvider(searchQuery)
        : fetchAllPacksProvider;

    var packs = ref.watch(packsProvider);

    return packs.when(
      data: (data) => _buildPacksList(context, ref, data),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(packsProvider),
      ),
      loading: () => const ExploreResultShimmerWidget(),
    );
  }

  Widget _buildPacksList(
      BuildContext context, WidgetRef ref, List<PackItemsModel> packs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = MediaQuery.of(context).orientation == Orientation.landscape ||
            MediaQuery.of(context).size.shortestSide >= 600;

        return isWideScreen
            ? _buildGridView(context, packs, ref, constraints)
            : _buildListView(context, packs, ref);
      },
    );
  }

  Widget _buildListView(
      BuildContext context, List<PackItemsModel> packs, WidgetRef ref) {
    return Column(
      children: packs.map((element) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            padding16,
            0,
            padding16,
            padding16,
          ),
          child: PackCardWidget(
            title: element.title,
            subTitle: element.subtitle,
            coverUrlPath: element.coverUrl,
            onTap: () {
              onPackTapped();
              handleNavigation(
                element.type,
                [element.id.toString(), element.path],
                context,
                ref: ref,
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGridView(BuildContext context, List<PackItemsModel> packs,
      WidgetRef ref, BoxConstraints constraints) {
    var itemWidth = (constraints.maxWidth - padding16 * 3) / 2;

    return Wrap(
      runSpacing: padding16,
      children: packs.map((element) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            width16,
            SizedBox(
              width: itemWidth,
              child: PackCardWidget(
                title: element.title,
                subTitle: element.subtitle,
                coverUrlPath: element.coverUrl,
                onTap: () {
                  onPackTapped();
                  handleNavigation(
                    element.type,
                    [element.id.toString(), element.path],
                    context,
                    ref: ref,
                  );
                },
              ),
            ),
          ],
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
        hintText: StringConstants.search,
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
