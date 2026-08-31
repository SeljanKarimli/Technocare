class SiteContentCollection {
  final int schemaVersion;
  final DateTime? updatedAt;
  final String sourceUrl;
  final List<SiteContentItem> items;

  const SiteContentCollection({required this.schemaVersion, required this.updatedAt, required this.sourceUrl, required this.items});

  factory SiteContentCollection.fromJson(Map<String, dynamic> json) => SiteContentCollection(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        sourceUrl: json['sourceUrl']?.toString() ?? '',
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => SiteContentItem.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class SiteContentItem {
  final int id;
  final String title;
  final String summary;
  final String body;
  final String imageUrl;
  final List<String> images;
  final String url;

  const SiteContentItem({required this.id, required this.title, required this.summary, required this.body, required this.imageUrl, required this.images, required this.url});

  factory SiteContentItem.fromJson(Map<String, dynamic> json) => SiteContentItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString() ?? '',
        images: (json['images'] as List? ?? const []).map((item) => item.toString()).where((item) => item.isNotEmpty).toList(),
        url: json['url']?.toString() ?? '',
      );
}
