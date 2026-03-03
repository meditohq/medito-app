// Defines the different types of widgets that can be displayed on the home screen
enum HomeWidgetType {
  shortcuts, // For shortcut buttons
  carousel, // For the featured content carousel
  products, // For the shop to support section
  quote, // For the daily quote
  upNext; // For the up next basics pack widget

  // Helper method to convert string to enum value
  static HomeWidgetType fromString(String value) {
    return HomeWidgetType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => HomeWidgetType.shortcuts,
    );
  }

  // Helper method to convert enum to string
  static List<String> toStringList(List<HomeWidgetType> types) {
    return types.map((type) => type.name).toList();
  }
}
