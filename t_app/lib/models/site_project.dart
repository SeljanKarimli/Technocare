class SiteProject {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String content;
  final List<String> images;
  final String url;

  const SiteProject({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.content,
    required this.images,
    required this.url,
  });

  List<String> get allImages {
    final unique = <String>{};
    return <String>[imageUrl, ...images]
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && unique.add(item))
        .toList(growable: false);
  }

  String get primaryImage => allImages.firstOrNull ?? '';

  factory SiteProject.fromJson(Map<String, dynamic> json) {
    final unique = <String>{};
    final images = (json['images'] as List? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty && unique.add(item))
        .toList(growable: false);
    final suppliedPrimary = json['imageUrl']?.toString().trim() ?? '';
    return SiteProject(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: suppliedPrimary.isNotEmpty
          ? suppliedPrimary
          : (images.firstOrNull ?? ''),
      content: json['content']?.toString() ?? '',
      images: images,
      url: json['url']?.toString() ?? '',
    );
  }
}

class ProjectPage {
  final List<SiteProject> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool isStale;
  final DateTime? cachedAt;

  const ProjectPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    this.isStale = false,
    this.cachedAt,
  });

  factory ProjectPage.fromJson(Map<String, dynamic> json) => ProjectPage(
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => SiteProject.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 12,
    total: (json['total'] as num?)?.toInt() ?? 0,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    isStale: json['_isStale'] == true,
    cachedAt: DateTime.tryParse(json['_cachedAt']?.toString() ?? ''),
  );
}
