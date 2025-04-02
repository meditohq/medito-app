import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/views/splash_view.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositorySyncProvider);
    final user = authRepository.currentUser;

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () {
          Navigator.pop(context);
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                height64,
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // Sign out using auth repository which will handle the full process
                      await authRepository.signOut();

                      // Clear app stats
                      await StatsManager().clearAllStats();

                      // Refresh affected providers
                      ref.read(meRefreshProvider)();
                      ref.read(statsProvider.notifier).refresh();
                      ref.invalidate(packProvider);
                      ref.invalidate(authRepositoryProvider);

                      // Navigate to splash screen to reinitialize
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const SplashView(),
                          ),
                          (route) => false, // Clear all routes
                        );
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(StringConstants.signOutSuccessMessage),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(StringConstants.signOutErrorMessage),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: ColorConstants.onyx,
                    backgroundColor: ColorConstants.lightPurple,
                    disabledForegroundColor: Colors.white60,
                    disabledBackgroundColor:
                        ColorConstants.lightPurple.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(StringConstants.signOutButtonText),
                ),
                height16,
                ElevatedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: ColorConstants.ebony,
                            title: const Text(
                              StringConstants.deleteAccountTitle,
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              StringConstants.deleteAccountConfirmation,
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text(
                                  StringConstants.cancel,
                                  style: TextStyle(
                                      color: ColorConstants.brightSky),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text(
                                  StringConstants.delete,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ) ??
                        false;

                    if (confirmed) {
                      try {
                        final success =
                            await authRepository.markAccountForDeletion();
                        if (success) {
                          await authRepository.signOut();
                          Navigator.of(context).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  StringConstants.accountMarkedForDeletion),
                            ),
                          );
                        } else {
                          throw Exception(
                              'Failed to mark account for deletion');
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(StringConstants.deleteAccountError),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(StringConstants.deleteAccountButtonText),
                ),
                const SizedBox.square(dimension: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
