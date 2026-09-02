import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;
  final bool isBroadcast;
  final String? url;
  final String? category;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.read,
    required this.isBroadcast,
    this.url,
    this.category,
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
        isBroadcast: json['isBroadcast'] == true || !json.containsKey('userId'),
        url: json['url']?.toString(),
        category: json['category']?.toString(),
      );

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    title: title,
    message: message,
    timestamp: timestamp,
    read: read ?? this.read,
    isBroadcast: isBroadcast,
    url: url,
    category: category,
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
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = context.read<ApiClient>();
      final responses = <dynamic>[
        await api.get('notifications/public', query: {'limit': 50}),
      ];
      if (!widget.guest) {
        responses.add(
          await api.get('notifications/my-notifications', authenticated: true),
        );
      }
      final raw = <dynamic>[];
      for (final response in responses) {
        final items = response is List
            ? response
            : response is Map
            ? response['items'] ?? response['data']
            : null;
        if (items is List) raw.addAll(items);
      }
      final preferences = await SharedPreferences.getInstance();
      final localRead =
          preferences.getStringList('readBroadcastNotifications')?.toSet() ??
          <String>{};
      final seen = <String>{};
      final parsed =
          raw
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.isNotEmpty && seen.add(item.id))
              .map(
                (item) => item.isBroadcast && localRead.contains(item.id)
                    ? item.copyWith(read: true)
                    : item,
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
    if (!notification.read) {
      setState(() {
        _items = _items
            .map(
              (item) =>
                  item.id == notification.id ? item.copyWith(read: true) : item,
            )
            .toList();
      });
      try {
        if (notification.isBroadcast) {
          final preferences = await SharedPreferences.getInstance();
          final read =
              preferences
                  .getStringList('readBroadcastNotifications')
                  ?.toSet() ??
              <String>{};
          read.add(notification.id);
          await preferences.setStringList(
            'readBroadcastNotifications',
            [
              notification.id,
              ...read.where((id) => id != notification.id),
            ].take(500).toList(),
          );
        } else {
          await context.read<ApiClient>().put(
            'notifications/${notification.id}/read',
            authenticated: true,
          );
        }
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
    final uri = Uri.tryParse(notification.url ?? '');
    if (uri != null && uri.hasScheme) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenilə',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadNotifications, child: _body()),
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
                'Saytda yenilik olduqda bildirişlər burada görünəcək. Sistem bildirişlərinə cihaz icazəsi verin.',
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
