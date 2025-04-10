import 'dart:io';
import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  const RootPageView({super.key, required this.firstChild});

  @override
  ConsumerState<RootPageView> createState() => _RootPageViewState();
}

class _RootPageViewState extends ConsumerState<RootPageView> {
  @override
  void initState() {
    super.initState();

    // Request ATT permission after the UI has rendered for better UX
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestTrackingPermissionForIOS();
    });
  }

  Future<void> _requestTrackingPermissionForIOS() async {
    // Only request on iOS and after a slight delay
    if (Platform.isIOS) {
      // Wait for 2 seconds after the app has loaded for a better user experience
      await Future.delayed(const Duration(seconds: 2));

      final analyticsService = ref.read(analyticsServiceProvider);
      await analyticsService.requestIOSTrackingPermission();
    }
  }

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
              children: [
                widget.firstChild,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
