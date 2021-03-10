class AnnouncementResponse {
  AnnouncementResponse({
    this.data,
  });

  final Data data;

  factory AnnouncementResponse.fromJson(Map<String, dynamic> json) =>
      AnnouncementResponse(
        data: Data.fromJson(json['data']),
      );

  Map<String, dynamic> toJson() => {
        'data': data.toJson(),
      };
}

class Data {
  Data({
    this.content,
  });

  final AnnouncementContent content;

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        content: AnnouncementContent.fromJson(json['content']),
      );

  Map<String, dynamic> toJson() => {
        'content': content.toJson(),
      };
}

class AnnouncementContent {
  AnnouncementContent({
    this.showIcon,
    this.icon,
    this.colorPrimary,
    this.timestamp,
    this.body,
    this.buttonLabel,
    this.buttonType,
    this.buttonPath,
    this.title,
  });

  final bool showIcon;
  final String icon;
  final String colorPrimary;
  final int timestamp;
  final String body;
  final String buttonLabel;
  final String buttonType;
  final String buttonPath;
  final String title;

  factory AnnouncementContent.fromJson(Map<String, dynamic> json) => AnnouncementContent(
        showIcon: json['show_icon'],
        icon: json['icon'],
        colorPrimary: json['color_primary'],
        timestamp: json['timestamp'],
        body: json['body'],
        buttonLabel: json['button_label'],
        buttonType: json['button_type'],
        buttonPath: json['button_path'],
        title: json['title'],
      );

  Map<String, dynamic> toJson() => {
        'show_icon': showIcon,
        'icon': icon,
        'color_primary': colorPrimary,
        'timestamp': timestamp,
        'body': body,
        'button_label': buttonLabel,
        'button_type': buttonType,
        'button_path': buttonPath,
        'title': title,
      };
}
