import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/account/account_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/widgets/snackbar_widget.dart';

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
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          height16,
          RowItemWidget(
            icon: MeditoIcon(
              assetName: MeditoIcons.logout,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
            title: AppLocalizations.of(context)!.signOutButtonText,
            titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
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
                  showSnackBar(
                    context,
                    AppLocalizations.of(context)!.signOutSuccessMessage,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(
                    context,
                    AppLocalizations.of(context)!.signOutErrorMessage,
                    backgroundColor: Colors.red,
                  );
                }
              }
            },
          ),
          height8,
          RowItemWidget(
            icon: MeditoIcon(
              assetName: MeditoIcons.xmark,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
            title: AppLocalizations.of(context)!.deleteAccountButtonText,
            titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            hasUnderline: true,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: ColorConstants.ebony,
                      title: Text(
                        AppLocalizations.of(context)!.deleteAccountTitle,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      content: Text(
                        AppLocalizations.of(context)!.deleteAccountConfirmation,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(
                                    ((0.7).clamp(0.0, 1.0) * 255).round())),
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
                    showSnackBar(
                      context,
                      AppLocalizations.of(context)!.accountDeletionInitiated,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showSnackBar(
                      context,
                      '${AppLocalizations.of(context)!.deleteAccountError} ${e.toString()}',
                      backgroundColor: Colors.red,
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
          icon: MeditoIcon(
            assetName: MeditoIcons.profile,
            color: Theme.of(context).colorScheme.onSurface,
            size: 24,
          ),
          title: AppLocalizations.of(context)!.signInSignUp,
          titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
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
