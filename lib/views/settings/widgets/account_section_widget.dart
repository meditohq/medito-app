import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/views/settings/delete_account_screen.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/snackbar_widget.dart';

class AccountSectionWidget extends ConsumerWidget {
  const AccountSectionWidget({super.key, this.inCard = false});

  final bool inCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositorySyncProvider);
    final user = authRepository.currentUser;

    if (user != null && user.email != null && user.email!.isNotEmpty) {
      return _buildSignedInUserSection(context, ref, user.email!);
    } else {
      return _buildSignedOutUserSection(context, ref);
    }
  }

  Widget _buildSignedInUserSection(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) {
    final authRepository = ref.watch(authRepositorySyncProvider);

    return Padding(
      padding: inCard
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Text(
              email,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
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
                await ref.read(statsManagerProvider).clearAllStats();
                ref.read(meRefreshProvider)();
                ref.read(statsProvider.notifier).refresh();
                ref.invalidate(packProvider);
                ref.invalidate(authRepositoryProvider);

                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SplashView()),
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
            hasUnderline: !inCard,
            onTap: () => startDeleteAccountFlow(context),
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
          hasUnderline: !inCard,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SignUpLogInPage()),
            );
          },
        ),
      ],
    );
  }
}
