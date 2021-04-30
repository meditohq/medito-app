class AnnouncementResponse {
  @Deprecated('Use fields instead')
  Data data;

  String get icon => data.icon;

  String get colorPrimary => data.colorPrimary;

  String get body => data.body;

  String get buttonLabel => data.buttonLabel;

  String get buttonType => data.buttonType;

  String get buttonPath => data.buttonPath;

  String get timestamp => data.timestamp;

  String get id => data.id;

  AnnouncementResponse({data});

  AnnouncementResponse.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (data != null) {
      data['data'] = this.data.toJson();
    }
    return data;
  }
}

class Data {
  String icon;
  String colorPrimary;
  String body;
  String buttonLabel;
  String buttonType;
  String buttonPath;
  String timestamp;
  String id;

  Data(
      {icon,
      colorPrimary,
      body,
      buttonLabel,
      buttonType,
      buttonPath,
      timestamp,
      id});

  Data.fromJson(Map<String, dynamic> json) {
    icon = json['icon'];
    colorPrimary = json['color_primary'];
    body = json['body'];
    buttonLabel = json['button_label'];
    buttonType = json['button_type'];
    buttonPath = json['button_path'];
    timestamp = json['timestamp'];
    id = json['id'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['icon'] = icon;
    data['color_primary'] = colorPrimary;
    data['body'] = body;
    data['button_label'] = buttonLabel;
    data['button_type'] = buttonType;
    data['button_path'] = buttonPath;
    data['timestamp'] = timestamp;
    data['id'] = id;
    return data;
  }
}
