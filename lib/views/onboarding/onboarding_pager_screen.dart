import 'dart:io';

import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/onboarding/all_set_screen.dart';
import 'package:medito/views/onboarding/onboarding_donation_screen.dart';
import 'package:medito/views/onboarding/notifications_screen.dart';
import 'package:medito/views/onboarding/tracking_permission_screen.dart';
import 'package:medito/widgets/onboarding/progress_indicator_widget.dart';

class OnboardingPagerScreen extends StatefulWidget {
  const OnboardingPagerScreen({super.key});

  @override
  State<OnboardingPagerScreen> createState() => OnboardingPagerScreenState();
}

class OnboardingPagerScreenState extends State<OnboardingPagerScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  List<Widget> _pages = [];
  final List<String> _images = [
    AssetConstants.onboardingImage1,
    AssetConstants.onboardingImage2,
    AssetConstants.onboardingImage3,
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      NotificationsScreen(
        onNext: () {
          _controller.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeIn,
          );
        },
      ),
      OnboardingDonationScreen(
        onNext: () {
          _controller.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeIn,
          );
        },
      ),
      if (Platform.isIOS)
        TrackingPermissionScreen(
          onNext: () {
            _controller.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            );
          },
        ),
      AllSetScreen(
        onComplete: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const BottomNavigationBarView(),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Visibility(
              visible: MediaQuery.of(context).size.height > 500 &&
                  MediaQuery.of(context).orientation == Orientation.portrait,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    _images[_currentPage < _images.length
                        ? _currentPage
                        : _images.length - 1],
                    key: ValueKey<String>(_images[_currentPage < _images.length
                        ? _currentPage
                        : _images.length - 1]),
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) => _pages[index],
              ),
            ),
            OnboardingProgressIndicator(
              currentIndex: _currentPage,
              totalSteps: _pages.length,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
