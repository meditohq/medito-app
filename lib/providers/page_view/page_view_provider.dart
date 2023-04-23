import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pageviewNotifierProvider =
    ChangeNotifierProvider<PageviewProvider>((ref) {
  return PageviewProvider();
});

class PageviewProvider extends ChangeNotifier {
  final pageController = PageController(keepPage: true);
  int currentPage = 0;
  double scrollProportion = 1;

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

  void updateScrollProportion(ScrollNotification scrollNotification) {
    var scrollPosition = scrollNotification.metrics.pixels;
    var maxScrollExtent = scrollNotification.metrics.maxScrollExtent;
    var totalScrollableArea = maxScrollExtent;

    scrollProportion = 1 - (scrollPosition / totalScrollableArea);

    scrollProportion = Curves.easeInOutCubic.transform(scrollProportion);

    notifyListeners();
  }

  void gotoNextPage() {
    pageController.nextPage(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeIn,
    );
  }

  void gotoPreviousPage() {
    pageController.previousPage(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeIn,
    );
  }
}
