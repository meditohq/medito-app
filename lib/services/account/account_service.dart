import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart' as http_constants;
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

final dev = const AppLoggerAdapter('ACCOUNT_SERVICE');

class AccountService {
  final AuthRepository _authRepository;

  AccountService({required AuthRepository authRepository})
    : _authRepository = authRepository;

  Future<void> openAccountDeletionPage() async {
    final user = _authRepository.currentUser;
    final email = _authRepository.getUserEmail();

    if (user == null || user.id.isEmpty || email == null || email.isEmpty) {
      dev.log(
        '[ACCOUNT_SERVICE] User ID or Email is missing, cannot open deletion page.',
        level: 800,
      );
      throw Exception('User ID or Email is missing.');
    }

    final baseUrl = http_constants.deleteAccountUrl;
    final url = Uri.parse('$baseUrl?user_id=${user.id}&email=$email');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      dev.log(
        '[ACCOUNT_SERVICE] Opened account deletion page: $url',
        level: 500,
      );
    } else {
      dev.log('[ACCOUNT_SERVICE] Could not launch URL: $url', level: 800);
      throw Exception('Could not launch URL');
    }
  }
}

final accountServiceProvider = Provider<AccountService>((ref) {
  final authRepository = ref.watch(authRepositorySyncProvider);

  return AccountService(authRepository: authRepository);
});
