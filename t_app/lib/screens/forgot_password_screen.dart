import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation.dart';
import '../core/form_validators.dart';
import '../repositories/auth_repository.dart';


class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<AuthRepository>();
      final resp = await repository.sendPasswordResetEmail(_emailController.text.trim());

      // Backend returns { "message": "..." } on success
      if (resp['message'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp['message'] as String)),
        );

        // Navigate to Reset screen with email
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(email: _emailController.text.trim()),
          ),
        );
      } else {
        setState(() {
          _errorMessage = (resp['message'] as String?) ?? 'Sıfırlama kodunu göndərmək mümkün olmadı.';
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
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifrəni bərpa et')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Sıfırlama kodunu almaq üçün e-poçt ünvanınızı daxil edin.',
              style: TextStyle(fontSize: 16),
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
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-poçt',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: FormValidators.email,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isLoading ? null : _sendResetEmail,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Sıfırlama kodunu göndər'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
