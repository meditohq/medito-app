import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  const RootPageView({super.key, required this.firstChild});

  @override
  ConsumerState<RootPageView> createState() => _RootPageViewState();
}

class _RootPageViewState extends ConsumerState<RootPageView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.black,
      resizeToAvoidBottomInset: false,
      body: NotificationListener<ScrollNotification>(
        child: PageView(
          scrollDirection: Axis.vertical,
          physics: const ClampingScrollPhysics(),
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [widget.firstChild],
            ),
          ],
        ),
      ),
    );
  }
}
