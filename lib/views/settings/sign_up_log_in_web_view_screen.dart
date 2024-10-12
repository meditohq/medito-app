import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/settings/user_profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../providers/device_and_app_info/device_and_app_info_provider.dart';

class SignUpLogInPage extends ConsumerWidget {
  const SignUpLogInPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    final user = authRepository.currentUser;

    if (user?.email != null && user?.email?.isNotEmpty == true) {
      return const UserProfilePage();
    } else {
      return const SignUpLogInForm();
    }
  }
}

class SignUpLogInForm extends ConsumerStatefulWidget {
  const SignUpLogInForm({Key? key}) : super(key: key);

  @override
  ConsumerState<SignUpLogInForm> createState() => SignUpLogInFormState();
}

class SignUpLogInFormState extends ConsumerState<SignUpLogInForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    await _performAuthAction(() => ref
        .read(authRepositoryProvider)
        .signUp(_emailController.text.trim(), _passwordController.text.trim()));
  }

  Future<void> _logIn() async {
    await _performAuthAction(() => ref
        .read(authRepositoryProvider)
        .logIn(_emailController.text.trim(), _passwordController.text.trim()));
  }

  Future<void> _performAuthAction(
      Future<AuthResponse> Function() authAction) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await authAction();
      await _refreshUserInfo();
      ref.invalidate(statsProvider);

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text(StringConstants.signInSuccess)),
      );
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      ref.invalidate(statsProvider);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUserInfo() async {
    ref.invalidate(deviceAppAndUserInfoProvider);
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.black);

    return Scaffold(
      backgroundColor: ColorConstants.onyx,
      appBar: AppBar(
        backgroundColor: ColorConstants.onyx,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Sign Up / Log In', style: textStyle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                fillColor: Colors.white,
                filled: true,
                labelStyle: textStyle,
              ),
              style: textStyle,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                fillColor: Colors.white,
                filled: true,
                labelStyle: textStyle,
              ),
              style: textStyle,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Sign Up'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _logIn,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Log In'),
                ),
              ],
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
