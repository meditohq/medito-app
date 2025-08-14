import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/account/account_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';

class AccountSectionWidget extends ConsumerWidget {
  const AccountSectionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositorySyncProvider);
    final user = authRepository.currentUser;

    if (user != null && user.email != null && user.email!.isNotEmpty) {
      // User is signed in
      return _buildSignedInUserSection(context, ref, user.email!);
    } else {
      // User is not signed in
      return _buildSignedOutUserSection(context, ref);
    }
  }

  Widget _buildSignedInUserSection(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) {
    final authRepository = ref.watch(authRepositorySyncProvider);
    final accountService = ref.watch(accountServiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              email,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: ColorConstants.white),
            ),
          ),
          height16,
          RowItemWidget(
            icon: HugeIcon(
              icon: HugeIcons.solidRoundedLogout01,
              color: ColorConstants.white,
              size: 24,
            ),
            title: AppLocalizations.of(context)!.signOutButtonText,
            titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ColorConstants.white,
                ),
            hasUnderline: true,
            onTap: () async {
              try {
                await authRepository.signOut();
                await StatsManager().clearAllStats();
                ref.read(meRefreshProvider)();
                ref.read(statsProvider.notifier).refresh();
                ref.invalidate(packProvider);
                ref.invalidate(authRepositoryProvider);

                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const SplashView(),
                    ),
                    (route) => false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          AppLocalizations.of(context)!.signOutSuccessMessage),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          AppLocalizations.of(context)!.signOutErrorMessage),
                    ),
                  );
                }
              }
            },
          ),
          height8,
          RowItemWidget(
            icon: HugeIcon(
              icon: HugeIcons.solidRoundedDelete02,
              color: ColorConstants.white,
              size: 24,
            ),
            title: AppLocalizations.of(context)!.deleteAccountButtonText,
            titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ColorConstants.white,
                ),
            hasUnderline: true,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: ColorConstants.ebony,
                      title: Text(
                        AppLocalizations.of(context)!.deleteAccountTitle,
                        style: const TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        AppLocalizations.of(context)!.deleteAccountConfirmation,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            AppLocalizations.of(context)!.cancel,
                            style: const TextStyle(
                                color: ColorConstants.brightSky),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            AppLocalizations.of(context)!.delete,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (confirmed) {
                try {
                  await accountService.openAccountDeletionPage();
                  // Assuming deletion page handles the rest and user might manually sign out or be signed out.
                  // Forcing local sign out for consistency.
                  await authRepository.signOut();
                  await StatsManager().clearAllStats();
                  ref.read(meRefreshProvider)();
                  ref.read(statsProvider.notifier).refresh();
                  ref.invalidate(packProvider);
                  ref.invalidate(authRepositoryProvider);

                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const SplashView(),
                      ),
                      (route) => false,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!
                            .accountDeletionInitiated),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${AppLocalizations.of(context)!.deleteAccountError} ${e.toString()}'),
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignedOutUserSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RowItemWidget(
          icon: HugeIcon(
            icon: HugeIcons.solidRoundedLogin01,
            color: ColorConstants.white,
            size: 24,
          ),
          title: AppLocalizations.of(context)!.signInSignUp,
          titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ColorConstants.white,
              ),
          hasUnderline: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SignUpLogInPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}
