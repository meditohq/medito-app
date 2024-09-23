import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/home_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/services/network/assign_dio_headers.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../main.dart';
import '../../providers/device_and_app_info/device_and_app_info_provider.dart';

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
    final uri = Uri.parse(url);
    final clientId = uri.queryParameters['clientId'];
    final emailAddress = uri.queryParameters['email'];

    if (clientId != null && emailAddress != null) {
      await _saveUserInfo(clientId, emailAddress);

      var auth = await ref
          .read(authRepositoryProvider)
          .generateUserToken(emailAddress);
      if (auth.token != null) {
        assignHeaders(auth.token!);

        ref.invalidate(fetchStatsProvider);

        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(StringConstants.signInSuccess),
          ),
        );
      } else {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(StringConstants.signInError),
          ),
        );
      }
    }
    Navigator.of(context).pop();
  }

  void assignHeaders(String token) {
    ref.read(deviceAndAppInfoProvider).whenData(
      (value) {
        AssignDioHeaders(token, value).assign();
      },
    );
  }

  Future<void> _saveUserInfo(String clientId, String email) async {
    var userTokenModel = UserTokenModel(clientId: clientId, email: email);
    var authRepo = ref.read(authRepositoryProvider);
    await authRepo.addUserInSharedPreference(userTokenModel);
    ref.invalidate(deviceAppAndUserInfoProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.onyx,
      appBar: AppBar(
        backgroundColor: ColorConstants.onyx,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorConstants.white),
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
