import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/shop_models.dart';
import '../repositories/shop_repository.dart';

class ShopOrdersPage extends StatefulWidget {
  const ShopOrdersPage({super.key});

  @override
  State<ShopOrdersPage> createState() => _ShopOrdersPageState();
}

class _ShopOrdersPageState extends State<ShopOrdersPage> {
  late Future<List<ShopOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = context.read<ShopRepository>().getOrders();
  }

  Future<void> _refresh() async {
    final value = context.read<ShopRepository>().getOrders();
    setState(() => _orders = value);
    await value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sifarişlərim')),
      body: FutureBuilder<List<ShopOrder>>(
        future: _orders,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final orders = snapshot.data ?? const [];
          if (orders.isEmpty) return const Center(child: Text('Hələ sifarişiniz yoxdur.'));
          return RefreshIndicator(onRefresh: _refresh, child: ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: orders.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, index) {
              final order = orders[index];
              return Card(child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(backgroundColor: Color(0xFFE8F7E3), child: Icon(Icons.receipt_long_outlined, color: Color(0xFF2F7623))),
                title: Text('Sifariş #${order.number}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${order.createdAt == null ? '' : DateFormat('dd.MM.yyyy').format(order.createdAt!.toLocal())}\n${order.status}'),
                isThreeLine: true,
                trailing: Text('₼${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ));
            },
          ));
        },
      ),
    );
  }
}
