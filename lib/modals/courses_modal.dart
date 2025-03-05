class Courses {
  final String id;
  final String title;
  final String url;
  final String description;
  final String thumbnail;
  final DateTime publishedDate;
  final String channelName;
  final String toolRelatedTo;
  final bool isPaid;
  final String price;
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
    required this.isPaid,
    required this.price,
    required this.v,
  });

  factory Courses.fromJson(Map<String, dynamic> json) {
    // Debug logging for JSON parsing
    print('Parsing JSON for course: ${json['title']}');

    // Handle isPaid properly
    bool isPaidValue = false;
    if (json['isPaid'] != null) {
      // Handle both boolean and string values for isPaid
      if (json['isPaid'] is bool) {
        isPaidValue = json['isPaid'];
      } else if (json['isPaid'] is String) {
        isPaidValue = json['isPaid'].toLowerCase() == 'true';
      }
    }

    // Handle price properly
    String priceValue = "0";
    if (json['price'] != null) {
      if (json['price'] is String) {
        priceValue = json['price'];
      } else if (json['price'] is num) {
        priceValue = json['price'].toString();
      }
    }

    print('Parsed isPaid: $isPaidValue, price: $priceValue');

    return Courses(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      publishedDate: json['publishedDate'] != null
          ? DateTime.parse(json['publishedDate'])
          : DateTime.now(),
      channelName: json['channelName'] ?? '',
      toolRelatedTo: json['toolRelatedTo'] ?? '',
      isPaid: isPaidValue,
      price: priceValue,
      v: json['__v'] ?? 0,
    );
  }
}
