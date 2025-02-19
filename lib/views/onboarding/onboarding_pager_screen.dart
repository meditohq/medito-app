import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/views/onboarding/all_set_screen.dart';
import 'package:medito/views/onboarding/donation_screen.dart';
import 'package:medito/views/onboarding/notifications_screen.dart';
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
    'assets/images/open_awareness.png',
    'assets/images/relationships.png',
    'assets/images/palouse_mindfulness_small.png',
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
      DonationScreen(
        onNext: () {
          _controller.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeIn,
          );
        },
      ),
      const AllSetScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SafeArea(
        child: Column(
          children: [
            Visibility(
              visible: MediaQuery.of(context).size.height > 500 && 
                      MediaQuery.of(context).orientation == Orientation.portrait,
              child: SizedBox(
                height: 300,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    _images[_currentPage],
                    key: ValueKey<String>(_images[_currentPage]),
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 50,
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
