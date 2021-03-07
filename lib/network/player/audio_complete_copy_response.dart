class AudioCompleteCopyResponse {
  Data _data;

  List<Version> get list => _data._content._versions;

  AudioCompleteCopyResponse({Data data}) {
    _data = data;
  }

  AudioCompleteCopyResponse.fromJson(Map<String, dynamic> json) {
    _data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (_data != null) {
      data['data'] = _data.toJson();
    }
    return data;
  }
}

class Data {
  Content _content;

  Data({Content content}) {
    _content = content;
  }

  Data.fromJson(Map<String, dynamic> json) {
    _content =
    json['content'] != null ? Content.fromJson(json['content']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (_content != null) {
      data['content'] = _content.toJson();
    }
    return data;
  }
}

class Content {
  List<Version> _versions;
  String _title;

  Content({List<Version> versions, String title}) {
    _versions = versions;
    _title = title;
  }

  Content.fromJson(Map<String, dynamic> json) {
    if (json['versions'] != null) {
      _versions = <Version>[];
      json['versions'].forEach((v) {
        _versions.add(Version.fromJson(v));
      });
    }
    _title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (_versions != null) {
      data['versions'] = _versions.map((v) => v.toJson()).toList();
    }
    data['title'] = _title;
    return data;
  }
}

class Version {
  int version;
  bool active;
  String title;
  String subtitle;
  String buttonIcon;
  String buttonLabel;
  String buttonType;
  String buttonPath;
  String sticky;

  Version(
      {int version,
        bool active,
        String title,
        String subtitle,
        String buttonIcon,
        String buttonLabel,
        String buttonType,
        String buttonPath,
        String sticky}) {
    version = version;
    active = active;
    title = title;
    subtitle = subtitle;
    buttonIcon = buttonIcon;
    buttonLabel = buttonLabel;
    buttonType = buttonType;
    buttonPath = buttonPath;
    sticky = sticky;
  }

  Version.fromJson(Map<String, dynamic> json) {
    version = json['version'];
    active = json['active'];
    title = json['title'];
    subtitle = json['subtitle'];
    buttonIcon = json['button_icon'];
    buttonLabel = json['button_label'];
    buttonType = json['button_type'];
    buttonPath = json['button_path'];
    sticky = json['sticky'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['version'] = version;
    data['active'] = active;
    data['title'] = title;
    data['subtitle'] = subtitle;
    data['button_icon'] = buttonIcon;
    data['button_label'] = buttonLabel;
    data['button_type'] = buttonType;
    data['button_path'] = buttonPath;
    data['sticky'] = sticky;
    return data;
  }
}