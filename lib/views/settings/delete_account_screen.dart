import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/account/account_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'package:medito/widgets/buttons/loading_button_widget.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/widgets/inputs/medito_text_field.dart';
import 'package:medito/widgets/snackbar_widget.dart';

/// Settings > Delete account: confirmation dialog, then the reason picker.
Future<void> startDeleteAccountFlow(BuildContext context) async {
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (_) => const DeleteAccountConfirmationDialog(),
      ) ??
      false;
  if (!confirmed || !context.mounted) return;

  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()));
}

class DeleteAccountConfirmationDialog extends StatelessWidget {
  const DeleteAccountConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return MeditoDialog(
      title: l10n.deleteAccountTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MeditoDialogBody(l10n.deleteAccountConfirmation),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacityValue(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MeditoDialogBody(l10n.deleteAccountDonationNotice),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      launchURLInBrowser(ConfigConstants.donationPortalUrl),
                  child: Text(
                    l10n.deleteAccountManageDonations,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        MeditoDialogSecondaryButton(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        MeditoDialogDestructiveButton(
          label: l10n.continueText,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _detailsController = TextEditingController();
  DeleteAccountReason? _reason;
  bool _isDeleting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _reasonLabel(AppLocalizations l10n, DeleteAccountReason reason) =>
      switch (reason) {
        DeleteAccountReason.notUsing => l10n.deleteAccountReasonNotUsing,
        DeleteAccountReason.privacy => l10n.deleteAccountReasonPrivacy,
        DeleteAccountReason.switchingApp =>
          l10n.deleteAccountReasonSwitchingApp,
        DeleteAccountReason.technicalIssues =>
          l10n.deleteAccountReasonTechnicalIssues,
        DeleteAccountReason.tooManyNotifications =>
          l10n.deleteAccountReasonTooManyNotifications,
        DeleteAccountReason.other => l10n.deleteAccountReasonOther,
      };

  void _selectReason(DeleteAccountReason? reason) {
    if (!_isDeleting) setState(() => _reason = reason);
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    // Captured up front: once the account is gone the confirmation screen
    // must be shown even if this screen was somehow popped meanwhile.
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isDeleting = true);
    try {
      await ref
          .read(accountServiceProvider)
          .deleteAccount(reason: _reason, details: _detailsController.text);
    } catch (e, stackTrace) {
      AppLogger.e('ACCOUNT', 'Account deletion failed', e, stackTrace);
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showSnackBar(
        context,
        e is AccountDeletionUnconfirmed
            ? l10n.deleteAccountUnconfirmed
            : l10n.deleteAccountFailed,
        backgroundColor: Colors.red,
      );
      return;
    }

    await navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AccountDeletedScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // System back (Android back, iOS edge swipe) is blocked while the
    // request is in flight, like the bottom-bar back button.
    return PopScope(
      canPop: !_isDeleting,
      child: Scaffold(
        bottomNavigationBar: SingleBackButtonActionBar(
          onBackPressed: () {
            if (!_isDeleting) Navigator.pop(context);
          },
        ),
        body: AdaptivePageBody(
          maxWidth: 760,
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  toolbarHeight: 56.0,
                  pinned: true,
                  elevation: 0.0,
                  title: HomeHeaderWidget(greeting: l10n.deleteAccountTitle),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(padding16),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        l10n.deleteAccountReasonTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.deleteAccountReasonSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onSurface.withOpacityValue(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RadioGroup<DeleteAccountReason>(
                        groupValue: _reason,
                        onChanged: _selectReason,
                        child: HomeGradientBorder(
                          backgroundColor: theme.cardColor,
                          borderRadius: 14,
                          borderWidth: 0.5,
                          child: Material(
                            type: MaterialType.transparency,
                            child: Column(
                              children: [
                                for (final reason in DeleteAccountReason.values)
                                  InkWell(
                                    onTap: () => _selectReason(reason),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Radio<DeleteAccountReason>(
                                            value: reason,
                                            activeColor: onSurface,
                                          ),
                                          Expanded(
                                            child: Text(
                                              _reasonLabel(l10n, reason),
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(color: onSurface),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MeditoTextField(
                        controller: _detailsController,
                        enabled: !_isDeleting,
                        hintText: l10n.deleteAccountDetailsHint,
                        maxLength: 1000,
                        maxLines: 5,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: LoadingButtonWidget(
                          btnText: l10n.deleteAccountFinalButton,
                          bgColor: theme.colorScheme.error,
                          textColor: theme.colorScheme.onError,
                          borderRadius: 12,
                          isLoading: _isDeleting,
                          onPressed: _delete,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Final confirmation after a successful deletion (required by Apple). The
/// account is already gone and local data wiped; Done restarts from splash,
/// which signs the device in as a fresh anonymous user.
class AccountDeletedScreen extends ConsumerWidget {
  const AccountDeletedScreen({super.key});

  void _done(BuildContext context, WidgetRef ref) {
    ref.invalidate(authRepositoryProvider);
    ref.invalidate(meProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(favoritesNotifierProvider);
    ref.invalidate(packProvider);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AdaptivePageBody(
          maxWidth: 560,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Icon(Icons.check_circle_outline, size: 56, color: onSurface),
                  const SizedBox(height: 24),
                  Text(
                    l10n.accountDeletedTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.accountDeletedBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onSurface.withOpacityValue(0.75),
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: LoadingButtonWidget(
                      btnText: l10n.continueText,
                      bgColor: context.brandPurple,
                      textColor: context.onBrandPurple,
                      borderRadius: 12,
                      onPressed: () => _done(context, ref),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
