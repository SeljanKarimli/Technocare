import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation.dart'; // ApiService, HomePage, CheckoutPage burada olsun

class MyCartPage extends StatefulWidget {
  const MyCartPage({super.key});

  @override
  State<MyCartPage> createState() => _MyCartPageState();
}

class _MyCartPageState extends State<MyCartPage> {
  List<CartItemFlutter> _cartItems = [];
  bool _isLoadingCart = false;
  String? _cartErrorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  // BACKEND-dən gələn map-i CartItem-ə çevirir, null-ları safe edir
  CartItemFlutter  _safeCartItemFromJson(Map<String, dynamic> json) {
    final fixed = Map<String, dynamic>.from(json);

    fixed['productId'] ??= '';
    fixed['productName'] ??= '';
    fixed['imageUrl'] ??= '';
    fixed['price'] ??= 0;
    fixed['quantity'] ??= 0;

    return CartItemFlutter.fromJson(fixed);
  }

  Future<void> _fetchCart() async {
    setState(() {
      _isLoadingCart = true;
      _cartErrorMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.getCart(); // Future<Map<String, dynamic>>

      if (response is Map<String, dynamic>) {
        final itemsJson = response['items'];

        if (itemsJson is List) {
          setState(() {
            _cartItems = itemsJson
                .whereType<Map<String, dynamic>>()
                .map(_safeCartItemFromJson)
                .toList();
          });
        } else {
          setState(() {
            _cartItems = [];
          });
          print(
              'Warning: cart response has no valid items list: ${response['items']}');
        }
      } else {
        setState(() {
          _cartItems = [];
        });
        print('Warning: unexpected cart response type: ${response.runtimeType}');
      }
    } catch (e) {
      setState(() {
        _cartErrorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      _showSnackBar('Səbət yüklənərkən xəta: $_cartErrorMessage', Colors.red);
    } finally {
      setState(() {
        _isLoadingCart = false;
      });
    }
  }

Future<void> _updateCartItemQuantity(String productId, int quantity) async {
  if (quantity < 1) {
    await _removeCartItem(productId);
    return;
  }

  try {
    final apiService = Provider.of<ApiService>(context, listen: false);
    await apiService.updateCartItem(productId, quantity);
    await _fetchCart();
    _showSnackBar('Səbət güncəlləndi.', Colors.green);
  } catch (e) {
    _showSnackBar(
      'Səbət güncəllənərkən xəta: ${e.toString().replaceFirst('Exception: ', '')}',
      Colors.red,
    );
  }
}

Future<void> _removeCartItem(String productId) async {
  try {
    final apiService = Provider.of<ApiService>(context, listen: false);
    await apiService.removeCartItem(productId);
    await _fetchCart();
    _showSnackBar('Məhsul səbətdən silindi.', Colors.green);
  } catch (e) {
    _showSnackBar(
      'Məhsul silinərkən xəta: ${e.toString().replaceFirst('Exception: ', '')}',
      Colors.red,
    );
  }
}


  String _getSafeImageUrl(String url) {
    final trimmed = url.trim();
    return trimmed.isEmpty ? 'https://via.placeholder.com/300?text=No+Image' : trimmed;
  }

  String _getProxyImageUrl(String url) {
    return "https://wsrv.nl/?url=${Uri.encodeComponent(url.trim())}";
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  double get _subtotal {
    return _cartItems.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  double get _deliveryFee => 5.00;
  double get _discount => 2.00;
  double get _total => _subtotal + _deliveryFee - _discount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Səbətim', style: TextStyle(color: Colors.black)),
        automaticallyImplyLeading: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          },
        ),
      ),
      body: _isLoadingCart
          ? const Center(child: CircularProgressIndicator())
          : _cartErrorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _cartErrorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              : _cartItems.isEmpty
                  ? const _EmptyCartView()
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) {
                              final item = _cartItems[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12.0),
                                        child: Image.network(
                                          _getSafeImageUrl(item.imageUrl),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Image.network(
                                              _getProxyImageUrl(item.imageUrl),
                                              width: 90,
                                              height: 90,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 90,
                                                  height: 90,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.productName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8.0),
                                            Text(
                                              '\₼${item.price.toStringAsFixed(2)} / ədəd',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 12.0),
                                            Row(
                                              children: [
                                                _buildQuantityButton(
                                                  Icons.remove,
                                                  () => _updateCartItemQuantity(
                                                    item.productId,
                                                    item.quantity - 1,
                                                  ),
                                                  isAdd: false,
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                  child: Text(
                                                    item.quantity.toString(),
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                _buildQuantityButton(
                                                  Icons.add,
                                                  () => _updateCartItemQuantity(
                                                    item.productId,
                                                  item.quantity + 1,
                                                  ),
                                                  isAdd: true,
                                                ),
                                                const Spacer(),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () => _removeCartItem(item.productId),
                                                ),
                                              ],
                                            ),
                                          ],
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
                              _buildSummaryRow('Ümumi məbləğ', '\₼${_subtotal.toStringAsFixed(2)}'),
                              _buildSummaryRow('Çatdırılma haqqı', '\₼${_deliveryFee.toStringAsFixed(2)}'),
                              _buildSummaryRow('Endirim', '-\₼${_discount.toStringAsFixed(2)}'),
                              const Divider(height: 24),
                              _buildSummaryRow('Cəmi', '\₼${_total.toStringAsFixed(2)}', isTotal: true),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const CheckoutPage(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shadowColor: Colors.green.withOpacity(0.3),
                                  ),
                                  child: const Text('Ödənişə keç'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onTap, {required bool isAdd}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAdd ? Colors.green : Colors.transparent,
          border: Border.all(color: Colors.green, width: 1.5),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isAdd ? Colors.white : Colors.green,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: Colors.green.shade300,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Səbətiniz boşdur!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Alış-verişə başlamaq üçün məhsullar əlavə edin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Məhsullara keç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dart CartItem – C# CartItem modelinin Flutter versiyası
class CartItemFlutter {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String imageUrl;

  CartItemFlutter({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  factory CartItemFlutter.fromJson(Map<String, dynamic> json) {
    final productId = json['productId']?.toString() ?? '';
    final productName = json['productName']?.toString() ?? '';
    final imageUrl = json['imageUrl']?.toString() ?? '';

    final rawPrice = json['price'];
    final double price;
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else {
      price = double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0;
    }

    final rawQty = json['quantity'];
    final int quantity;
    if (rawQty is num) {
      quantity = rawQty.toInt();
    } else {
      quantity = int.tryParse(rawQty?.toString() ?? '0') ?? 0;
    }

    return CartItemFlutter(
      productId: productId,
      productName: productName,
      price: price,
      quantity: quantity,
      imageUrl: imageUrl,
    );
  }
}