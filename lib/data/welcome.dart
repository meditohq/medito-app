// To parse this JSON data, do
//
//     final welcome = welcomeFromMap(jsonString);

import 'dart:convert';

class Welcome {
  Welcome({
    this.data,
  });

  final Data data;

  factory Welcome.fromMap(Map<String, dynamic> json) => Welcome(
    data: json["data"] == null ? null : Data.fromMap(json["data"]),
  );

  Map<String, dynamic> toMap() => {
    "data": data == null ? null : data.toMap(),
  };
}

class Data {
  Data({
    this.content,
  });

  final WelcomeContent content;

  factory Data.fromMap(Map<String, dynamic> json) => Data(
    content: json["content"] == null ? null : WelcomeContent.fromMap(json["content"]),
  );

  Map<String, dynamic> toMap() => {
    "content": content == null ? null : content.toMap(),
  };
}

class WelcomeContent {
  WelcomeContent({
    this.showIcon,
    this.icon,
    this.primaryColor,
    this.timestamp,
    this.content,
    this.buttonLabel,
    this.buttonDestinationType,
    this.buttonDestinationLink,
    this.title,
  });

  final bool showIcon;
  final String icon;
  final String primaryColor;
  final DateTime timestamp;
  final String content;
  final String buttonLabel;
  final String buttonDestinationType;
  final String buttonDestinationLink;
  final String title;

  factory WelcomeContent.fromMap(Map<String, dynamic> json) => WelcomeContent(
    showIcon: json["show_icon"] == null ? null : json["show_icon"],
    icon: json["icon"] == null ? null : json["icon"],
    primaryColor: json["primary_color"] == null ? null : json["primary_color"],
    timestamp: json["timestamp"] == null ? null : DateTime.parse(json["timestamp"]),
    content: json["content"] == null ? null : json["content"],
    buttonLabel: json["button_label"] == null ? null : json["button_label"],
    buttonDestinationType: json["button_destination_type"] == null ? null : json["button_destination_type"],
    buttonDestinationLink: json["button_destination_link"] == null ? null : json["button_destination_link"],
    title: json["title"] == null ? null : json["title"],
  );

  Map<String, dynamic> toMap() => {
    "show_icon": showIcon == null ? null : showIcon,
    "icon": icon == null ? null : icon,
    "primary_color": primaryColor == null ? null : primaryColor,
    "timestamp": timestamp == null ? null : timestamp.toIso8601String(),
    "content": content == null ? null : content,
    "button_label": buttonLabel == null ? null : buttonLabel,
    "button_destination_type": buttonDestinationType == null ? null : buttonDestinationType,
    "button_destination_link": buttonDestinationLink == null ? null : buttonDestinationLink,
    "title": title == null ? null : title,
  };
}
