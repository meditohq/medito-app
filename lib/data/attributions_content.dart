class Content {
  String sourceUrl;
  String licenseName;
  String licenseUrl;
  bool downloadButton;
  String title;

  Content({this.sourceUrl, this.licenseName, this.licenseUrl, this.title});

  Content.fromJson(Map<String, dynamic> json) {
    sourceUrl = json['source_url'];
    licenseName = json['license_name'];
    licenseUrl = json['license_url'];
    downloadButton = json['download_button'];
    title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['source_url'] = this.sourceUrl;
    data['license_name'] = this.licenseName;
    data['license_url'] = this.licenseUrl;
    data['download_button'] = this.downloadButton;
    data['title'] = this.title;
    return data;
  }
}