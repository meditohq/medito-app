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
                  Navigator.of(context).pop();
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
                disabledForegroundColor: Colors.grey,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text(StringConstants.signOutButtonText),
            ),
          ],
        ),
      ),
    );
  }
}
