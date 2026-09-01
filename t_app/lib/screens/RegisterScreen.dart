import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/form_validators.dart';
import '../providers/auth_provider.dart';
import 'LoginScreen.dart';
import 'VerificationPage.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _agreed = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _openPolicy(String path) async {
    final uri = Uri.parse('https://technocare.az/$path');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showError('Səhifəni açmaq mümkün olmadı.');
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      _showError('Məxfilik siyasəti və istifadə qaydaları ilə razılaşın.');
      return;
    }
    final email = _emailController.text.trim().toLowerCase();
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _nameController.text.trim(),
      email,
      _passwordController.text,
      _phoneController.text.trim(),
    );
    if (!mounted) return;
    if (!success) {
      _showError(auth.errorMessage ?? 'Qeydiyyatı tamamlamaq mümkün olmadı.');
      auth.clearErrorMessage();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Qeydiyyat tamamlandı. E-poçtunuza göndərilən kodu daxil edin.',
        ),
      ),
    );
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => VerificationPage(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Qeydiyyat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const CircleAvatar(
                radius: 48,
                backgroundColor: Color(0xFFEAF7E5),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 48,
                  color: Color(0xFF2F7623),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Hesab yaradın',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Ad və soyad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: FormValidators.name,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'E-poçt',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: FormValidators.email,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                maxLength: 64,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Şifrə',
                  helperText: 'Ən azı 10 simvol',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _isPasswordVisible
                        ? 'Şifrəni gizlət'
                        : 'Şifrəni göstər',
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: FormValidators.password,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                maxLength: 24,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobil nömrə',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: FormValidators.phone,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agreed,
                onChanged: (value) => setState(() => _agreed = value ?? false),
                title: const Text(
                  'Məxfilik siyasəti və istifadə qaydaları ilə razıyam.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _openPolicy('mexfilik-siyaseti'),
                    child: const Text('Məxfilik siyasəti'),
                  ),
                  TextButton(
                    onPressed: () => _openPolicy('istifade-qaydalari'),
                    child: const Text('İstifadə qaydaları'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _register,
                  child: auth.isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Qeydiyyatdan keç'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Hesabınız var? Daxil olun'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
