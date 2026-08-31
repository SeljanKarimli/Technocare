import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/shop_models.dart';

class CheckoutWebViewPage extends StatefulWidget {
  final CheckoutSession session;
  const CheckoutWebViewPage({super.key, required this.session});

  @override
  State<CheckoutWebViewPage> createState() => _CheckoutWebViewPageState();
}

class _CheckoutWebViewPageState extends State<CheckoutWebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) => setState(() => _progress = progress),
        onNavigationRequest: (request) {
          if (request.url.startsWith('technocare://checkout/success')) {
            Navigator.pop(context, true);
            return NavigationDecision.prevent;
          }
          if (request.url.startsWith('technocare://checkout/cancel')) {
            Navigator.pop(context, false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) setState(() => _error = error.description);
        },
      ))
      ..loadRequest(Uri.parse(widget.session.checkoutUrl));
  }

  Future<void> _openExternally() => launchUrl(Uri.parse(widget.session.checkoutUrl), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Təhlükəsiz ödəniş'),
        actions: [IconButton(onPressed: _openExternally, tooltip: 'Brauzerdə aç', icon: const Icon(Icons.open_in_browser_rounded))],
        bottom: _progress < 100 ? PreferredSize(preferredSize: const Size.fromHeight(3), child: LinearProgressIndicator(value: _progress / 100, color: const Color(0xFF59BE3F))) : null,
      ),
      body: _error == null
          ? WebViewWidget(controller: _controller)
          : Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_reset_rounded, size: 64, color: Color(0xFF59BE3F)),
              const SizedBox(height: 16),
              const Text('Ödəniş səhifəsi açılmadı', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: _openExternally, icon: const Icon(Icons.open_in_new), label: const Text('Brauzerdə davam et')),
            ]))),
    );
  }
}
