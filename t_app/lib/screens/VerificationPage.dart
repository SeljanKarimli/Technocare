import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../core/form_validators.dart';
import 'LoginScreen.dart';

class VerificationPage extends StatefulWidget {
  final String? email; // Make the email optional
  const VerificationPage({Key? key, this.email}) : super(key: key);

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late final TextEditingController _codeController;
  late final TextEditingController _emailController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isNewRegistration = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _emailController = TextEditingController();
    
    // Check if an email was passed during navigation from registration
    _isNewRegistration = widget.email != null;
    if (_isNewRegistration) {
      _emailController.text = widget.email!;
    }
  }

  Future<void> _verifyCode() async {
    final email = _isNewRegistration
        ? widget.email
        : _emailController.text;
    final emailError = FormValidators.email(email);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Doğrulama kodunu daxil edin.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String emailToVerify = email!.trim().toLowerCase();

    try {
      final repository = context.read<AuthRepository>();
      final response = await repository.verifyEmailCode(emailToVerify, _codeController.text);

      if (response['message'] != null) {
        // Verification successful
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-poçt təsdiqləndi. İndi daxil ola bilərsiniz.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Kod düzgün deyil.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('Exception') 
          ? e.toString().substring(11) // Extract the message from the exception
          : 'Gözlənilməz xəta baş verdi.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose(); // Dispose of the new controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-poçtu təsdiqlə')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isNewRegistration)
              Text('Doğrulama kodu ${widget.email} ünvanına göndərildi.')
            else
              const Text('E-poçt ünvanınızı və doğrulama kodunu daxil edin.'),
            const SizedBox(height: 24),
            // Conditionally show the email text field
            if (!_isNewRegistration)
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-poçt',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            if (!_isNewRegistration) const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Doğrulama kodu',
                prefixIcon: Icon(Icons.verified),
              ),
              keyboardType: TextInputType.number,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verifyCode,
                    child: const Text('Təsdiqlə'),
                  ),
          ],
        ),
      ),
    );
  }
}
