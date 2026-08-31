import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_models.dart';
import '../providers/shop_cart_provider.dart';
import '../repositories/shop_repository.dart';
import 'ShopProductDetailPage.dart';

class ShopPage extends StatefulWidget {
  final String initialQuery;
  const ShopPage({super.key, this.initialQuery = ''});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<ShopProduct> _products = [];
  List<ShopTaxonomy> _categories = [];
  List<ShopTaxonomy> _brands = [];
  List<String> _recentSearches = [];
  int? _categoryId;
  String? _brand;
  String _sort = 'relevance';
  bool _inStock = false;
  double? _minPrice;
  double? _maxPrice;
  double? _availableMinPrice;
  double? _availableMaxPrice;
  int _page = 1;
  int _total = 0;
  int _totalPages = 1;
  int _requestVersion = 0;
  Completer<void>? _requestCancellation;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _scrollController.addListener(_onScroll);
    _loadRecentSearches();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final cancellation = _requestCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await context.read<ShopRepository>().getRecentSearches();
    if (mounted) setState(() => _recentSearches = searches);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetch(reset: true),
    );
    setState(() => _showSuggestions = value.trim().length >= 2);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 &&
        !_loadingMore &&
        !_loading &&
        _page < _totalPages) {
      _fetch(reset: false);
    }
  }

  Future<void> _fetch({required bool reset}) async {
    if (reset) {
      final previous = _requestCancellation;
      if (previous != null && !previous.isCompleted) previous.complete();
      _requestCancellation = Completer<void>();
    }
    final cancellation = _requestCancellation ??= Completer<void>();
    final requestVersion = ++_requestVersion;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final result = await context.read<ShopRepository>().getProducts(
        query: _searchController.text,
        page: reset ? 1 : _page + 1,
        categoryId: _categoryId,
        brand: _brand,
        inStock: _inStock,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sort: _sort,
        abortTrigger: cancellation.future,
      );
      if (!mounted || requestVersion != _requestVersion) return;
      if (_searchController.text.trim().length >= 2) {
        await context.read<ShopRepository>().saveRecentSearch(
          _searchController.text,
        );
        await _loadRecentSearches();
      }
      setState(() {
        _products = reset
            ? result.items
            : [
                ..._products,
                ...result.items.where(
                  (item) =>
                      !_products.any((existing) => existing.id == item.id),
                ),
              ];
        _categories = result.categories;
        _brands = result.brands;
        _availableMinPrice = result.minPrice;
        _availableMaxPrice = result.maxPrice;
        _page = result.page;
        _total = result.total;
        _totalPages = result.totalPages;
        _error = null;
      });
    } catch (error) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _addToCart(ShopProduct product) async {
    try {
      await context.read<ShopCartProvider>().add(product);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} səbətə əlavə edildi.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        categories: _categories,
        brands: _brands,
        categoryId: _categoryId,
        brand: _brand,
        sort: _sort,
        inStock: _inStock,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        availableMinPrice: _availableMinPrice,
        availableMaxPrice: _availableMaxPrice,
      ),
    );
    if (result == null) return;
    setState(() {
      _categoryId = result.categoryId;
      _brand = result.brand;
      _sort = result.sort;
      _inStock = result.inStock;
      _minPrice = result.minPrice;
      _maxPrice = result.maxPrice;
    });
    await _fetch(reset: true);
  }

  int get _activeFilterCount =>
      (_categoryId == null ? 0 : 1) +
      (_brand == null ? 0 : 1) +
      (_inStock ? 1 : 0) +
      (_sort == 'relevance' ? 0 : 1) +
      (_minPrice == null && _maxPrice == null ? 0 : 1);

  void _changeFilter(VoidCallback change) {
    setState(change);
    _fetch(reset: true);
  }

  void _clearAllFilters() => _changeFilter(() {
    _categoryId = null;
    _brand = null;
    _sort = 'relevance';
    _inStock = false;
    _minPrice = null;
    _maxPrice = null;
  });

  String _categoryLabel() {
    for (final item in _categories) {
      if (item.id == _categoryId) return item.name;
    }
    return 'Kateqoriya';
  }

  String _brandLabel() {
    for (final item in _brands) {
      if (item.slug == _brand) return item.name;
    }
    return 'Brend';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  setState(() => _showSuggestions = false);
                  _fetch(reset: true);
                },
                decoration: InputDecoration(
                  hintText: 'Məhsul, SKU və ya brend axtarın',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _showSuggestions = false);
                            _fetch(reset: true);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF2F5F1),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _loading ? 'Məhsullar yüklənir…' : '$_total məhsul',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4C5750),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openFilters,
                    icon: Badge(
                      isLabelVisible: _activeFilterCount > 0,
                      label: Text('$_activeFilterCount'),
                      child: const Icon(Icons.tune_rounded, size: 19),
                    ),
                    label: const Text('Filtrlər'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_showSuggestions && _products.isNotEmpty)
          Material(
            color: Colors.white,
            elevation: 5,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _products.length > 5 ? 5 : _products.length,
                itemBuilder: (_, index) {
                  final suggestion = _products[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.search_rounded, size: 19),
                    title: Text(
                      suggestion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: suggestion.sku.isEmpty
                        ? null
                        : Text('SKU: ${suggestion.sku}'),
                    onTap: () {
                      _searchController.text = suggestion.name;
                      setState(() => _showSuggestions = false);
                      _fetch(reset: true);
                    },
                  );
                },
              ),
            ),
          ),
        if (_activeFilterCount > 0)
          SizedBox(
            height: 46,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              scrollDirection: Axis.horizontal,
              children: [
                if (_categoryId != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: InputChip(
                      label: Text(_categoryLabel()),
                      onDeleted: () => _changeFilter(() => _categoryId = null),
                    ),
                  ),
                if (_brand != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: InputChip(
                      label: Text(_brandLabel()),
                      onDeleted: () => _changeFilter(() => _brand = null),
                    ),
                  ),
                if (_inStock)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: InputChip(
                      label: const Text('Stokda'),
                      onDeleted: () => _changeFilter(() => _inStock = false),
                    ),
                  ),
                if (_minPrice != null || _maxPrice != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: InputChip(
                      label: Text(
                        '${_minPrice?.toStringAsFixed(0) ?? '0'}–${_maxPrice?.toStringAsFixed(0) ?? '∞'} ₼',
                      ),
                      onDeleted: () => _changeFilter(() {
                        _minPrice = null;
                        _maxPrice = null;
                      }),
                    ),
                  ),
                if (_sort != 'relevance')
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: InputChip(
                      label: const Text('Sıralama'),
                      onDeleted: () => _changeFilter(() => _sort = 'relevance'),
                    ),
                  ),
                ActionChip(
                  label: const Text('Hamısını təmizlə'),
                  onPressed: _clearAllFilters,
                ),
              ],
            ),
          ),
        if (_recentSearches.isNotEmpty && _searchController.text.isEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _recentSearches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ActionChip(
                avatar: const Icon(Icons.history, size: 16),
                label: Text(_recentSearches[index]),
                onPressed: () {
                  _searchController.text = _recentSearches[index];
                  _fetch(reset: true);
                },
              ),
            ),
          ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) return const _ShopSkeleton();
    if (_error != null && _products.isEmpty) {
      return _ShopMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Məhsullar yüklənmədi',
        message: _error!,
        action: () => _fetch(reset: true),
      );
    }
    if (_products.isEmpty) {
      return _ShopMessage(
        icon: Icons.search_off_rounded,
        title: 'Məhsul tapılmadı',
        message: 'Axtarışı və ya filtrləri dəyişərək yenidən sınayın.',
        action: () {
          _searchController.clear();
          setState(() {
            _categoryId = null;
            _brand = null;
            _sort = 'relevance';
            _inStock = false;
            _minPrice = null;
            _maxPrice = null;
          });
          _fetch(reset: true);
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: .60,
        ),
        itemCount: _products.length + (_loadingMore ? 2 : 0),
        itemBuilder: (_, index) {
          if (index >= _products.length)
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2EF),
                borderRadius: BorderRadius.circular(16),
              ),
            );
          final product = _products[index];
          return _ShopProductCard(
            product: product,
            onAdd: () => _addToCart(product),
          );
        },
      ),
    );
  }
}

class _ShopProductCard extends StatelessWidget {
  final ShopProduct product;
  final VoidCallback onAdd;
  const _ShopProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopProductDetailPage(product: product),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE4E9E2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: product.primaryImage.isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: product.primaryImage,
                              fit: BoxFit.contain,
                              placeholder: (_, __) =>
                                  Container(color: const Color(0xFFF4F6F3)),
                            ),
                    ),
                    if (product.onSale)
                      const Positioned(
                        top: 9,
                        left: 9,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF59BE3F),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            child: Text(
                              'ENDİRİM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand.isEmpty
                          ? 'TECHNOCARE'
                          : product.brand.toUpperCase(),
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF59BE3F),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                      ),
                    ),
                    if (product.sku.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'SKU: ${product.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.displayPrice,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: product.purchasable && product.inStock
                              ? onAdd
                              : null,
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF59BE3F),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterResult {
  final int? categoryId;
  final String? brand;
  final String sort;
  final bool inStock;
  final double? minPrice;
  final double? maxPrice;
  const _FilterResult(
    this.categoryId,
    this.brand,
    this.sort,
    this.inStock,
    this.minPrice,
    this.maxPrice,
  );
}

class _FilterSheet extends StatefulWidget {
  final List<ShopTaxonomy> categories;
  final List<ShopTaxonomy> brands;
  final int? categoryId;
  final String? brand;
  final String sort;
  final bool inStock;
  final double? minPrice;
  final double? maxPrice;
  final double? availableMinPrice;
  final double? availableMaxPrice;
  const _FilterSheet({
    required this.categories,
    required this.brands,
    required this.categoryId,
    required this.brand,
    required this.sort,
    required this.inStock,
    required this.minPrice,
    required this.maxPrice,
    required this.availableMinPrice,
    required this.availableMaxPrice,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late int? categoryId = widget.categoryId;
  late String? brand = widget.brand;
  late String sort = widget.sort;
  late bool inStock = widget.inStock;
  late double? minPrice = widget.minPrice;
  late double? maxPrice = widget.maxPrice;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Məhsulları filtrlə',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int?>(
                value: categoryId,
                decoration: const InputDecoration(labelText: 'Kateqoriya'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Bütün kateqoriyalar'),
                  ),
                  ...widget.categories.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(
                        '${item.name} (${item.count})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => categoryId = value),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                value: brand,
                decoration: const InputDecoration(labelText: 'Brend'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Bütün brendlər'),
                  ),
                  ...widget.brands.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.slug,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => brand = value),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: sort,
                decoration: const InputDecoration(labelText: 'Sıralama'),
                items: const [
                  DropdownMenuItem(value: 'relevance', child: Text('Uyğunluq')),
                  DropdownMenuItem(
                    value: 'popularity',
                    child: Text('Populyarlıq'),
                  ),
                  DropdownMenuItem(value: 'latest', child: Text('Ən yeni')),
                  DropdownMenuItem(
                    value: 'price_asc',
                    child: Text('Qiymət: aşağıdan yuxarı'),
                  ),
                  DropdownMenuItem(
                    value: 'price_desc',
                    child: Text('Qiymət: yuxarıdan aşağı'),
                  ),
                  DropdownMenuItem(value: 'name', child: Text('Ada görə')),
                ],
                onChanged: (value) =>
                    setState(() => sort = value ?? 'relevance'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('min-$minPrice'),
                      initialValue: minPrice?.toStringAsFixed(0) ?? '',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Min. qiymət',
                        hintText: widget.availableMinPrice?.toStringAsFixed(0),
                      ),
                      onChanged: (value) => minPrice = double.tryParse(
                        value.replaceAll(',', '.'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('max-$maxPrice'),
                      initialValue: maxPrice?.toStringAsFixed(0) ?? '',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Maks. qiymət',
                        hintText: widget.availableMaxPrice?.toStringAsFixed(0),
                      ),
                      onChanged: (value) => maxPrice = double.tryParse(
                        value.replaceAll(',', '.'),
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: inStock,
                activeColor: const Color(0xFF59BE3F),
                title: const Text('Yalnız stokda olanlar'),
                onChanged: (value) => setState(() => inStock = value),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        categoryId = null;
                        brand = null;
                        sort = 'relevance';
                        inStock = false;
                        minPrice = null;
                        maxPrice = null;
                      }),
                      child: const Text('Təmizlə'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (minPrice != null &&
                            maxPrice != null &&
                            minPrice! > maxPrice!) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Minimum qiymət maksimum qiymətdən böyük ola bilməz.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(
                          context,
                          _FilterResult(
                            categoryId,
                            brand,
                            sort,
                            inStock,
                            minPrice,
                            maxPrice,
                          ),
                        );
                      },
                      child: const Text('Tətbiq et'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopSkeleton extends StatelessWidget {
  const _ShopSkeleton();
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(14),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: .60,
    ),
    itemCount: 8,
    itemBuilder: (_, __) => Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2EF),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

class _ShopMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback action;
  const _ShopMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF59BE3F)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: action, child: const Text('Yenidən cəhd et')),
        ],
      ),
    ),
  );
}
