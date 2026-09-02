import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/form_validators.dart';

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<bool> _submitForm() async {
    if (!_formKey.currentState!.validate()) return false;

    setState(() => _isLoading = true);

    try {
      final applicationData = {
        'Name': _nameController.text.trim(),
        'Email': _emailController.text.trim(),
        'Phone': _mobileController.text.trim(),
        'AppliedFor': _selectedField,
        'AppliedSubService': _selectedSubService,
        'Message': _messageController.text.trim(),
      };

      await context.read<ApiClient>().post(
        'ServiceApplications',
        body: applicationData,
      );
      _showSnack(
        'Müraciət qəbul edildi və info@technocare.az ünvanına yönləndirildi.',
      );
      return true;
    } on ApiException catch (error) {
      _showSnack(error.message);
      return false;
    } catch (_) {
      _showSnack('Müraciəti göndərmək mümkün olmadı.');
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
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Adınız Soyadınız',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: FormValidators.name,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                maxLength: 24,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobil nömrə',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: FormValidators.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                maxLength: 254,
                validator: FormValidators.email,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedField,
                decoration: const InputDecoration(
                  labelText: 'Sahə',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _applicationFields.keys
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) => setState(() {
                  _selectedField = val;
                  _selectedSubService = null;
                }),
                validator: (v) => v == null ? 'Seçim edin' : null,
              ),
              const SizedBox(height: 12),
              if (_selectedField != null)
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedField),
                  isExpanded: true, // Prevents overflow
                  initialValue: _selectedSubService,
                  decoration: const InputDecoration(
                    labelText: 'Alt xidmət',
                    prefixIcon: Icon(Icons.list),
                  ),
                  items: _applicationFields[_selectedField]!
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSubService = val),
                  validator: (v) => v == null ? 'Seçim edin' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Məlumat',
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (await _submitForm()) {
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Göndər'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
