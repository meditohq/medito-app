import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    final user = authRepository.currentUser;

    return Scaffold(
      backgroundColor: ColorConstants.onyx,
      appBar: const MeditoAppBarSmall(
        title: StringConstants.userProfileTitle,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${StringConstants.userProfileEmailLabel} ${user?.email}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await authRepository.signOut();
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(StringConstants.signOutSuccessMessage)),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(StringConstants.signOutErrorMessage)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: ColorConstants.onyx,
                backgroundColor: ColorConstants.brightSky,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text(StringConstants.signOutButtonText),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(StringConstants.deleteAccountTitle),
                    content: const Text(StringConstants.deleteAccountConfirmation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(StringConstants.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(StringConstants.delete),
                      ),
                    ],
                  ),
                ) ?? false;

                if (confirmed) {
                  try {
                    final success = await authRepository.markAccountForDeletion();
                    if (success) {
                      await authRepository.signOut();
                      Navigator.of(context).pop(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(StringConstants.accountMarkedForDeletion)),
                      );
                    } else {
                      throw Exception('Failed to mark account for deletion');
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(StringConstants.deleteAccountError)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text(StringConstants.deleteAccountButtonText),
            ),
          ],
        ),
      ),
    );
  }
}
