import 'package:flutter/material.dart';

import '../core/app_remote_image.dart';
import '../models/site_project.dart';
import 'application_form_s_page.dart';

class ProjectDetailPage extends StatelessWidget {
  final SiteProject project;

  const ProjectDetailPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(project.name)),
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (project.primaryImage.isNotEmpty)
            AppRemoteImage(
              source: project.primaryImage,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              targetWidth: 1200,
              semanticLabel: '${project.name} layihəsinin əsas şəkli',
              placeholderVariant: AppImagePlaceholderVariant.project,
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Qısa məlumat',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.description,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                ],
                if (project.content.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Ətraflı məlumat',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.content,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
                if (project.images.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'Qalereya',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: project.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, index) => Semantics(
                        button: true,
                        label: '${project.name} qalereyası, şəkil ${index + 1}',
                        child: InkWell(
                          key: ValueKey<String>(
                            'project-gallery-thumbnail-$index',
                          ),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _ProjectGalleryPage(
                                projectName: project.name,
                                images: project.images,
                                initialIndex: index,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AppRemoteImage(
                              source: project.images[index],
                              width: 160,
                              height: 120,
                              fit: BoxFit.cover,
                              targetWidth: 480,
                              semanticLabel:
                                  '${project.name} layihəsinin ${index + 1}-ci qalereya şəkli',
                              placeholderVariant:
                                  AppImagePlaceholderVariant.project,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ApplicationFormSPage(),
                      ),
                    ),
                    child: const Text('Siz də müraciət edin'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProjectGalleryPage extends StatefulWidget {
  final String projectName;
  final List<String> images;
  final int initialIndex;

  const _ProjectGalleryPage({
    required this.projectName,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ProjectGalleryPage> createState() => _ProjectGalleryPageState();
}

class _ProjectGalleryPageState extends State<_ProjectGalleryPage> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(widget.projectName),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (_, index) => InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: AppRemoteImage(
                source: widget.images[index],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                targetWidth: 1600,
                semanticLabel:
                    '${widget.projectName} qalereyası, şəkil ${index + 1}',
                placeholderVariant: AppImagePlaceholderVariant.project,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
