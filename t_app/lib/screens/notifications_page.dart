import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.read,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        timestamp:
            DateTime.tryParse(
              (json['timestamp'] ?? json['createdAt'] ?? '').toString(),
            ) ??
            DateTime.now(),
        read: json['read'] == true,
      );

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    title: title,
    message: message,
    timestamp: timestamp,
    read: read ?? this.read,
  );
}

class NotificationsPage extends StatefulWidget {
  // Kept for source compatibility. ApiClient owns the base URL.
  final String? apiBaseUrl;
  final bool guest;

  const NotificationsPage({super.key, this.apiBaseUrl, this.guest = false});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<NotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    if (widget.guest) {
      _loading = false;
    } else {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await context.read<ApiClient>().get(
        'notifications/my-notifications',
        authenticated: true,
      );
      final raw = response is List
          ? response
          : response is Map
          ? (response['items'] ?? response['data'] ?? const [])
          : const [];
      final parsed =
          (raw as List)
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!mounted) return;
      setState(() {
        _items = parsed;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Bildirişləri yükləmək mümkün olmadı.';
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.read) return;
    setState(() {
      _items = _items
          .map(
            (item) =>
                item.id == notification.id ? item.copyWith(read: true) : item,
          )
          .toList();
    });
    try {
      await context.read<ApiClient>().put(
        'notifications/${notification.id}/read',
        authenticated: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(read: false)
                  : item,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildirişi yeniləmək mümkün olmadı.')),
      );
    }
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => !item.read).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(unread == 0 ? 'Bildirişlər' : 'Bildirişlər ($unread)'),
        actions: [
          IconButton(
            onPressed: widget.guest ? null : _loadNotifications,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenilə',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.guest ? () async {} : _loadNotifications,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const _CenteredScrollable(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yenidən cəhd et'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return _CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 60),
            const SizedBox(height: 12),
            const Text('Hələ bildirişiniz yoxdur.'),
            if (widget.guest) ...[
              const SizedBox(height: 8),
              const Text(
                'Alış-veriş və WhatsApp sifarişi üçün giriş tələb olunmur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final notification = _items[index];
        return Card(
          color: notification.read ? null : const Color(0xFFEAF7EF),
          child: ListTile(
            onTap: () => _markAsRead(notification),
            leading: Icon(
              notification.read
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_rounded,
              color: notification.read ? Colors.grey : const Color(0xFF15803D),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight: notification.read
                    ? FontWeight.w600
                    : FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${notification.message}\n${_formatTimestamp(notification.timestamp)}',
              ),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _CenteredScrollable extends StatelessWidget {
  final Widget child;

  const _CenteredScrollable({required this.child});

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .28),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: child),
      ),
    ],
  );
}
