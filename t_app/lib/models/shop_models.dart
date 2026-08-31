class ShopProduct {
  final int id;
  final String name;
  final String slug;
  final String sku;
  final String brand;
  final List<ShopTaxonomy> categories;
  final String shortDescription;
  final String description;
  final List<String> images;
  final double? price;
  final double? regularPrice;
  final double? salePrice;
  final String currencyCode;
  final String currencySymbol;
  final bool onSale;
  final bool inStock;
  final bool purchasable;
  final String permalink;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.sku,
    required this.brand,
    required this.categories,
    required this.shortDescription,
    required this.description,
    required this.images,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.currencyCode,
    required this.currencySymbol,
    required this.onSale,
    required this.inStock,
    required this.purchasable,
    required this.permalink,
  });

  String get primaryImage => images.isEmpty ? '' : images.first;
  String get displayPrice => price == null
      ? 'Qiymət üçün əlaqə'
      : '$currencySymbol${price!.toStringAsFixed(2)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'sku': sku,
    'brand': brand,
    'categories': categories.map((item) => item.toJson()).toList(),
    'shortDescription': shortDescription,
    'description': description,
    'images': images,
    'price': price,
    'regularPrice': regularPrice,
    'salePrice': salePrice,
    'currencyCode': currencyCode,
    'currencySymbol': currencySymbol,
    'onSale': onSale,
    'inStock': inStock,
    'purchasable': purchasable,
    'permalink': permalink,
  };

  factory ShopProduct.fromJson(Map<String, dynamic> json) => ShopProduct(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    sku: json['sku']?.toString() ?? '',
    brand: json['brand']?.toString() ?? '',
    categories: (json['categories'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ShopTaxonomy.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    shortDescription: json['shortDescription']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    images: (json['images'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(),
    price: _double(json['price']),
    regularPrice: _double(json['regularPrice']),
    salePrice: _double(json['salePrice']),
    currencyCode: json['currencyCode']?.toString() ?? 'AZN',
    currencySymbol: json['currencySymbol']?.toString() ?? '₼',
    onSale: json['onSale'] == true,
    inStock: json['inStock'] == true,
    purchasable: json['purchasable'] == true,
    permalink: json['permalink']?.toString() ?? '',
  );

  static double? _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

class ShopTaxonomy {
  final int id;
  final String name;
  final String slug;
  final int parentId;
  final int count;
  final String imageUrl;

  const ShopTaxonomy({
    required this.id,
    required this.name,
    required this.slug,
    required this.parentId,
    required this.count,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'parentId': parentId,
    'count': count,
    'imageUrl': imageUrl,
  };

  factory ShopTaxonomy.fromJson(Map<String, dynamic> json) => ShopTaxonomy(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    parentId: (json['parentId'] as num?)?.toInt() ?? 0,
    count: (json['count'] as num?)?.toInt() ?? 0,
    imageUrl: json['imageUrl']?.toString() ?? '',
  );
}

class ProductPage {
  final List<ShopProduct> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final List<ShopTaxonomy> categories;
  final List<ShopTaxonomy> brands;
  final double? minPrice;
  final double? maxPrice;
  final int inStockCount;

  const ProductPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.categories,
    required this.brands,
    required this.minPrice,
    required this.maxPrice,
    required this.inStockCount,
  });

  factory ProductPage.fromJson(Map<String, dynamic> json) {
    final facets = json['facets'] is Map
        ? Map<String, dynamic>.from(json['facets'] as Map)
        : <String, dynamic>{};
    List<ShopTaxonomy> parseTaxonomies(dynamic value) =>
        (value as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => ShopTaxonomy.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
    return ProductPage(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ShopProduct.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      categories: parseTaxonomies(facets['categories']),
      brands: parseTaxonomies(facets['brands']),
      minPrice: ShopProduct._double(facets['minPrice']),
      maxPrice: ShopProduct._double(facets['maxPrice']),
      inStockCount: (facets['inStockCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShopCartItem {
  final int productId;
  final int quantity;
  final ShopProduct product;
  final double lineTotal;

  const ShopCartItem({
    required this.productId,
    required this.quantity,
    required this.product,
    required this.lineTotal,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'product': product.toJson(),
    'lineTotal': lineTotal,
  };

  factory ShopCartItem.fromJson(Map<String, dynamic> json) => ShopCartItem(
    productId: (json['productId'] as num?)?.toInt() ?? 0,
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    product: ShopProduct.fromJson(
      Map<String, dynamic>.from(json['product'] as Map? ?? const {}),
    ),
    lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
  );
}

class ShopCart {
  final List<ShopCartItem> items;
  final int itemCount;
  final double subtotal;
  final String currencyCode;
  final String currencySymbol;

  const ShopCart({
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.currencyCode,
    required this.currencySymbol,
  });
  const ShopCart.empty()
    : items = const [],
      itemCount = 0,
      subtotal = 0,
      currencyCode = 'AZN',
      currencySymbol = '₼';

  factory ShopCart.fromJson(Map<String, dynamic> json) => ShopCart(
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ShopCartItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    currencyCode: json['currencyCode']?.toString() ?? 'AZN',
    currencySymbol: json['currencySymbol']?.toString() ?? '₼',
  );
}

class CheckoutSession {
  final String checkoutUrl;
  final DateTime expiresAt;

  const CheckoutSession({required this.checkoutUrl, required this.expiresAt});
  factory CheckoutSession.fromJson(Map<String, dynamic> json) =>
      CheckoutSession(
        checkoutUrl: json['checkoutUrl']?.toString() ?? '',
        expiresAt:
            DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class ShopOrder {
  final int id;
  final String number;
  final String status;
  final DateTime? createdAt;
  final String currencyCode;
  final double total;

  const ShopOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.createdAt,
    required this.currencyCode,
    required this.total,
  });
  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
    id: (json['id'] as num?)?.toInt() ?? 0,
    number: json['number']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    currencyCode: json['currencyCode']?.toString() ?? 'AZN',
    total: (json['total'] as num?)?.toDouble() ?? 0,
  );
}
