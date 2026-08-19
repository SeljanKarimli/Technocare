import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ensure this path is correct for your project structure
import '../navigation.dart'; 

class ApplicationFormSPage extends StatefulWidget {
  final String initialSelectedField;

  const ApplicationFormSPage({super.key, this.initialSelectedField = ''});

  @override
  State<ApplicationFormSPage> createState() => _ApplicationFormSPageState();
}

class _ApplicationFormSPageState extends State<ApplicationFormSPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedField;
  String? _selectedSubService;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = false;

  final Map<String, List<String>> _applicationFields = {
    'Avtomatika Xidməti': [
      'Sənaye proseslərinin avtomatlaşdırılması üzrə peşəkar həllər',
      'Avtomatlaşdırma Sistemlərinin Layihələndirilməsi',
      'Mövcud avtomatika sistemlərinin Modernizasiyası',
      'SCADA və HMI sistemlərinin hazırlanması',
    ],
    'Elektronika Xidməti': [
      'Elektronika Təmiri və Xidmətləri',
      'Dövrə dizaynı və inteqrasiyası',
      'Mikroelektronika həlləri',
    ],
    'Energetika Xidməti': [
      'Enerji səmərəliliyi həlləri',
      'Bərpa Olunan Enerji Sistemləri',
      'Elektrik paylama şəbəkələrinin optimallaşdırılması',
    ],
  };

  @override
  void initState() {
    super.initState();

    // 1. Validate the initial field exists in our keys
    if (widget.initialSelectedField.isNotEmpty && 
        _applicationFields.containsKey(widget.initialSelectedField)) {
      _selectedField = widget.initialSelectedField;
    }

    // 2. Use addPostFrameCallback to safely access Provider in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        setState(() {
          _nameController.text = authProvider.userName ?? '';
          _mobileController.text = authProvider.userPhone ?? '';
          _emailController.text = authProvider.userEmail ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Zəhmət olmasa email daxil edin';
    final v = value.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
      return 'Keçərli bir email ünvanı daxil edin';
    }
    return null;
  }

  Future<bool> _submitForm() async {
    if (!_formKey.currentState!.validate()) return false;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwtToken');

      if (token == null || token.isEmpty) {
        _showSnack('Token tapılmadı. Yenidən login olun.');
        return false;
      }

      final applicationData = {
        'Name': _nameController.text.trim(),
        'Email': _emailController.text.trim(),
        'Phone': _mobileController.text.trim(),
        'AppliedFor': _selectedField,
        'AppliedSubService': _selectedSubService,
        'Message': _messageController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('http://technocareapi.runasp.net/api/ServiceApplications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(applicationData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('Müraciət göndərildi ✅');
        return true;
      } else {
        _showSnack('Xəta: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _showSnack('Şəbəkə xətası baş verdi');
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Müraciət Forması')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xidmət üçün müraciət edin',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Adınız Soyadınız', prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? 'Boş qoymayın' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobil nömrə', prefixIcon: Icon(Icons.phone)),
                validator: (v) => v!.isEmpty ? 'Boş qoymayın' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedField,
                decoration: const InputDecoration(labelText: 'Sahə', prefixIcon: Icon(Icons.category)),
                items: _applicationFields.keys.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (val) => setState(() { _selectedField = val; _selectedSubService = null; }),
                validator: (v) => v == null ? 'Seçim edin' : null,
              ),
              const SizedBox(height: 12),
              if (_selectedField != null)
                DropdownButtonFormField<String>(
                  isExpanded: true, // Prevents overflow
                  value: _selectedSubService,
                  decoration: const InputDecoration(labelText: 'Alt xidmət', prefixIcon: Icon(Icons.list)),
                  items: _applicationFields[_selectedField]!.map((s) => DropdownMenuItem(
                    value: s, 
                    child: Text(s, overflow: TextOverflow.ellipsis)
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedSubService = val),
                  validator: (v) => v == null ? 'Seçim edin' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Məlumat', prefixIcon: Icon(Icons.edit)),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    if (await _submitForm()) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
                    }
                  },
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Göndər'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}