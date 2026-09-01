import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // For state management

import '../core/api_client.dart';
import '../core/form_validators.dart';
import '../providers/auth_provider.dart';

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

      try {
        await context.read<ApiClient>().post(
              'EducationApplications',
              body: applicationData,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Müraciətiniz uğurla göndərildi!')),
        );
        Navigator.pop(context);
      } on ApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Müraciəti göndərmək mümkün olmadı.')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Adınız Soyadınız',
                  hintText: 'Adınızı və soyadınızı daxil edin',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: FormValidators.name,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                maxLength: 24,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobil nömrəniz',
                  hintText: 'Mobil nömrənizi daxil edin',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: FormValidators.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email ünvanınız',
                  hintText: 'Email ünvanınızı dəxil edin',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: FormValidators.email,
              ),
              const SizedBox(height: 16),
              // Main Service Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedField,
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
                maxLength: 2000,
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
                child: FilledButton(
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
