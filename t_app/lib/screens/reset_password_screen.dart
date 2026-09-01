import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation.dart';
import '../core/form_validators.dart';
import '../repositories/auth_repository.dart';


class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();        // token/code from email
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscure1 = true;
  bool _obscure2 = true;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<AuthRepository>();

      final email = widget.email.trim();
      final token = _codeController.text.trim();
      final newPassword = _newPasswordController.text;

      final response = await repository.resetPassword(email, token, newPassword);

      // Backend success pattern: { "message": "..." }
      if (response['message'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifrə uğurla yeniləndi. İndi daxil ola bilərsiniz.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = (response['message'] as String?) ?? 'Şifrəni yeniləmək mümkün olmadı.';
        });
      }
    } catch (e) {
      setState(() {
        final s = e.toString();
        _errorMessage = s.startsWith('Exception:') ? s.replaceFirst('Exception: ', '') : s;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni şifrə')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Sıfırlama kodu $email ünvanına göndərildi.\nKodu və yeni şifrənizi daxil edin.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Code / Token
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Sıfırlama kodu',
                      hintText: 'E-poçta göndərilmiş kodu daxil edin',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Sıfırlama kodunu daxil edin.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // New Password
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscure1,
                    decoration: InputDecoration(
                      labelText: 'Yeni şifrə',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure1 = !_obscure1),
                      ),
                    ),
                    validator: FormValidators.password,
                  ),
                  const SizedBox(height: 12),
                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscure2,
                    decoration: InputDecoration(
                      labelText: 'Yeni şifrəni təkrarlayın',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure2 = !_obscure2),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Şifrəni təkrar daxil edin.';
                      if (val != _newPasswordController.text) return 'Şifrələr eyni deyil.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Şifrəni yenilə'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
