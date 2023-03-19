import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pageviewNotifierProvider =
    ChangeNotifierProvider<PageviewViewModel>((ref) {
  return PageviewViewModel();
});

class PageviewViewModel extends ChangeNotifier {
  final pageController = PageController();
  double secondScreenHeightFactor = 1;

  void getCurrentPagePositionListener() {
    pageController.addListener(
      () {
        var currentPagePosition = pageController.page != null
            ? double.parse(pageController.page!.toStringAsFixed(1))
            : 0.0;
        print(pageController.page);
        if (currentPagePosition == 0.0) {
          secondScreenHeightFactor = 0.9;
          // notifyListeners();
        } else if (currentPagePosition == 1.0) {
          secondScreenHeightFactor = 1.2;
          // notifyListeners();
        }
      },
    );
  }
}
