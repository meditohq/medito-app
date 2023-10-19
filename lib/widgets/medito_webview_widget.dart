import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MeditoWebViewWidget extends StatefulWidget {
  final String url;

  const MeditoWebViewWidget({Key? key, required this.url}) : super(key: key);

  @override
  _MeditoWebViewWidgetState createState() => _MeditoWebViewWidgetState();
}

class _MeditoWebViewWidgetState extends State<MeditoWebViewWidget> {
  var controller = WebViewController();
  int _stackToView = 1;

  @override
  void initState() {
    try {
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(ColorConstants.ebony)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: _handleLoad,
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } catch (e) {
      Sentry.captureException(
        {
          'error': e.toString(),
          'url': widget.url.toString(),
        },
        stackTrace: e,
      );
    }
    super.initState();
  }

  void _handleLoad(String _) {
    if (mounted) {
      setState(() {
        _stackToView = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.onyx,
      appBar: MeditoAppBarWidget(
        hasCloseButton: true,
      ),
      body: IndexedStack(
        index: _stackToView,
        children: [
          WebViewWidget(
            controller: controller,
            gestureRecognizers: {}
              ..add(Factory(() => EagerGestureRecognizer())),
          ),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
