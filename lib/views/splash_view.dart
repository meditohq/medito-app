import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/firebase_options.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/root/root_combine_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/network/header_service.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => SplashViewState();
}

class SplashViewState extends ConsumerState<SplashView> {
  var _showAccountButtons = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndInitialize();
  }

  Future<void> _checkAuthAndInitialize() async {
    var auth = ref.read(authRepositoryProvider);

    try {
      await auth.initializeSupabase();

      if (auth.currentUser != null) {
        await _initializeServices();
        if (!mounted) return;

        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RootPageView(
              firstChild: BottomNavigationBarView(),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _showAccountButtons = true;
        });
      }
    } catch (e) {
      dev.log('Failed to initialize Supabase', error: e);
      if (!mounted) return;

      showSnackBar(context, StringConstants.offlineMode);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DownloadsView(),
        ),
      );
    }
  }

  Future<void> _handleAnonymousSignIn() async {
    var auth = ref.read(authRepositoryProvider);

    try {
      await auth.initializeUser();
      await _initializeServices();

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const RootPageView(
            firstChild: BottomNavigationBarView(),
          ),
        ),
      );
    } catch (e) {
      dev.log('Failed to initialize user', error: e);
      if (!mounted) return;

      showSnackBar(context, StringConstants.offlineMode);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DownloadsView(),
        ),
      );
    }
  }

  Future<void> _initializeServices() async {
    HttpApiService().initializeAuth();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await _initializeDioHeaderService();
    ref.read(rootCombineProvider(context));
    _initializeFirebaseMessaging();

    try {
      await StatsManager().initialize();
    } catch (e) {
      dev.log('Stats initialization failed', error: e);
      if (!mounted) return;
      showSnackBar(context, StringConstants.statsInitError);
    }
  }

  Future<void> _initializeDioHeaderService() async {
    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
    HeaderService(deviceInfo).initialise();
  }

  void _initializeFirebaseMessaging() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firebaseMessaging = ref.read(firebaseMessagingProvider);
      firebaseMessaging.initialize(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (didPop) {
          _checkAuthAndInitialize();
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: ColorConstants.ebony,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SvgPicture.asset(
                    AssetConstants.icLogo,
                    width: 160,
                  ),
                ),
              ),
              if (_showAccountButtons) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context)
                              .push(
                            MaterialPageRoute(
                              builder: (context) => const SignUpLogInPage(),
                            ),
                          )
                              .then((value) {
                            if (value == true) {
                              _checkAuthAndInitialize();
                            }
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConstants.lightPurple,
                            foregroundColor: ColorConstants.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                              StringConstants.createAccountLogInButtonText),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _handleAnonymousSignIn,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: ColorConstants.lightPurple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            StringConstants.continueAsGuest,
                            style: TextStyle(color: ColorConstants.lightPurple),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
