import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_remote_image.dart';
import '../models/site_content.dart';
import '../repositories/content_repository.dart';

class RemoteContentCollection extends StatefulWidget {
  final String kind;
  final String title;
  final String emptyMessage;
  final IconData fallbackIcon;
  final Widget Function(BuildContext context, SiteContentItem item) applyPage;

  const RemoteContentCollection({
    super.key,
    required this.kind,
    required this.title,
    required this.emptyMessage,
    required this.fallbackIcon,
    required this.applyPage,
  });

  @override
  State<RemoteContentCollection> createState() =>
      _RemoteContentCollectionState();
}

class _RemoteContentCollectionState extends State<RemoteContentCollection> {
  late Future<SiteContentCollection> _content;

  @override
  void initState() {
    super.initState();
    _content = context.read<ContentRepository>().getCollection(widget.kind);
  }

  Future<void> _refresh() async {
    final request = context.read<ContentRepository>().getCollection(
      widget.kind,
      forceRefresh: true,
    );
    setState(() => _content = request);
    await request;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SiteContentCollection>(
    future: _content,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return _CollectionMessage(
          icon: Icons.cloud_off_rounded,
          message: 'Məlumatı yükləmək mümkün olmadı.',
          action: _refresh,
        );
      }
      final items = snapshot.data!.items;
      if (items.isEmpty) {
        return _CollectionMessage(
          icon: widget.fallbackIcon,
          message: widget.emptyMessage,
          action: _refresh,
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }
            final item = items[index - 1];
            return _ContentCard(
              item: item,
              fallbackIcon: widget.fallbackIcon,
              onOpen: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _ContentDetailPage(
                    item: item,
                    applyPage: widget.applyPage,
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _ContentCard extends StatelessWidget {
  final SiteContentItem item;
  final IconData fallbackIcon;
  final VoidCallback onOpen;

  const _ContentCard({
    required this.item,
    required this.fallbackIcon,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            height: 142,
            child: item.imageUrl.isEmpty
                ? ColoredBox(
                    color: const Color(0xFFEAF0EB),
                    child: Icon(
                      fallbackIcon,
                      size: 44,
                      color: const Color(0xFF2F7623),
                    ),
                  )
                : AppRemoteImage(
                    source: item.imageUrl,
                    fit: BoxFit.cover,
                    targetWidth: 480,
                    semanticLabel: '${item.title} bölməsinin şəkli',
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ətraflı bax',
                    style: TextStyle(
                      color: Color(0xFF2F7623),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContentDetailPage extends StatelessWidget {
  final SiteContentItem item;
  final Widget Function(BuildContext context, SiteContentItem item) applyPage;

  const _ContentDetailPage({required this.item, required this.applyPage});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(item.title)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl.isNotEmpty)
            AppRemoteImage(
              source: item.imageUrl,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              targetWidth: 1200,
              semanticLabel: '${item.title} bölməsinin əsas şəkli',
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.body.isEmpty ? item.summary : item.body,
                  style: const TextStyle(fontSize: 15, height: 1.55),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => applyPage(context, item),
                      ),
                    ),
                    child: const Text('Müraciət et'),
                  ),
                ),
                if (item.url.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(item.url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Saytda bax'),
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

class _CollectionMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function() action;

  const _CollectionMessage({
    required this.icon,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: action,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .26),
        Icon(icon, size: 58, color: const Color(0xFF2F7623)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: action,
            child: const Text('Yenidən cəhd et'),
          ),
        ),
      ],
    ),
  );
}
