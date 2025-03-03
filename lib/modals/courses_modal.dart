class Courses {
  final String id;
  final String title;
  final String url;
  final String description;
  final String thumbnail;
  final DateTime publishedDate;
  final String channelName;
  final String toolRelatedTo;
  final int price;
  final int v;

  Courses({
    required this.id,
    required this.title,
    required this.url,
    required this.description,
    required this.thumbnail,
    required this.publishedDate,
    required this.channelName,
    required this.toolRelatedTo,
    required this.price,
    required this.v,
  });

  factory Courses.fromJson(Map<String, dynamic> json) {
    return Courses(
      id: json['_id'],
      title: json['title'],
      url: json['url'],
      description: json['description'],
      thumbnail: json['thumbnail'],
      publishedDate: DateTime.parse(json['publishedDate']),
      channelName: json['channelName'],
      toolRelatedTo: json['toolRelatedTo'],
      price: int.parse(json['price']),
      v: json['__v'],
    );
  }
}
