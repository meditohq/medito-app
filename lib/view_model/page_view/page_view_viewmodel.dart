import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pageviewNotifierProvider =
    ChangeNotifierProvider<PageviewViewModel>((ref) {
  return PageviewViewModel();
});

class PageviewViewModel extends ChangeNotifier {
  final pageController = PageController(keepPage: true);
  double secondScreenHeightFactor = 1;

  void gotoNextPage() {
    pageController.nextPage(
        duration: Duration(milliseconds: 500), curve: Curves.easeIn);
  }
}
