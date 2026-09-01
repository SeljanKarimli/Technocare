class HomeContent {
  final int schemaVersion;
  final DateTime? updatedAt;
  final String sourceUrl;
  final List<HomeSection> sections;
  final bool isStale;
  final DateTime? cachedAt;

  const HomeContent({
    required this.schemaVersion,
    required this.updatedAt,
    required this.sourceUrl,
    required this.sections,
    this.isStale = false,
    this.cachedAt,
  });

  factory HomeContent.fromJson(Map<String, dynamic> json) => HomeContent(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        sourceUrl: json['sourceUrl']?.toString() ?? '',
        isStale: json['_isStale'] == true,
        cachedAt: DateTime.tryParse(json['_cachedAt']?.toString() ?? ''),
        sections: (json['sections'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => HomeSection.fromJson(Map<String, dynamic>.from(item)))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
      );
}

class HomeSection {
  final String id;
  final String type;
  final int order;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> images;
  final List<HomeLink> links;
  final List<HomeMetric> metrics;
  final List<Map<String, dynamic>> items;

  const HomeSection({
    required this.id,
    required this.type,
    required this.order,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.images,
    required this.links,
    required this.metrics,
    required this.items,
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) => HomeSection(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        eyebrow: json['eyebrow']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        images: (json['images'] as List? ?? const []).map((item) => item.toString()).where((item) => item.isNotEmpty).toList(),
        links: (json['links'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => HomeLink.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        metrics: (json['metrics'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => HomeMetric.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        items: (json['items'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(),
      );
}

class HomeLink {
  final String label;
  final String url;

  const HomeLink(this.label, this.url);
  factory HomeLink.fromJson(Map<String, dynamic> json) => HomeLink(json['label']?.toString() ?? '', json['url']?.toString() ?? '');
}

class HomeMetric {
  final String value;
  final String label;

  const HomeMetric(this.value, this.label);
  factory HomeMetric.fromJson(Map<String, dynamic> json) => HomeMetric(json['value']?.toString() ?? '', json['label']?.toString() ?? '');
}
