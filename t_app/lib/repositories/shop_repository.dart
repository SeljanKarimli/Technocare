import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/home_content.dart';
import '../models/shop_models.dart';

class ShopRepository {
  static const _homeCacheKey = 'live_home.payload.v2';
  static const _homeCacheTimeKey = 'live_home.cachedAt.v2';
  static const _recentSearchesKey = 'shop.recentSearches';
  static const _guestCartKey = 'shop.guestCart.v1';
  static const _productPageCachePrefix = 'shop.products.v2.';
  static const _productDetailCachePrefix = 'shop.product.v2.';
  final ApiClient _api;
  Future<void> _cartQueue = Future<void>.value();
  bool lastCartRefreshUsedStaleData = false;
  bool _lastProductRequestUsedStaleData = false;

  ShopRepository(this._api);

  Future<HomeContent> getHome({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final cachedJson = preferences.getString(_homeCacheKey);
    final cachedAt = DateTime.tryParse(
      preferences.getString(_homeCacheTimeKey) ?? '',
    );
    if (!forceRefresh &&
        cachedJson != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < ApiConfig.contentFreshness) {
      return HomeContent.fromJson({
        ...Map<String, dynamic>.from(jsonDecode(cachedJson) as Map),
        '_cachedAt': cachedAt.toIso8601String(),
      });
    }

    try {
      final data = Map<String, dynamic>.from(
        await _api.get('v1/content/home') as Map,
      );
      await preferences.setString(_homeCacheKey, jsonEncode(data));
      await preferences.setString(
        _homeCacheTimeKey,
        DateTime.now().toIso8601String(),
      );
      return HomeContent.fromJson(data);
    } catch (_) {
      if (cachedJson != null) {
        return HomeContent.fromJson({
          ...Map<String, dynamic>.from(jsonDecode(cachedJson) as Map),
          '_isStale': true,
          if (cachedAt != null) '_cachedAt': cachedAt.toIso8601String(),
        });
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
    bool forceRefresh = false,
  }) async {
    final parameters = <String, dynamic>{
      'q': query.trim(),
      'page': page,
      'pageSize': pageSize,
      if (categoryId != null) 'category': categoryId,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (inStock) 'inStock': true,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      'sort': sort,
    };
    final preferences = await SharedPreferences.getInstance();
    final key = _cacheKey(_productPageCachePrefix, parameters);
    final cached = _decodeCache(preferences.getString(key));
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.$1) < ApiConfig.contentFreshness) {
      return ProductPage.fromJson({
        ...cached.$2,
        '_cachedAt': cached.$1.toIso8601String(),
      });
    }

    try {
      final data = Map<String, dynamic>.from(
        await _api.get(
              'v1/shop/products',
              query: parameters,
              abortTrigger: abortTrigger,
            )
            as Map,
      );
      final cachedAt = DateTime.now().toUtc();
      await _writeCache(preferences, key, cachedAt, data);
      return ProductPage.fromJson({
        ...data,
        '_cachedAt': cachedAt.toIso8601String(),
      });
    } catch (_) {
      if (cached == null) rethrow;
      return ProductPage.fromJson({
        ...cached.$2,
        '_isStale': true,
        '_cachedAt': cached.$1.toIso8601String(),
      });
    }
  }

  Future<ShopProduct> getProduct(
    int productId, {
    bool forceRefresh = false,
  }) async {
    _lastProductRequestUsedStaleData = false;
    final preferences = await SharedPreferences.getInstance();
    final key = '$_productDetailCachePrefix$productId';
    final cached = _decodeCache(preferences.getString(key));
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.$1) < ApiConfig.contentFreshness) {
      return ShopProduct.fromJson(cached.$2);
    }
    try {
      final data = Map<String, dynamic>.from(
        await _api.get(
              'v1/shop/products/$productId',
              query: {if (forceRefresh) 'fresh': true},
            )
            as Map,
      );
      await _writeCache(preferences, key, DateTime.now().toUtc(), data);
      return ShopProduct.fromJson(data);
    } catch (_) {
      if (cached == null) rethrow;
      _lastProductRequestUsedStaleData = forceRefresh;
      return ShopProduct.fromJson(cached.$2);
    }
  }

  Future<List<ShopSuggestion>> getSuggestions(
    String query, {
    int limit = 5,
    Future<void>? abortTrigger,
  }) async {
    final value = query.trim();
    if (value.length < 2) return const [];
    final data = Map<String, dynamic>.from(
      await _api.get(
            'v1/shop/suggestions',
            query: {'q': value, 'limit': limit.clamp(1, 10)},
            abortTrigger: abortTrigger,
          )
          as Map,
    );
    return (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ShopSuggestion.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<ShopTaxonomy>> getCategories() async {
    final data = Map<String, dynamic>.from(
      await _api.get('v1/shop/categories') as Map,
    );
    return _parseTaxonomyItems(data['items']);
  }

  Future<List<ShopTaxonomy>> getBrands() async {
    final data = Map<String, dynamic>.from(
      await _api.get('v1/shop/brands') as Map,
    );
    return _parseTaxonomyItems(data['items']);
  }

  /// The active cart is deliberately device-local so guests can shop without
  /// creating an account. Product snapshots make the cart available offline;
  /// every load attempts to refresh them from the live WooCommerce catalogue.
  Future<ShopCart> getCart() => _withCartLock(() async {
    final stored = await _readGuestCartItems();
    final refreshed = <ShopCartItem>[];
    lastCartRefreshUsedStaleData = false;
    for (final item in stored) {
      ShopProduct product = item.product;
      try {
        product = await getProduct(item.productId, forceRefresh: true);
        if (_lastProductRequestUsedStaleData) {
          lastCartRefreshUsedStaleData = true;
        }
      } catch (_) {
        // Retain the last known website snapshot while offline.
        lastCartRefreshUsedStaleData = true;
      }
      refreshed.add(_cartItem(product, item.quantity));
    }
    await _writeGuestCartItems(refreshed);
    return _buildCart(refreshed);
  });

  Future<ShopCart> addToCart(
    int productId, {
    int quantity = 1,
    ShopProduct? productSnapshot,
  }) => _withCartLock(() async {
    final items = await _readGuestCartItems();
    final index = items.indexWhere((item) => item.productId == productId);
    ShopProduct product;
    try {
      product = await getProduct(productId);
    } catch (_) {
      if (index >= 0) {
        product = items[index].product;
      } else if (productSnapshot != null) {
        product = productSnapshot;
      } else {
        rethrow;
      }
    }
    if (!product.inStock || !product.purchasable) {
      throw const ApiException(
        409,
        'Bu məhsul hazırda sifariş üçün mövcud deyil.',
      );
    }
    final requested = quantity.clamp(1, 99).toInt();
    final nextQuantity = index < 0
        ? requested
        : (items[index].quantity + requested).clamp(1, 99).toInt();
    final nextItem = _cartItem(product, nextQuantity);
    if (index < 0) {
      items.add(nextItem);
    } else {
      items[index] = nextItem;
    }
    await _writeGuestCartItems(items);
    return _buildCart(items);
  });

  Future<ShopCart> updateCartItem(int productId, int quantity) =>
      _withCartLock(() async {
        final items = await _readGuestCartItems();
        final index = items.indexWhere((item) => item.productId == productId);
        if (index < 0) {
          throw const ApiException(404, 'Məhsul səbətdə tapılmadı.');
        }
        if (quantity <= 0) {
          items.removeAt(index);
        } else {
          items[index] = _cartItem(
            items[index].product,
            quantity.clamp(1, 99).toInt(),
          );
        }
        await _writeGuestCartItems(items);
        return _buildCart(items);
      });

  Future<ShopCart> removeCartItem(int productId) => _withCartLock(() async {
    final items = await _readGuestCartItems();
    items.removeWhere((item) => item.productId == productId);
    await _writeGuestCartItems(items);
    return _buildCart(items);
  });

  Future<void> clearCart() => _withCartLock(() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_guestCartKey);
  });

  Future<List<ShopOrder>> getOrders({int page = 1}) async {
    final data = Map<String, dynamic>.from(
      await _api.get(
            'v1/shop/orders',
            authenticated: true,
            query: {'page': page},
          )
          as Map,
    );
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
    await preferences.setStringList(
      _recentSearchesKey,
      current.take(8).toList(),
    );
  }

  Future<void> clearRecentSearches() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_recentSearchesKey);
  }

  List<ShopTaxonomy> _parseTaxonomyItems(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => ShopTaxonomy.fromJson(Map<String, dynamic>.from(item)))
          .toList();

  String _cacheKey(String prefix, Map<String, dynamic> parameters) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(parameters)));
    return '$prefix$encoded';
  }

  (DateTime, Map<String, dynamic>)? _decodeCache(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final wrapper = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      return (
        DateTime.parse(wrapper['cachedAt'].toString()),
        Map<String, dynamic>.from(wrapper['data'] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    SharedPreferences preferences,
    String key,
    DateTime cachedAt,
    Map<String, dynamic> data,
  ) async {
    await preferences.setString(
      key,
      jsonEncode({'cachedAt': cachedAt.toIso8601String(), 'data': data}),
    );
  }

  Future<T> _withCartLock<T>(Future<T> Function() operation) {
    final result = _cartQueue.then((_) => operation());
    _cartQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<List<ShopCartItem>> _readGuestCartItems() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(_guestCartKey);
    if (payload == null || payload.isEmpty) return <ShopCartItem>[];
    try {
      final decoded = jsonDecode(payload);
      final rawItems = decoded is Map ? decoded['items'] : decoded;
      return (rawItems as List? ?? const [])
          .whereType<Map>()
          .map((item) => ShopCartItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.productId > 0 && item.quantity > 0)
          .toList();
    } on FormatException {
      await preferences.remove(_guestCartKey);
      return <ShopCartItem>[];
    }
  }

  Future<void> _writeGuestCartItems(List<ShopCartItem> items) async {
    final preferences = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await preferences.remove(_guestCartKey);
      return;
    }
    await preferences.setString(
      _guestCartKey,
      jsonEncode({
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      }),
    );
  }

  ShopCartItem _cartItem(ShopProduct product, int quantity) => ShopCartItem(
    productId: product.id,
    quantity: quantity,
    product: product,
    lineTotal: (product.price ?? 0) * quantity,
  );

  ShopCart _buildCart(List<ShopCartItem> items) {
    final normalized = items
        .map((item) => _cartItem(item.product, item.quantity))
        .toList(growable: false);
    final first = normalized.isEmpty ? null : normalized.first.product;
    return ShopCart(
      items: normalized,
      itemCount: normalized.fold(0, (total, item) => total + item.quantity),
      subtotal: normalized.fold(0, (total, item) => total + item.lineTotal),
      currencyCode: first?.currencyCode ?? 'AZN',
      currencySymbol: first?.currencySymbol ?? '₼',
    );
  }
}
