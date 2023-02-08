import 'package:Medito/components/buttons/close_button_component.dart';
import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewComponent extends StatefulWidget {
  final String url;

  const WebViewComponent({Key? key, required this.url}) : super(key: key);
  @override
  _WebViewComponentState createState() => _WebViewComponentState();
}

class _WebViewComponentState extends State<WebViewComponent> {
  int _stackToView = 1;
  void _handleLoad(String value) {
    setState(() {
      _stackToView = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeditoColors.greyIsTheNewGrey,
      appBar: MeditoAppBarWidget(
        hasCloseButton: true,
      ),
      body: IndexedStack(
        index: _stackToView,
        children: [
          WebView(
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (WebViewController webViewController) {
              webViewController.loadUrl(widget.url);
            },
            onPageFinished: _handleLoad,
          ),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
