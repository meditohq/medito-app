// cursor_rule.analyticsstrings.mdc
// Put all analytics event string constants in this file. Add a comment for each event describing the context in which it is used, so that in the future AI and maintainers can accurately translate or update them.

// This file contains all analytics event string constants used for Firebase Analytics and other analytics platforms.
// Add a comment for each event describing the context in which it is used, so future AI and maintainers can accurately translate or update them.

class AnalyticsEventConstants {
  /// Event name for Firebase Analytics when a product is clicked in the shop section
  static const String productClicked = 'product_clicked';

  /// Event name for when the user changes the order of home screen widgets in CustomiseHomeLayoutScreen
  static const String homeWidgetOrderChanged = 'home_widget_order_changed';

  /// Description for the analytics event when the user changes the order of home screen widgets in CustomiseHomeLayoutScreen
  static const String homeWidgetOrderChangedDesc =
      'User changed the order of home screen widgets';
}
