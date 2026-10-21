import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeCheckoutWebViewPlatform extends WebViewPlatform {
  late FakeCheckoutWebViewController controller;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = FakeCheckoutWebViewController(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Navigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class _Navigation extends PlatformNavigationDelegate {
  _Navigation(super.params) : super.implementation();
  PageEventCallback? finished;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('fake-checkout-webview'));
}

class FakeCheckoutWebViewController extends PlatformWebViewController {
  FakeCheckoutWebViewController(super.params) : super.implementation();
  Uri? loaded;
  final scripts = <String>[];
  JavaScriptChannelParams? channel;
  _Navigation? _navigation;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate delegate,
  ) async {
    _navigation = delegate as _Navigation;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loaded = params.uri;
    scheduleMicrotask(() => _navigation?.finished?.call(params.uri.toString()));
  }

  @override
  Future<String?> currentUrl() async => loaded?.toString();
  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
  }
}
