import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/site_content.dart';

class ContentRepository {
  final ApiClient _api;

  const ContentRepository(this._api);

  Future<SiteContentCollection> getCollection(
    String kind, {
    bool forceRefresh = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final payloadKey = 'content.$kind.payload';
    final timeKey = 'content.$kind.cachedAt';
    final cached = preferences.getString(payloadKey);
    final cachedAt = DateTime.tryParse(preferences.getString(timeKey) ?? '');
    if (!forceRefresh && cached != null && cachedAt != null && DateTime.now().difference(cachedAt) < ApiConfig.contentFreshness) {
      return SiteContentCollection.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
    }
    try {
      final response = Map<String, dynamic>.from(await _api.get('v1/content/$kind') as Map);
      await preferences.setString(payloadKey, jsonEncode(response));
      await preferences.setString(timeKey, DateTime.now().toIso8601String());
      return SiteContentCollection.fromJson(response);
    } catch (_) {
      if (cached != null) {
        return SiteContentCollection.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
      }
      rethrow;
    }
  }
}
