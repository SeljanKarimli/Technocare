import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding
import 'package:provider/provider.dart'; // For state management
import 'package:shared_preferences/shared_preferences.dart'; // For storing JWT token
import 'dart:io'; // Import for HttpClient

import '../navigation.dart'; 

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  // Helper method to build a category section
  Widget _buildCategorySection(
      BuildContext context, String title, IconData icon, List<String> services, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell( // Wrap with InkWell for onTap
        onTap: onTap, // Apply the onTap callback
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 40, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: services.map((service) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            service,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xidmətlər', style: TextStyle(color: Colors.black)),
        automaticallyImplyLeading: false, // Hide back button for bottom nav tab
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24.0),
            _buildCategorySection(
              context,
              'Avtomatika',
              Icons.auto_mode_outlined,
              [
                'Sənaye proseslərinin avtomatlaşdırılması üzrə peşəkar həllər',
                'Avtomatlaşdırma Sistemlərinin Layihələndirilməsi',
                'Mövcud avtomatika sistemlərinin Modernizasiyası',
                'SCADA və HMI sistemlərinin hazırlanması',
              ],
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ApplicationFormSPage(initialSelectedField: 'Avtomatika Xidməti')),
                );
              },
            ),
            const SizedBox(height: 24.0),
            _buildCategorySection(
              context,
              'Elektronika Xidmətlərimiz',
              Icons.electrical_services_outlined,
              [
                'Elektronika Təmiri və Xidmətləri',
                'Dövrə dizaynı və inteqrasiyası',
                'Mikroelektronika həlləri',
              ],
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ApplicationFormSPage(initialSelectedField: 'Elektronika Xidməti')),
                );
              },
            ),
            const SizedBox(height: 24.0),
            _buildCategorySection(
              context,
              'Energetika Xidmətlərimiz',
              Icons.bolt_outlined,
              [
                'Enerji səmərəliliyi həlləri',
                'Bərpa Olunan Enerji Sistemləri',
                'Elektrik paylama şəbəkələrinin optimallaşdırılması',
              ],
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ApplicationFormSPage(initialSelectedField: 'Energetika Xidməti')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
