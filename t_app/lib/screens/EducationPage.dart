import 'package:flutter/material.dart';

import '../navigation.dart';

class EducationPage extends StatelessWidget {
  const EducationPage({super.key});

  // Helper method to build an education field section (similar to CategoriesPage)
  Widget _buildEducationFieldSection(
      BuildContext context, String title, IconData icon, List<String> services, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell(
        onTap: onTap,
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
        title: const Text('Tədris Kurslarımız', style: TextStyle(color: Colors.black)),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24.0),
            _buildEducationFieldSection(
              context,
              'Avtomatika mühəndisliyi',
              Icons.precision_manufacturing,
              [
                'Sənaye avtomatlaşdırması sistemləri',
                'PLC və SCADA proqramlaşdırma',
                'Sensor və aktuator sistemləri',
                'Proses avtomatlaşdırması həlləri',
              ],
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AutomationEngineeringCoursePage()),
                );
              },
            ),
            const SizedBox(height: 24.0),
            _buildEducationFieldSection(
              context,
              'Elektronika mühəndisliyi',
              Icons.memory,
              [
                'Mikrokontroller proqramlaşdırma',
                'Dövrə dizaynı və analizi',
                'Sensor texnologiyaları',
                'İnteqral sxemlər və PCB dizayn',
              ],
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ElectronicsEngineeringCoursePage()),
                );
              },
            ),
            const SizedBox(height: 24.0),
            _buildEducationFieldSection(
              context,
              'Elektrik mühəndisliyi',
              Icons.electrical_services,
              [
                'Elektrik dövrələri və sistemlər',
                'Enerji paylama şəbəkələri',
                'Transformator və generator sistemləri',
                'Ağıllı enerji həlləri',
              ],
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ElectricalEngineeringCoursePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Detail page for Automation Engineering Course
class AutomationEngineeringCoursePage extends StatelessWidget {
  const AutomationEngineeringCoursePage({super.key});

  Widget _buildAdvantagePoint(String text, String subText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (subText.isNotEmpty)
                  Text(
                    subText,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avtomatika Mühəndisliyi Kursu', style: TextStyle(color: Colors.black)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.precision_manufacturing,
                size: 60,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Avtomatika mühəndisliyi:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Avtomatika mühəndisliyi, texnoloji sistemlərin insan müdaxiləsi olmadan işləsmesini təmin edən bir mühəndislik sahəsidir. Bu sahə proseslərin, avadanlıqların və sistemlərin avtomatik idarə olunmasını nəzərdə tutur. Avtomatika mühəndisləri, sensorlar, aktuatorlar, mikroprosessorlar, PLC sistemləri və proqramlaşdırma vasitəsilə cihazların səmərəli və təhlükəsiz şəkildə işləməsinə nail olurlar.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Kursun əsas üstünlükləri:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12.0),
            _buildAdvantagePoint('Praktiki yönümlü təhsil', 'Ən son avadanlıqlarla real layihələr üzərində işləmə imkanı.'),
            _buildAdvantagePoint('Mütəxəssis təlimçilər', 'Sahənin aparıcı mütəxəssislərindən dərs almaq şansı.'),
            _buildAdvantagePoint('Karyera imkanları', 'Məzunlarımızı yerli və beynəlxalq şirkətlərdə işlə təmin etməyə köməklik.'),
            _buildAdvantagePoint('Sertifikatlaşdırma', 'Kursu bitirdikdən sonra beynəlxalq səviyyəli sertifikat.'),
            const SizedBox(height: 24.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ApplicationFormEPage(initialSelectedField: 'Avtomatika Mühəndisliyi')),
                  );
                },
                child: const Text('Müraciət et'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Detail page for Electronics Engineering Course
class ElectronicsEngineeringCoursePage extends StatelessWidget {
  const ElectronicsEngineeringCoursePage({super.key});

  Widget _buildAdvantagePoint(String text, String subText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (subText.isNotEmpty)
                  Text(
                    subText,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elektronika Mühəndisliyi Kursu', style: TextStyle(color: Colors.black)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.memory,
                size: 60,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Elektronika Mühəndisliyi Kursu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Elektronika mühəndisliyi — ağıllı cihazlardan tutmuş süni intellekt sistemlərinə qədər texnologiyanın əsasını təşkil edən sahədir. Bu kurs elektronikanın əsaslarını öyrətməklə yanaşı, mikrokontrollerlər, sensorlar, inteqral sxemlər və real layihələr üzərində çalışma bacarıqları qazandırır. Kurs 6 ay davam edir, həftədə 2 dəfə nəzəri və praktiki dərslərlə həyata keçirilir.',
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Kurs kimlər üçündür?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12.0),
            _buildAdvantagePoint('Texnologiyaya marağı olan tələbələr və məzunlar', ''),
            _buildAdvantagePoint('Karyeralarını elektronika sahəsində qurmaq istəyənlər', ''),
            _buildAdvantagePoint('Mikrokontroller və sensorlarla işləməyi öyrənmək istəyənlər', ''),
            const SizedBox(height: 24.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ApplicationFormEPage(initialSelectedField: 'Elektronika Mühəndisliyi')),
                  );
                },
                child: const Text('Müraciət et'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Detail page for Electrical Engineering Course
class ElectricalEngineeringCoursePage extends StatelessWidget {
  const ElectricalEngineeringCoursePage({super.key});

  Widget _buildAdvantagePoint(String text, String subText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (subText.isNotEmpty)
                  Text(
                    subText,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elektrik Mühəndisliyi Kursu', style: TextStyle(color: Colors.black)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.electrical_services,
                size: 60,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Elektrik Mühəndisliyi Kursu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Elektrik mühəndisliyi — elektrik enerjisinin istehsalı, ötürülməsi və istifadəsi ilə məşğul olan mühüm mühəndislik sahəsidir. Elektrik dövrələri, transformatorlar, generatorlar və ağıllı enerji sistemləri kimi mövzuları əhatə edən bu sahə sənaye və cəmiyyət üçün əvəzolunmazdır.',
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Kursun məqsədi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12.0),
            _buildAdvantagePoint('Tələbələrə elektrik enerjisi ilə işləyən sistemlərin nəzəri və praktiki əsaslarını öyrətməkdir.', ''),
            _buildAdvantagePoint('Sənaye standartlarına uyğun bilik və bacarıqları aşılamaq.', ''),
            _buildAdvantagePoint('Müasir elektrik sistemlərinin dizaynı və analizi bacarıqlarını inkişaf etdirmək.', ''),
            const SizedBox(height: 24.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ApplicationFormEPage(initialSelectedField: 'Elektrik Mühəndisliyi')),
                  );
                },
                child: const Text('Müraciət et'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
