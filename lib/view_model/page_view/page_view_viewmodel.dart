import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pageviewNotifierProvider =
    ChangeNotifierProvider<PageviewViewModel>((ref) {
  return PageviewViewModel();
});

class PageviewViewModel extends ChangeNotifier {
  final pageController = PageController(keepPage: true);
  int currentPage = 0;

  void addListenerToPage() {
    pageController.addListener(
      () {
        var currentPagePosition = pageController.page != null
            ? double.parse(pageController.page!.toStringAsFixed(1))
            : 0.0;
        if (currentPagePosition == 0.0) {
          currentPage = 0;
          notifyListeners();
        } else if (currentPagePosition == 1.0) {
          currentPage = 1;
          notifyListeners();
        }
      },
    );
  }

  void gotoNextPage() {
    pageController.nextPage(
        duration: Duration(milliseconds: 500), curve: Curves.easeIn);
  }
}
