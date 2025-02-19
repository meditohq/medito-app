import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  void _handleNotificationsPermission(
      BuildContext context, WidgetRef ref) async {
    var status = await Permission.notification.request();

    if (status.isGranted) {
      _navigateNext(context);
    }
  }

  void _navigateNext(BuildContext context) {
    onNext?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: screenHeight < 700 ? 16 : 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Image/Content Section
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: screenHeight * 0.5,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                StringConstants.enableNotificationsTitle,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenHeight < 700 ? 20 : 24,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                StringConstants.enableNotificationsBody,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: screenHeight < 700 ? 14 : 16,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        // Buttons Section
                        Padding(
                          padding: EdgeInsets.only(
                              top: screenHeight < 700 ? 24 : 32),
                          child: Column(
                            children: [
                              _buildActionButton(
                                text: StringConstants.enableNotificationsCta,
                                onPressed: () => _handleNotificationsPermission(
                                    context, ref),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => _navigateNext(context),
                                  style: TextButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    StringConstants.skipForNow,
                                    style: const TextStyle(
                                      color: ColorConstants.lightPurple,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, ColorConstants.ebony],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.lightPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}
