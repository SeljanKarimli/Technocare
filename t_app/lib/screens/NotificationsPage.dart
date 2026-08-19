import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.read,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] ?? json['Id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? json['Title'] ?? '').toString(),
      message: (json['message'] ?? json['Message'] ?? '').toString(),
      timestamp: DateTime.tryParse(
            (json['timestamp'] ??
                    json['Timestamp'] ??
                    json['createdAt'] ??
                    json['CreatedAt'] ??
                    '')
                .toString(),
          ) ??
          DateTime.now(),
      read: (json['read'] ?? json['Read'] ?? false) == true,
    );
  }
}

class NotificationsPage extends StatefulWidget {
  /// Example: "https://technocareapi.runasp.net"
  final String apiBaseUrl;

  const NotificationsPage({super.key, required this.apiBaseUrl});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token'); // səndə token başqa addadırsa dəyiş
  }

  Map<String, String> _headers(String? token) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Uri _u(String path) {
    final base = widget.apiBaseUrl.endsWith('/')
        ? widget.apiBaseUrl.substring(0, widget.apiBaseUrl.length - 1)
        : widget.apiBaseUrl;

    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  List<dynamic> _extractList(dynamic decoded) {
    // Backend bəzən belə qaytarır: [{...}, {...}]
    if (decoded is List) return decoded;

    // Bəzən belə olur: { "data": [ ... ] } və ya { "items": [ ... ] }
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'] ?? decoded['items'] ?? decoded['result'];
      if (data is List) return data;
    }
    return <dynamic>[];
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getToken();

      final url = _u('notifications/my-notifications');
      debugPrint('GET => $url');

      final res = await http.get(url, headers: _headers(token));
      debugPrint('Status => ${res.statusCode}');
      debugPrint('Body => ${res.body}');

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final list = _extractList(decoded);

        final parsed = list
            .where((e) => e is Map)
            .map((e) => NotificationItem.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();

        setState(() {
          _items = parsed;
          _loading = false;
        });
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        setState(() {
          _error = 'Unauthorized. Please log in again.';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load notifications (${res.statusCode}).';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationItem n) async {
    if (n.read) return;

    // optimistic UI
    setState(() {
      _items = _items
          .map((x) => x.id == n.id
              ? NotificationItem(
                  id: x.id,
                  title: x.title,
                  message: x.message,
                  timestamp: x.timestamp,
                  read: true,
                )
              : x)
          .toList();
    });

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      // FIX: /api prefix əlavə olundu
      final url = _u('/api/notifications/${n.id}/read');
      debugPrint('PUT => $url');

      final res = await http.put(url, headers: _headers(token));

      if (res.statusCode == 200 || res.statusCode == 204) return;

      // rollback
      setState(() {
        _items = _items
            .map((x) => x.id == n.id
                ? NotificationItem(
                    id: x.id,
                    title: x.title,
                    message: x.message,
                    timestamp: x.timestamp,
                    read: false,
                  )
                : x)
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark as read (${res.statusCode}).')),
      );
    } catch (e) {
      // rollback
      setState(() {
        _items = _items
            .map((x) => x.id == n.id
                ? NotificationItem(
                    id: x.id,
                    title: x.title,
                    message: x.message,
                    timestamp: x.timestamp,
                    read: false,
                  )
                : x)
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking as read: $e')),
      );
    }
  }

  String _formatTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = months[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd $mm $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((e) => !e.read).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirişlər${unreadCount > 0 ? ' ($unreadCount)' : ''}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _loading
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.green.shade600),
                        const SizedBox(height: 16),
                        Text(
                          'Bildirişlər yüklənir...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : (_error != null)
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red.shade400,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _loadNotifications,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Yenidən cəhd edin'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : (_items.isEmpty)
                    ? ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.notifications_none,
                                      size: 64,
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Bildiriş yoxdur',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Hələ bildirişiniz yoxdur',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final n = _items[index];

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              await _markAsRead(n);

                              if (!mounted) return;
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.notifications,
                                          size: 20,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    n.message,
                                    style: const TextStyle(fontSize: 16, height: 1.5),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Bağla'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: n.read ? Colors.white : Colors.green.shade50,
                                border: Border.all(
                                  color: n.read
                                      ? Colors.grey.shade200
                                      : Colors.green.shade300,
                                  width: n.read ? 1 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: n.read
                                          ? Colors.grey.shade300
                                          : Colors.green,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (n.read ? Colors.grey.shade300 : Colors.green)
                                              .withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n.title,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: n.read
                                                      ? FontWeight.w600
                                                      : FontWeight.w800,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _formatTime(n.timestamp.toLocal()),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          n.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                            height: 1.4,
                                          ),
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
    );
  }
}
