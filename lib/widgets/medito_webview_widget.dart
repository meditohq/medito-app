import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MeditoWebViewWidget extends StatefulWidget {
  final String url;

  const MeditoWebViewWidget({Key? key, required this.url}) : super(key: key);
  @override
  _MeditoWebViewWidgetState createState() => _MeditoWebViewWidgetState();
}

class _MeditoWebViewWidgetState extends State<MeditoWebViewWidget> {
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
