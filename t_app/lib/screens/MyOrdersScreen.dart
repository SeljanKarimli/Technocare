import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Set this to match your backend (usually the same as ApiService.baseUrl)
const String kApiBaseUrl = 'http://technocareapi.runasp.net/api';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('jwtToken');

      if (userId == null || userId.isEmpty) {
        throw Exception('UserId tapılmadı (SharedPreferences). Yenidən login olun.');
      }

      // ✅ backend expects: /orders/my-orders?userId=...
      final uri = Uri.parse('$kApiBaseUrl/orders/my-orders')
          .replace(queryParameters: {'userId': userId});

      final res = await http.get(
        uri,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          if (token != null && token.isNotEmpty)
            HttpHeaders.authorizationHeader: 'Bearer $token',
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        // show backend message if any
        final body = res.body.isNotEmpty ? res.body : '';
        throw Exception('Failed to load orders (${res.statusCode}) $body');
      }

      final decoded = jsonDecode(res.body);

      // Accept either a raw list or { "orders": [...] }
      final List listJson = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['orders'] is List
              ? decoded['orders']
              : <dynamic>[]);

      setState(() {
        _orders = listJson
            .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
            .cast<Map<String, dynamic>>()
            .toList();
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _getSafeImageUrl(String url) {
    final trimmed = url.trim();
    return trimmed.isEmpty ? 'https://via.placeholder.com/300?text=No+Image' : trimmed;
  }

  String _getProxyImageUrl(String url) {
    return "https://wsrv.nl/?url=${Uri.encodeComponent(url.trim())}";
  }

  String _currency(num n) => '₼${n.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sifarişlərim')),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchOrders,
                              child: const Text('Yenilə'),
                            )
                          ],
                        ),
                      ),
                    ],
                  )
                : _orders.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('Hələ sifarişiniz yoxdur')),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = _orders[index];

                          final id = _str(order, ['id', 'Id']);
                          final status = _str(order, ['status', 'Status']) ?? 'Pending';

                          // NOTE: your NEW backend Order model might not have these:
                          final total = _num(order, ['totalAmount', 'TotalAmount']) ?? 0;
                          final orderDate = _date(order, ['orderDate', 'OrderDate']);
                          final shipping = _str(order, ['shippingAddress', 'ShippingAddress']);
                          final payment = _str(order, ['paymentMethod', 'PaymentMethod']);

                          final items = (order['items'] ?? order['Items']) as List? ?? const [];

                          return Card(
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDate(orderDate),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      _StatusPill(status: status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'ID: ${_shortId(id)}',
                                          style: TextStyle(color: Colors.grey[700]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        _currency(total),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (shipping != null && shipping.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('Ünvan: $shipping',
                                          style: TextStyle(color: Colors.grey[700])),
                                    ),
                                  if (payment != null && payment.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('Ödəniş: $payment',
                                          style: TextStyle(color: Colors.grey[700])),
                                    ),
                                  const SizedBox(height: 10),
                                  const Text('Məhsullar',
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  ...items.map((raw) {
                                    final m = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
                                    final name = _str(m, ['productName', 'ProductName']) ?? '';
                                    final qty = _int(m, ['quantity', 'Quantity']) ?? 0;
                                    final price = _num(m, ['price', 'Price']) ?? 0;
                                    final img = _str(m, ['imageUrl', 'ImageUrl']);

                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: (img != null && img.isNotEmpty)
                                            ? Image.network(
                                                _getSafeImageUrl(img),
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Image.network(
                                                      _getProxyImageUrl(img),
                                                      width: 48,
                                                      height: 48,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) =>
                                                          const Icon(Icons.image_not_supported),
                                                    ),
                                              )
                                            : const SizedBox(
                                                width: 48,
                                                height: 48,
                                                child: Icon(Icons.inventory_2_outlined),
                                              ),
                                      ),
                                      title: Text(name,
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                      subtitle: Text('x$qty  •  ${_currency(price)}'),
                                      trailing: Text(
                                        _currency(price * qty),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  // ---------- helpers ----------
  String? _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String) return v;
      if (v != null) return v.toString();
    }
    return null;
  }

  num? _num(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final parsed = num.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  int? _int(Map<String, dynamic> m, List<String> keys) => _num(m, keys)?.toInt();

  DateTime? _date(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {}
    }
    return null;
  }

  String _shortId(String? id) {
    if (id == null || id.length < 8) return id ?? '';
    return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}  ${two(local.hour)}:${two(local.minute)}';
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  Color _bg() {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFF3CD);
      case 'paid':
      case 'completed':
        return const Color(0xFFD4EDDA);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFF8D7DA);
      default:
        return const Color(0xFFE2E3E5);
    }
  }

  Color _fg() {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFF856404);
      case 'paid':
      case 'completed':
        return const Color(0xFF155724);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFF721C24);
      default:
        return const Color(0xFF383D41);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontWeight: FontWeight.w600, color: _fg()),
      ),
    );
  }
}