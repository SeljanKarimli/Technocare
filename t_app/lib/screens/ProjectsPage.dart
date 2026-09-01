import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/site_project.dart';
import '../repositories/projects_repository.dart';
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
  Timer? _debounce;
  int _page = 1;
  int _requestVersion = 0;
  bool _loading = false;
  bool _hasMore = true;
  bool _isStale = false;
  DateTime? _cachedAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) _load();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(refresh: true),
    );
  }

  Future<void> _load({bool refresh = false, bool forceRefresh = false}) async {
    if ((_loading && !refresh) || (!refresh && !_hasMore)) return;
    final requestVersion = refresh ? ++_requestVersion : _requestVersion;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await context.read<ProjectsRepository>().getProjects(
        query: _searchController.text,
        page: _page,
        pageSize: 12,
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        if (refresh) _projects.clear();
        final known = _projects.map((project) => project.id).toSet();
        _projects.addAll(
          response.items.where((project) => known.add(project.id)),
        );
        _hasMore = response.page < response.totalPages;
        _page = response.page + 1;
        _isStale = response.isStale;
        _cachedAt = response.cachedAt;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true, forceRefresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Layihə axtarın',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
            if (_isStale)
              SliverToBoxAdapter(
                child: _OfflineBanner(cachedAt: _cachedAt),
              ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Layihələr',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            if (_error != null && _projects.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.cloud_off_rounded,
                  message: _error!,
                  action: () => _load(refresh: true, forceRefresh: true),
                ),
              )
            else if (!_loading && _projects.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.factory_outlined,
                  message: 'Layihə tapılmadı.',
                ),
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
                    (context, index) =>
                        _ProjectCard(project: _projects[index]),
                    childCount: _projects.length,
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

class _OfflineBanner extends StatelessWidget {
  final DateTime? cachedAt;
  const _OfflineBanner({this.cachedAt});

  @override
  Widget build(BuildContext context) {
    final time = cachedAt?.toLocal();
    final updated = time == null
        ? ''
        : ' Son yenilənmə: ${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}.';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Offline məlumat göstərilir.$updated',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final SiteProject project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${project.name} layihəsinə bax',
    child: Card(
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
              child: project.primaryImage.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFEAF0EB),
                      child: Icon(
                        Icons.factory_outlined,
                        size: 44,
                        color: Color(0xFF2F7623),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: project.primaryImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ColoredBox(
                        color: Color(0xFFEAF0EB),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFEAF0EB),
                        child: Icon(
                          Icons.factory_outlined,
                          size: 44,
                          color: Color(0xFF2F7623),
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
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
          Icon(icon, size: 56, color: const Color(0xFF2F7623)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: action,
              child: const Text('Yenidən cəhd et'),
            ),
          ],
        ],
      ),
    ),
  );
}
