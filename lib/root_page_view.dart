import 'package:Medito/view_model/page_view/page_view_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'views/player/components/mini_player_widget.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  RootPageView({required this.firstChild});
  @override
  ConsumerState<RootPageView> createState() => _RootPageViewtState();
}

class _RootPageViewtState extends ConsumerState<RootPageView> {
  @override
  void initState() {
    ref.read(pageviewNotifierProvider).getCurrentPagePositionListener();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: ref.read(pageviewNotifierProvider).pageController,
        scrollDirection: Axis.vertical,
        physics: BouncingScrollPhysics(),
        children: [
          Column(
            children: [
              Expanded(child: widget.firstChild),
              MiniPlayerWidget(),
            ],
          ),
          Consumer(builder: (context, ref, child) {
            final provider = ref.watch(pageviewNotifierProvider);
            return FractionallySizedBox(
              heightFactor: provider.secondScreenHeightFactor,
              child: AnimatedCrossFade(
                duration: Duration(milliseconds: 500),
                crossFadeState: (provider.pageController.page ?? 0) >= 0.9
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  color: Colors.green,
                ),
                secondChild: Container(
                  color: Colors.red,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
