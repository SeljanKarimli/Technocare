import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/site_project.dart';
import 'ApplicationFormSPage.dart';

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
            CachedNetworkImage(
              imageUrl: project.primaryImage,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => const SizedBox(
                height: 250,
                child: ColoredBox(
                  color: Color(0xFFEAF0EB),
                  child: Icon(
                    Icons.factory_outlined,
                    size: 64,
                    color: Color(0xFF3E8F2E),
                  ),
                ),
              ),
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
                if (project.allImages.skip(1).isNotEmpty) ...[
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
                      itemCount: project.allImages.skip(1).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: project.allImages.skip(1).elementAt(index),
                          width: 160,
                          height: 120,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox(
                            width: 160,
                            child: ColoredBox(
                              color: Color(0xFFEAF0EB),
                              child: Icon(Icons.image_not_supported_outlined),
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
