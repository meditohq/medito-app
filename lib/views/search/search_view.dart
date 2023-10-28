import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/search_appbar_widget.dart';
import 'widgets/search_initial_page_widget.dart';
import 'widgets/search_result_widget.dart';

class SearchView extends ConsumerWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: SearchAppbarWidget(),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          if (searchQuery.query.isEmpty)
            Expanded(
              child: SearchInitialPageWidget(),
            ),
          if (searchQuery.query.isNotEmpty)
            Expanded(
              child: SearchResultWidget(),
            ),
        ],
      ),
    );
  }
}
