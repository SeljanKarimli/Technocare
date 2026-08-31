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

  factory SiteProject.fromJson(Map<String, dynamic> json) => SiteProject(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        images: (json['images'] as List? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(),
        url: json['url']?.toString() ?? '',
      );
}
