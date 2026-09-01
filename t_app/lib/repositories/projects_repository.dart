import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/site_project.dart';

class ProjectsRepository {
  static const _cachePrefix = 'projects.page.v1.';
  final ApiClient _api;

  const ProjectsRepository(this._api);

  Future<ProjectPage> getProjects({
    String query = '',
    int page = 1,
    int pageSize = 12,
    bool forceRefresh = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _cacheKey(query, page, pageSize);
    final payload = preferences.getString(key);
    final cached = _decodeCache(payload);
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.$1) < ApiConfig.contentFreshness) {
      return ProjectPage.fromJson(cached.$2);
    }

    try {
      final data = Map<String, dynamic>.from(
        await _api.get(
              'v1/content/projects',
              query: {
                'q': query.trim(),
                'page': page,
                'pageSize': pageSize,
              },
            )
            as Map,
      );
      final cachedAt = DateTime.now().toUtc();
      await preferences.setString(
        key,
        jsonEncode({'cachedAt': cachedAt.toIso8601String(), 'data': data}),
      );
      return ProjectPage.fromJson({...data, '_cachedAt': cachedAt.toIso8601String()});
    } catch (_) {
      if (cached == null) rethrow;
      return ProjectPage.fromJson({
        ...cached.$2,
        '_isStale': true,
        '_cachedAt': cached.$1.toIso8601String(),
      });
    }
  }

  String _cacheKey(String query, int page, int pageSize) {
    final normalized = query.trim().toLowerCase();
    final encoded = base64Url.encode(utf8.encode(normalized));
    return '$_cachePrefix$encoded.$page.$pageSize';
  }

  (DateTime, Map<String, dynamic>)? _decodeCache(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final wrapper = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      final cachedAt = DateTime.parse(wrapper['cachedAt'].toString());
      final data = Map<String, dynamic>.from(wrapper['data'] as Map);
      return (cachedAt, data);
    } catch (_) {
      return null;
    }
  }
}
