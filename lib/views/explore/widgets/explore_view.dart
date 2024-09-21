import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';

import '../../../constants/colors/color_constants.dart';
import '../../../constants/strings/string_constants.dart';
import 'explore_initial_page_widget.dart';

class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({super.key});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorConstants.ebony,
        toolbarHeight: 92.0,
        title: const Column(
          children: [
            HomeHeaderWidget(greeting: StringConstants.explore),
            SizedBox(height: 18.0),
          ],
        ),
        elevation: 0.0,
      ),
      body: const ExploreInitialPageWidget(),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
