import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/image_url.dart';
import '../models/shop_models.dart';
import '../providers/shop_cart_provider.dart';
import '../services/whatsapp_order_service.dart';

class ShopCartPage extends StatefulWidget {
  const ShopCartPage({super.key});

  @override
  State<ShopCartPage> createState() => _ShopCartPageState();
}

class _ShopCartPageState extends State<ShopCartPage> {
  bool _preparingOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ShopCartProvider>().load(),
    );
  }

  Future<void> _sendOrder() async {
    setState(() => _preparingOrder = true);
    try {
      final cartProvider = context.read<ShopCartProvider>();
      await cartProvider.load();
      if (!mounted) return;
      final cart = cartProvider.cart;
      if (cart.items.isEmpty) {
        return;
      }
      final unavailable = cart.items
          .where((item) => !item.product.inStock || !item.product.purchasable)
          .toList();
      if (unavailable.isNotEmpty) {
        final names = unavailable.map((item) => item.product.name).join(', ');
        throw StateError('Bu məhsullar hazırda mövcud deyil: $names');
      }
      final stale = cartProvider.usingStalePrices;
      if (stale) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Qiymət yenilənə bilmədi'),
            content: const Text(
              'Hazırda canlı qiymət və stok yoxlanılmadı. Sifariş mətnində yekun qiymətin Technocare nümayəndəsi tərəfindən təsdiqlənəcəyi qeyd olunacaq.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ləğv et'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Davam et'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
      final service = context.read<WhatsAppOrderService>();
      final uri = await service.createOrderUri(
        cart,
        pricesRequireConfirmation: stale,
      );
      var opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!opened) {
        final phone = await service.resolveTechnocarePhone();
        final message = service.buildOrderMessage(
          cart,
          pricesRequireConfirmation: stale,
        );
        await Clipboard.setData(ClipboardData(text: '+$phone\n\n$message'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'WhatsApp açılmadı. Nömrə və sifariş mətni kopyalandı.',
            ),
          ),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Sifariş mətni WhatsApp-da hazırlandı. Göndər düyməsini basın.',
          ),
          action: SnackBarAction(
            label: 'Səbəti təmizlə',
            onPressed: () => cartProvider.clear(),
          ),
        ),
      );
    } catch (error) {
      final message = error is StateError
          ? error.message.toString()
          : error.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _preparingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Səbətim')),
      body: Consumer<ShopCartProvider>(
        builder: (context, state, _) {
          if (state.loading && state.cart.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.cart.items.isEmpty) {
            return _CartMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Səbət yüklənmədi',
              message: state.error!,
              action: state.load,
            );
          }
          if (state.cart.items.isEmpty) {
            return const _CartMessage(
              icon: Icons.shopping_cart_outlined,
              title: 'Səbət boşdur',
              message: 'Mağazadan məhsul seçərək alış-verişə başlayın.',
            );
          }
          return RefreshIndicator(
            onRefresh: state.load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              itemCount: state.cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) =>
                  _CartLine(item: state.cart.items[index]),
            ),
          );
        },
      ),
      bottomNavigationBar: Consumer<ShopCartProvider>(
        builder: (context, state, _) {
          if (state.cart.items.isEmpty) return const SizedBox.shrink();
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 14,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${state.cart.itemCount} məhsul',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const Spacer(),
                      Text(
                        '${state.cart.currencySymbol}${state.cart.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sifariş mətni avtomatik hazırlanacaq.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _preparingOrder ? null : _sendOrder,
                      icon: _preparingOrder
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.chat_outlined),
                      label: const Text('WhatsApp ilə sifariş et'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF087A32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  final ShopCartItem item;
  const _CartLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShopCartProvider>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9E2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 88,
              height: 88,
              child: item.product.primaryImage.isEmpty
                  ? const Icon(Icons.inventory_2_outlined)
                  : CachedNetworkImage(
                      imageUrl: AppImageUrl.resolve(item.product.primaryImage),
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFFF4F6F3)),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF4F6F3),
                        child: Icon(Icons.inventory_2_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.product.currencySymbol}${item.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QuantityButton(
                      icon: Icons.remove,
                      onPressed: item.quantity > 1
                          ? () => provider.update(
                              item.productId,
                              item.quantity - 1,
                            )
                          : null,
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add,
                      onPressed: item.quantity < 99
                          ? () => provider.update(
                              item.productId,
                              item.quantity + 1,
                            )
                          : null,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Səbətdən sil',
                      onPressed: () => provider.remove(item.productId),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _QuantityButton({required this.icon, this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: IconButton.outlined(
      tooltip: icon == Icons.add ? 'Miqdarı artır' : 'Miqdarı azalt',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 17),
    ),
  );
}

class _CartMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  const _CartMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 70, color: const Color(0xFF2F7623)),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
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
