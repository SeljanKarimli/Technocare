import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_models.dart';
import '../providers/shop_cart_provider.dart';

class ShopProductDetailPage extends StatelessWidget {
  final ShopProduct product;
  const ShopProductDetailPage({super.key, required this.product});

  Future<void> _add(BuildContext context) async {
    try {
      await context.read<ShopCartProvider>().add(product);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Məhsul səbətə əlavə edildi.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Məhsul məlumatı')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 350,
              child: product.primaryImage.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 90,
                        color: Colors.grey,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: product.primaryImage,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const ColoredBox(
                        color: Color(0xFFF4F6F3),
                      ),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF4F6F3),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 90,
                          color: Color(0xFF69736C),
                        ),
                      ),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            sliver: SliverList.list(
              children: [
                if (product.brand.isNotEmpty)
                  Text(
                    product.brand.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF2F7623),
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                if (product.sku.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Stok kodu: ${product.sku}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      product.displayPrice,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: product.inStock
                            ? const Color(0xFFE8F7E3)
                            : const Color(0xFFFFECEC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          product.inStock ? 'Stokda var' : 'Stokda yoxdur',
                          style: TextStyle(
                            color: product.inStock
                                ? const Color(0xFF327A24)
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 36),
                const Text(
                  'Məhsul haqqında',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  product.description.isEmpty
                      ? product.shortDescription
                      : product.description,
                  style: const TextStyle(
                    color: Color(0xFF5F6962),
                    height: 1.55,
                  ),
                ),
                if (product.categories.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.categories
                        .map((item) => Chip(label: Text(item.name)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: product.purchasable && product.inStock
                  ? () => _add(context)
                  : null,
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: Text(
                product.inStock ? 'Səbətə əlavə et' : 'Hazırda mövcud deyil',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2F7623),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
