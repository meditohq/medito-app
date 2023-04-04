import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewComponent extends StatefulWidget {
  final String url;

  const WebViewComponent({Key? key, required this.url}) : super(key: key);
  @override
  _WebViewComponentState createState() => _WebViewComponentState();
}

class _WebViewComponentState extends State<WebViewComponent> {
  int _stackToView = 1;
  void _handleLoad(String _) {
    setState(() {
      _stackToView = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    var controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _handleLoad,
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    return Scaffold(
      backgroundColor: ColorConstants.greyIsTheNewGrey,
      appBar: MeditoAppBarWidget(
        hasCloseButton: true,
      ),
      body: IndexedStack(
        index: _stackToView,
        children: [
          WebViewWidget(
            controller: controller,
          ),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
