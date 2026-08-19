import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../navigation.dart';
import 'ProjectDetailPage.dart';

// ---------------------------------------------------------------------------
// Smart image widget: tries proxy → raw URL → placeholder, in order
// ---------------------------------------------------------------------------
class _SmartNetworkImage extends StatefulWidget {
  final String rawUrl;
  const _SmartNetworkImage({required this.rawUrl});

  @override
  State<_SmartNetworkImage> createState() => _SmartNetworkImageState();
}

class _SmartNetworkImageState extends State<_SmartNetworkImage> {
  // 0 = proxy, 1 = raw, 2 = give up
  int _attempt = 0;

  String get _currentUrl {
    final trimmed = widget.rawUrl.trim();
    if (trimmed.isEmpty) return '';
    switch (_attempt) {
      case 0:
        return "https://wsrv.nl/?url=${Uri.encodeComponent(trimmed)}&default=error";
      case 1:
        return trimmed;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _currentUrl;

    // Replace the broken_image icon container (attempt >= 2) with:
if (url.isEmpty || _attempt >= 2) {
  return Image.asset(
    '../assets/images/project_placeholder.jpg',
    width: double.infinity,
    fit: BoxFit.cover,
  );
}

    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade200,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.green.shade600,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() => _attempt++);
  });
  // On final attempt, show asset right away
  if (_attempt >= 1) {
    return Image.asset(
      '../assets/images/project_placeholder.jpg',
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }
  return Container(
    color: Colors.grey.shade200,
    child: Center(
      child: CircularProgressIndicator(
        color: Colors.green.shade300,
        strokeWidth: 2,
      ),
    ),
  );
},
    );
  }
}

// ---------------------------------------------------------------------------
// ProjectsPage
// ---------------------------------------------------------------------------
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  _ProjectsPageState createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<Project> projects = [];
  bool isLoading = true;
  String errorMessage = '';
  int page = 1;
  int pageSize = 10;
  bool hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<Project> _displayedProjects = [];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _displayedProjects = projects.where((project) {
        return _searchController.text.isEmpty ||
            project.name
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            project.description
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
      }).toList();
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (hasMore && !isLoading) {
        _fetchProjects();
      }
    }
  }

  Future<void> _fetchProjects() async {
    if (!hasMore) return;
    try {
      final response = await http.get(
        Uri.parse(
            "http://technocareapi.runasp.net/api/Projects?page=$page&pageSize=$pageSize"),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          if (data.length < pageSize) hasMore = false;

          final existingIds = projects.map((p) => p.id).toSet();
          final newProjects = data
              .map((json) => Project.fromJson(json))
              .where((p) => !existingIds.contains(p.id))
              .toList();

          projects.addAll(newProjects);
          isLoading = false;
          if (newProjects.isNotEmpty) {
            page++;
          } else if (data.isNotEmpty) {
            hasMore = false;
          }
          _applyFilters();
        });
      } else {
        setState(() {
          errorMessage = "Xəta: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Bağlantı xətası: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && projects.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            projects.clear();
            _displayedProjects.clear();
            page = 1;
            hasMore = true;
            isLoading = true;
            errorMessage = '';
          });
          await _fetchProjects();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar — same style as HomePage
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Layihə axtarın...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.grey.shade600),
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Section title — same style as HomePage
                const Text(
                  'Layihələr',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16.0),

                if (errorMessage.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(errorMessage,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  )
                else if (_displayedProjects.isEmpty && !isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Layihə tapılmadı.'),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        _displayedProjects.length + (hasMore ? 1 : 0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      if (index == _displayedProjects.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(
                                color: Colors.green),
                          ),
                        );
                      }
                      return _buildProjectCard(_displayedProjects[index]);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailPage(project: project),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
                // Smart widget: proxy → raw → broken icon
                child: _SmartNetworkImage(rawUrl: project.imageUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}