import 'package:flutter/material.dart';
import 'package:medito/providers/auth/auth_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:medito/constants/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/auth/initialize_user_provider.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart'; // Import the constants

class SignUpLogInWebView extends ConsumerStatefulWidget {
  final String url;

  const SignUpLogInWebView({Key? key, required this.url}) : super(key: key);

  @override
  ConsumerState<SignUpLogInWebView> createState() => _SignUpLogInWebViewState();
}

class _SignUpLogInWebViewState extends ConsumerState<SignUpLogInWebView> {
  late final WebViewController _controller;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('Page started loading: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request: ${request.url}');
            if (request.url.contains('success')) {
              print('Successful login detected: ${request.url}');
              _handleSuccessfulLogin(request.url);

              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _handleSuccessfulLogin(String url) async {
    print('Handling successful login: $url');
    final uri = Uri.parse(url);
    final clientId = uri.queryParameters['clientId'];
    final emailAddress = uri.queryParameters['email'];

    if (clientId != null && emailAddress != null) {
      print('Client ID: $clientId, Email: $emailAddress');
      await _saveUserInfo(clientId, emailAddress);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are now signed in'),
          backgroundColor: ColorConstants.amsterdamSpring,
        ),
      );

      Navigator.of(context).pop();
    } else {
      print('Client ID or Email is null');
    }
  }

  Future<void> _saveUserInfo(String userId, String email) async {
    var sharedPref = ref.read(sharedPreferencesProvider);
    var oldUserId = sharedPref.getString(SharedPreferenceConstants.userId);
    await ref
        .read(userInitializationProvider.notifier)
        .saveUserInfo(userId, email);
    await ref
        .read(authProvider.notifier)
        .generateUserToken(oldUserId, email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.amsterdamSpring,
      appBar: AppBar(
        backgroundColor: ColorConstants.amsterdamSpring,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorConstants.walterWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: ColorConstants.onyx,
              ),
            ),
        ],
      ),
    );
  }
}
