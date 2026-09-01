import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/whatsapp_order_service.dart';

// FIX: Define methods inside the class

// NEW: Help & Support Screen
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchPhone(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    await launchUrl(url);
  }

  Future<void> _launchEmail(String email) async {
    final Uri url = Uri(scheme: 'mailto', path: email);
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Yardım və Dəstək',
          style: TextStyle(color: Colors.black),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.support_agent,
                    color: Colors.green.shade700,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yardım mərkəzi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sualınız var? Bizimlə əlaqə saxlayın',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tez-tez Verilən Suallar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFAQItem(
              'Sifarişim nə vaxt çatdırılacaq?',
              'Sifarişlər adətən 3-5 iş günü ərzində çatdırılır. Çatdırılma statusunu "Sifarişlərim" bölməsindən izləyə bilərsiniz.',
            ),
            _buildFAQItem(
              'Məhsulu necə geri qaytara bilərəm?',
              'Məhsulu 14 gün ərzində, qablaşdırması vəziyyətində geri qaytara bilərsiniz. Daha ətraflı məlumat üçün Dəstək xidməti ilə əlaqə saxlayın.',
            ),
            _buildFAQItem(
              'Ödəniş üsulları hansılardır?',
              'Kredit/debet kartları və nağd ödəniş (çatdırılmada) qəbul olunur.',
            ),
            const SizedBox(height: 32),
            const Text(
              'Bizimlə əlaqə',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              Icons.email_outlined,
              'Email',
              'info@technocare.az',
              () => _launchEmail('info@technocare.az'),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              Icons.phone_outlined,
              'Telefon',
              '+994 10 230 70 97',
              () => _launchPhone('+994102307097'),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              Icons.chat_bubble_outline,
              'Canlı Çat',
              'İş saatlarında aktivdir',
              () async {
                final whatsappUrl = await context
                    .read<WhatsAppOrderService>()
                    .createChatUri();
                await launchUrl(
                  whatsappUrl,
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              answer,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
