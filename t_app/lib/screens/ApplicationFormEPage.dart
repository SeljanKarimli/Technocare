import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding
import 'package:provider/provider.dart'; // For state management
import 'package:shared_preferences/shared_preferences.dart'; // For storing JWT token
import 'dart:io'; // Import for HttpClient

import '../navigation.dart';

// New Application Form Page
class ApplicationFormEPage extends StatefulWidget {
  final String initialSelectedField;

  const ApplicationFormEPage({super.key, this.initialSelectedField = ''});

  @override
  State<ApplicationFormEPage> createState() => _ApplicationFormEPageState();
}

class _ApplicationFormEPageState extends State<ApplicationFormEPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedField;
  String? _selectedSubService; // Added state for the sub-service dropdown
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  // Updated to a Map to link services with their sub-services
  final List<String> _applicationFields = [
    'Avtomatika Mühəndisliyi',
    'Elektronika Mühəndisliyi',
    'Elektrik Mühəndisliyi',
  ];
  
  @override
  void initState() {
    super.initState();
    // Initialize selected field from widget property
    _selectedField = widget.initialSelectedField.isNotEmpty ? widget.initialSelectedField : null;

    // Get authProvider to pre-fill user info
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = authProvider.userName ?? '';
    _mobileController.text = authProvider.userPhone ?? '';
    _emailController.text = authProvider.userEmail ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      final applicationData = {
        'Name': _nameController.text,
        'Email': _emailController.text,
        'Phone': _mobileController.text,
        'AppliedFor': _selectedField,
        'Message': _messageController.text,
      };

      // Print the data to the console for debugging purposes
      print('Submitting form with data: $applicationData');

      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwtToken');
        if (token == null) {
          throw Exception('Token not found. User not authenticated.');
        }

        final response = await http.post(
          Uri.parse('http://technocareapi.runasp.net/api/EducationApplications'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(applicationData),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Müraciətiniz uğurla göndərildi!')),
          );
          Navigator.pop(context);
        } else {
          String errorMessage = 'Bilinməyən xəta baş verdi.';
          if (response.body.isNotEmpty) {
            try {
              final errorData = json.decode(response.body);
              if (errorData is Map<String, dynamic>) {
                final errorTitle = errorData['title'] ?? 'Bilinməyən xəta';
                final errors = (errorData['errors'] as Map<String, dynamic>?)
                    ?.values
                    .expand((list) => list)
                    .join('\n');
                errorMessage = '$errorTitle\n${errors ?? ''}';
              } else {
                errorMessage = response.body;
              }
            } catch (_) {
              errorMessage = response.body;
            }
          }
          throw Exception(errorMessage);
        }
      } catch (e) {
        String errorMessage;
        if (e is http.ClientException) {
          errorMessage = 'Şəbəkə xətası baş verdi. Zəhmət olmasa internet bağlantınızı yoxlayın.';
        } else {
          errorMessage = 'Müraciət göndərildi';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müraciət Forması', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kurs üçün müraciət edin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Adınız Soyadınız',
                  hintText: 'Adınızı və soyadınızı daxil edin',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zəhmət olmasa adınızı və soyadınızı daxil edin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobil nömrəniz',
                  hintText: 'Mobil nömrənizi daxil edin',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zəhmət olmasa mobil nömrənizi daxil edin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email ünvanınız',
                  hintText: 'Email ünvanınızı dəxil edin',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zəhmət olmasa email ünvanınızı daxil edin';
                  }
                  if (!value.contains('@')) {
                    return 'Keçərli bir email ünvanı daxil edin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Main Service Dropdown
              DropdownButtonFormField<String>(
                value: _selectedField,
                decoration: const InputDecoration(
                  labelText: 'Müraciət etdiyiniz təhsil sahəsi',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _applicationFields.map((String field) {
                  return DropdownMenuItem<String>(
                    value: field,
                    child: Text(field),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedField = newValue;
                    _selectedSubService = null; // Reset sub-service when main service changes
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zəhmət olmasa bir sahə seçin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Qısa məlumat (əlavə qeydlər)',
                  hintText: 'Müraciətiniz haqqında əlavə məlumat daxil edin',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_outlined),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Müraciəti göndər'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
