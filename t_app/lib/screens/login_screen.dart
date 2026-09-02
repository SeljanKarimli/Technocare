import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/form_validators.dart';
import '../navigation.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_flow_info_card.dart';

class LoginScreen extends StatefulWidget {
  final bool returnToPrevious;

  const LoginScreen({super.key, this.returnToPrevious = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailController.text.trim().toLowerCase(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (!success) {
      _showError(auth.errorMessage ?? 'Daxil olmaq mümkün olmadı.');
      auth.clearErrorMessage();
      return;
    }
    if (widget.returnToPrevious) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/technocare.png',
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('Daxil ol'),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFEAF7E5),
                child: Icon(
                  Icons.login_rounded,
                  size: 44,
                  color: Color(0xFF2F7623),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hesabınıza daxil olun',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Profil və şəxsi bildirişləriniz üçün daxil olun.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'E-poçt',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: FormValidators.email,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => auth.isLoading ? null : _login(),
                decoration: InputDecoration(
                  labelText: 'Şifrə',
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
                validator: (value) =>
                    value?.isNotEmpty == true ? null : 'Şifrəni daxil edin.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  ),
                  child: const Text('Şifrəni unutmusunuz?'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _login,
                  child: auth.isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Daxil ol'),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Hesabınız yoxdur?'),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Qeydiyyatdan keç'),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VerificationPage()),
                ),
                child: const Text('Təsdiq kodunu daxil et'),
              ),
              const SizedBox(height: 16),
              const AuthFlowInfoCard(),
            ],
          ),
        ),
      ),
    );
  }
}
