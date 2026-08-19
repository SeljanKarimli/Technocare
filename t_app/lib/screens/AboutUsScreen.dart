import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  Future<void> _launchPhone(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    await launchUrl(url);
  }

  Future<void> _launchEmail(String email) async {
    final Uri url = Uri(scheme: 'mailto', path: email);
    await launchUrl(url);
  }

  Future<void> _launchMap() async {
    final Uri url = Uri.parse(
        'https://www.google.com/maps/place/TECHNOCARE+MMC/data=!4m2!3m1!1s0x0:0xd6fc45c07a7ea798?sa=X&ved=1t:2428&ictx=111');
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haqqımızda', style: TextStyle(color: Colors.black)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/technocare.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.business, size: 80, color: Colors.green.shade700);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Technocare MMC haqqında',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Technocare MMC olaraq, sənaye avtomatlaşdırılması, elektronika və energetika sahələrində qabaqcıl həllər təqdim edən aparıcı şirkətik. Biz Schneider Electric, WAGO, SICK, Siemens, Weidmüller kimi dünya brendlərinin məhsulları üzrə Azərbaycanda satış və servis xidmətləri təqdim edirik.',
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Missiyamız:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Text(
                'Müasir texnologiyaları tətbiq edərək sənaye proseslərinin səmərəliliyini artırmaq, müştərilərimizə yüksək keyfiyyətli məhsul və xidmətlər təqdim etməkdir.',
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Bizimlə əlaqə saxlayın:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildContactTile(
              Icons.location_on_outlined,
              'Ünvan',
              'Bakı, Azərbaycan',
              _launchMap,
            ),
            const SizedBox(height: 12),
            _buildContactTile(
              Icons.phone_outlined,
              'Telefon',
              '+994 10 230 70 97',
              () => _launchPhone('+994102307097'),
            ),
            const SizedBox(height: 12),
            _buildContactTile(
              Icons.email_outlined,
              'Email',
              'info@technocare.az',
              () => _launchEmail('info@technocare.az'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
