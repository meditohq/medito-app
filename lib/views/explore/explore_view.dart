import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/explore_appbar_widget.dart';
import 'widgets/explore_initial_page_widget.dart';
import 'widgets/explore_result_widget.dart';

class ExploreView extends ConsumerStatefulWidget {
  ExploreView({super.key});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var exploreQuery = ref.watch(exploreQueryProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: ExploreAppbarWidget(),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: exploreQuery.query.isEmpty
                ? ExploreInitialPageWidget()
                : ExploreResultWidget(),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
