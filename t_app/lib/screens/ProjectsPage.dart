import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/site_project.dart';
import 'ProjectDetailPage.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<SiteProject> _projects = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  List<SiteProject> get _visibleProjects {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _projects;
    return _projects
        .where((project) =>
            project.name.toLowerCase().contains(query) ||
            project.description.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!refresh && !_hasMore)) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _projects.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = Map<String, dynamic>.from(
        await context.read<ApiClient>().get(
          'v1/content/projects',
          query: {'page': _page, 'pageSize': 12},
        ) as Map,
      );
      final items = (response['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => SiteProject.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        final known = _projects.map((project) => project.id).toSet();
        _projects.addAll(items.where((project) => known.add(project.id)));
        final totalPages = (response['totalPages'] as num?)?.toInt() ?? _page;
        _hasMore = _page < totalPages;
        if (items.isNotEmpty) _page++;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Layihələri yükləmək mümkün olmadı.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleProjects;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Layihə axtarın',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Text('Layihələr', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ),
            ),
            if (_error != null && _projects.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.cloud_off_rounded,
                  message: _error!,
                  action: () => _load(refresh: true),
                ),
              )
            else if (!_loading && items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(icon: Icons.factory_outlined, message: 'Layihə tapılmadı.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: .72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ProjectCard(project: items[index]),
                    childCount: items.length,
                  ),
                ),
              ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final SiteProject project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProjectDetailPage(project: project)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox.expand(
                  child: CachedNetworkImage(
                    imageUrl: project.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(
                      color: Color(0xFFEAF0EB),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFEAF0EB),
                      child: Icon(Icons.factory_outlined, size: 44, color: Color(0xFF3E8F2E)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(project.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? action;

  const _MessageState({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: const Color(0xFF3E8F2E)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: action, child: const Text('Yenidən cəhd et')),
              ],
            ],
          ),
        ),
      );
}
