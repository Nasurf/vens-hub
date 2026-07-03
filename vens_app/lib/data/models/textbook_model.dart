class TextBookModel {
  String name;
  String url;

  TextBookModel({required this.name, required this.url});

  factory TextBookModel.fromJson(Map<String, dynamic> json) {
    return TextBookModel(name: json["name"], url: json["url"]);
  }

  TextBookModel copyWith({String? name, String? url}) {
    return TextBookModel(name: name ?? this.name, url: url ?? this.url);
  }
}
