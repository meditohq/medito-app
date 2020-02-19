
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

  Data(
      {this.description,
        this.contentText,
        this.id,
        this.num,
        this.template,
        this.timeCreated,
        this.title,
        this.url, this.illustrationUrl, this.hasFiles});

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

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['\"description\"'] = "\"this.description.toString()\"";
    data['\"contentText\"'] = "\"this.contentText.toString()\"";
    data['\"id\"'] = "\"this.id.toString()\"";
    data['\"num\"'] = this.num;
    data['\"template\"'] = "\"this.template.toString()\"";
    data['\"timeCreated\"'] = this.timeCreated;
    data['\"title\"'] = "\"this.title.toString()\"";
    data['\"url\"'] = "\"this.url.toString()\"";
    data['\"illustrationUrl\"'] = "\"this.illustrationUrl.toString()\"";
    data['\"hasFiles\"'] = this.hasFiles;
    return data;
  }
}
