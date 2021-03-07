class TextResponse {

  String get title => data.content.title;
  String get content => data.content.body;

  TextResponse({
    this.data,
  });

  final Data data;

  factory TextResponse.fromJson(Map<String, dynamic> json) => TextResponse(
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

  final Content content;

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        content: Content.fromJson(json['content']),
      );

  Map<String, dynamic> toJson() => {
        'content': content.toJson(),
      };
}

class Content {
  Content({
    this.body,
    this.title,
  });

  final String body;
  final String title;

  factory Content.fromJson(Map<String, dynamic> json) => Content(
        body: json['body'],
        title: json['title'],
      );

  Map<String, dynamic> toJson() => {
        'body': body,
        'title': title,
      };
}
