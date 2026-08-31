import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/home_content.dart';
import '../models/shop_models.dart';

class ShopRepository {
  static const _homeCacheKey = 'live_home.payload';
  static const _homeCacheTimeKey = 'live_home.cachedAt';
  static const _recentSearchesKey = 'shop.recentSearches';
  final ApiClient _api;

  ShopRepository(this._api);

  Future<HomeContent> getHome({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final cachedJson = preferences.getString(_homeCacheKey);
    final cachedAt = DateTime.tryParse(preferences.getString(_homeCacheTimeKey) ?? '');
    if (!forceRefresh && cachedJson != null && cachedAt != null && DateTime.now().difference(cachedAt) < ApiConfig.contentFreshness) {
      return HomeContent.fromJson(Map<String, dynamic>.from(jsonDecode(cachedJson) as Map));
    }

    try {
      final data = Map<String, dynamic>.from(await _api.get('v1/content/home') as Map);
      await preferences.setString(_homeCacheKey, jsonEncode(data));
      await preferences.setString(_homeCacheTimeKey, DateTime.now().toIso8601String());
      return HomeContent.fromJson(data);
    } catch (_) {
      if (cachedJson != null) {
        return HomeContent.fromJson(Map<String, dynamic>.from(jsonDecode(cachedJson) as Map));
      }
      rethrow;
    }
  }

  Future<ProductPage> getProducts({
    String query = '',
    int page = 1,
    int pageSize = 20,
    int? categoryId,
    String? brand,
    bool inStock = false,
    double? minPrice,
    double? maxPrice,
    String sort = 'relevance',
    Future<void>? abortTrigger,
  }) async {
    final data = await _api.get('v1/shop/products', query: {
      'q': query.trim(),
      'page': page,
      'pageSize': pageSize,
      if (categoryId != null) 'category': categoryId,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (inStock) 'inStock': true,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      'sort': sort,
    }, abortTrigger: abortTrigger);
    return ProductPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ShopProduct> getProduct(int productId) async {
    final data = await _api.get('v1/shop/products/$productId');
    return ShopProduct.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<ShopTaxonomy>> getCategories() async {
    final data = Map<String, dynamic>.from(await _api.get('v1/shop/categories') as Map);
    return _parseTaxonomyItems(data['items']);
  }

  Future<List<ShopTaxonomy>> getBrands() async {
    final data = Map<String, dynamic>.from(await _api.get('v1/shop/brands') as Map);
    return _parseTaxonomyItems(data['items']);
  }

  Future<ShopCart> getCart() async {
    final data = await _api.get('v1/shop/cart', authenticated: true);
    return ShopCart.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ShopCart> addToCart(int productId, {int quantity = 1}) async {
    final data = await _api.post(
      'v1/shop/cart/items',
      authenticated: true,
      body: {'productId': productId, 'quantity': quantity},
    );
    return ShopCart.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ShopCart> updateCartItem(int productId, int quantity) async {
    final data = await _api.patch(
      'v1/shop/cart/items/$productId',
      authenticated: true,
      body: {'quantity': quantity},
    );
    return ShopCart.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ShopCart> removeCartItem(int productId) async {
    final data = await _api.delete('v1/shop/cart/items/$productId', authenticated: true);
    return ShopCart.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> clearCart() => _api.delete('v1/shop/cart', authenticated: true);

  Future<CheckoutSession> createCheckoutSession() async {
    final data = await _api.post('v1/shop/checkout-session', authenticated: true);
    return CheckoutSession.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<ShopOrder>> getOrders({int page = 1}) async {
    final data = Map<String, dynamic>.from(await _api.get('v1/shop/orders', authenticated: true, query: {'page': page}) as Map);
    return (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ShopOrder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<String>> getRecentSearches() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_recentSearchesKey) ?? const [];
  }

  Future<void> saveRecentSearch(String query) async {
    final value = query.trim();
    if (value.length < 2) return;
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getStringList(_recentSearchesKey) ?? <String>[];
    current.removeWhere((item) => item.toLowerCase() == value.toLowerCase());
    current.insert(0, value);
    await preferences.setStringList(_recentSearchesKey, current.take(8).toList());
  }

  Future<void> clearRecentSearches() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_recentSearchesKey);
  }

  List<ShopTaxonomy> _parseTaxonomyItems(dynamic value) => (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => ShopTaxonomy.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
