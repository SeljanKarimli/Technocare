import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<CartItemFlutter> _items = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  CartItemFlutter _safeCartItemFromJson(Map<String, dynamic> json) {
    final fixed = Map<String, dynamic>.from(json);

    fixed['productId'] ??= '';
    fixed['productName'] ??= '';
    fixed['imageUrl'] ??= '';
    fixed['price'] ??= 0;
    fixed['quantity'] ??= 0;

    return CartItemFlutter.fromJson(fixed);
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.getCart();
      if (response is Map<String, dynamic>) {
        final itemsJson = response['items'];

        if (itemsJson is List) {
          setState(() {
            _items = itemsJson
                .whereType<Map<String, dynamic>>()
                .map(_safeCartItemFromJson)
                .toList();
          });
        } else {
          setState(() {
            _items = [];
          });
        }
      } else {
        setState(() {
          _items = [];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getSafeImageUrl(String url) {
    final trimmed = url.trim();
    return trimmed.isEmpty ? 'https://via.placeholder.com/300?text=No+Image' : trimmed;
  }

  String _getProxyImageUrl(String url) {
    return "https://wsrv.nl/?url=${Uri.encodeComponent(url.trim())}";
  }

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  double get _deliveryFee => 5.0;
  double get _discount => 2.0;
  double get _total => _subtotal + _deliveryFee - _discount;

  Future<void> _confirmOrder() async {
    if (_items.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final auth = context.read<AuthProvider>();

      final uid = auth.userId;
      final mail = auth.userEmail;

      if (uid == null || uid.isEmpty) {
        throw Exception("userId yoxdur. Yenidən login ol.");
      }
      if (mail == null || mail.isEmpty) {
        throw Exception("email yoxdur. Profil / login məlumatlarını yoxla.");
      }

      final cart = await apiService.getCart();
      final cartId = (cart['id'] ?? cart['cartId'] ?? cart['CartId']).toString();

      final orderPayload = {
        "CartId": cartId,
        "UserId": uid,
        "Email": mail,
        "shippingAddress": "Technocare default address",
        "paymentMethod": "Online",
      };

      await apiService.createOrder(orderPayload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sifariş uğurla tamamlandı')),
      );

      setState(() => _items = []);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödəniş', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.orange.shade300,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Səbət boşdur',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ödənişə davam etmək üçün səbətə məhsul əlavə edin',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: Image.network(
                                          _getSafeImageUrl(item.imageUrl),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Image.network(
                                              _getProxyImageUrl(item.imageUrl),
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.broken_image, size: 24),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.productName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.quantity} x ₼${item.price.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₼${(item.price * item.quantity).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildSummaryRow('Ümumi məbləğ', '₼${_subtotal.toStringAsFixed(2)}'),
                              _buildSummaryRow('Çatdırılma haqqı', '₼${_deliveryFee.toStringAsFixed(2)}'),
                              _buildSummaryRow('Endirim', '-₼${_discount.toStringAsFixed(2)}'),
                              const Divider(height: 24),
                              _buildSummaryRow('Cəmi', '₼${_total.toStringAsFixed(2)}', isTotal: true),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: (_items.isEmpty || _isLoading) ? null : _confirmOrder,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shadowColor: Colors.green.withOpacity(0.3),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text('Ödənişi təsdiqlə'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
