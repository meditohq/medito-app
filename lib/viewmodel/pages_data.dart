import '../utils/utils.dart';

class Data {
  String description;
  String contentText;
  String id;
  int num;
  String template;
  int timeCreated;
  String title;
  String url;
  String illustrationUrl;
  bool hasFiles;

  Data({this.description,
    this.contentText,
    this.id,
    this.num,
    this.template,
    this.timeCreated,
    this.title,
    this.url,
    this.illustrationUrl,
    this.hasFiles});

  Data.fromJson(Map<String, dynamic> json) {
    description = json['description'];
    contentText = json['contentText'];
    id = json['id'];
    num = json['num'];
    template = json['template'];
    timeCreated = json['timeCreated'];
    title = json['title'];
    url = json['url'];
    illustrationUrl = json['illustrationUrl'];
    hasFiles = json['hasFiles'];
  }

  Map<String, dynamic> toJson() => {
  '\"description\"': "\"" + blankIfNull(this.description) + "\"",
  '\"contentText\"': "\"" + blankIfNull(this.contentText) + "\"",
  '\"id\"': "\"" + blankIfNull(this.id) + "\"",
  '\"num\"': this.num,
  '\"template\"': "\"" + blankIfNull(this.template) + "\"",
  '\"timeCreated\"': this.timeCreated,
  '\"title\"': "\"" + blankIfNull(this.title) + "\"",
  '\"url\"': "\"" + blankIfNull(this.url) + "\"",
  '\"illustrationUrl\"': "\"" + blankIfNull(this.illustrationUrl) + "\"",
  '\"hasFiles\"': this.hasFiles
  };

}
