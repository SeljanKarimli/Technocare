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
