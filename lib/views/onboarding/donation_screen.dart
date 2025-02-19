import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/routes/routes.dart';

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  void _handleDonationAction(BuildContext context, bool didDonate) {
    if (didDonate) {
      handleNavigation(
        TypeConstants.url,
        ['https://meditofoundation.org/donate'],
        context,
      );
    }
  }

  void _handleNextAction() {
    onNext?.call();
  }

  @override
  Widget build(BuildContext context) {
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
                        // Content Section
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: screenHeight * 0.5,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                StringConstants.donationTitle,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenHeight < 700 ? 20 : 24,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                StringConstants.donationBody,
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
                                text: StringConstants.donateNow,
                                onPressed: () =>
                                    _handleDonationAction(context, true),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: _handleNextAction,
                                  style: TextButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    StringConstants.noThanks,
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
