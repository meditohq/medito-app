import 'package:flutter/material.dart';

class WidgetTestUtil {
  // Wrapping the widget with MaterialApp because it needs to know the text direction (LTR or RTL)
  // and ScaffoldMessenger for showing the snackbar.
  // This is only needed when testing individual widget.
  // The app works without it because it is wrapped with MaterialApp at the top level.
  static Widget wrapWidgetForTesting({@required Widget child}) {
    return MaterialApp(
      title: 'TestAppWrapper',
      home: Scaffold(
        appBar: AppBar(
          title: Text('TestAppBar'),
        ),
        body: child,
      ),
    );
  }
}
