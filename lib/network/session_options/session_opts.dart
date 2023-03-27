import 'package:Medito/utils/utils.dart';

// ignore_for_file: avoid-dynamic
class SessionOptionsResponse {
  SessionData? data;

  SessionOptionsResponse({data});

  SessionOptionsResponse.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? SessionData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['data'] = this.data?.toJson();
    return data;
  }
}

class SessionData {
  int? id;
  String? title;
  String? subtitle;
  String? description;
  bool? backgroundSound;
  String? cover;
  String? get coverUrl => cover?.toAssetUrl();
  String? get backgroundImageUrl => _backgroundImage?.toAssetUrl();
  String? colorPrimary;
  String? colorSecondary;
  String? get attribution => _author?.body ?? '';
  List<AudioFile?>? get files => _audio?.map((e) => e.file).toList()?..removeWhere((element) => element == null);

  String? _backgroundImage;
  List<Audio>? _audio;
  Author? _author;

  SessionData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    subtitle = json['subtitle'];
    description = json['description'];
    backgroundSound = json['background_sound'];
    cover = json['cover'];
    _backgroundImage = json['background_image'];
    colorPrimary = json['color_primary'];
    colorSecondary = json['color_secondary'];
    _author =
    json['author'] != null ? Author.fromJson(json['author']) : null;
    if (json['audio'] != null) {
      _audio = <Audio>[];
      json['audio'].forEach((v) {
        _audio?.add(Audio.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['subtitle'] = subtitle;
    data['description'] = description;
    data['background_sound'] = backgroundSound;
    data['background_image'] = _backgroundImage;
    data['cover'] = cover;
    data['color_primary'] = colorPrimary;
    data['color_secondary'] = colorSecondary;
    if (_author != null) {
      data['author'] = _author?.toJson();
    }
    if (_audio != null) {
      data['audio'] = _audio?.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Author {
  String? body;

  Author.fromJson(Map<String, dynamic> json) {
    body = json['body'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['body'] = body;
    return data;
  }
}

class Audio {
  AudioFile? file;

  Audio({file});

  Audio.fromJson(Map<String, dynamic> json) {
    file = json['file'] != null ? AudioFile.fromJson(json['file']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (file != null) {
      data['file'] = file?.toJson();
    }
    return data;
  }
}

class AudioFile {
  String? id;
  String? voice;
  String? length;

  AudioFile.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    voice = json['voice'];
    length = json['length'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['voice'] = voice;
    data['length'] = length;
    return data;
  }
}
