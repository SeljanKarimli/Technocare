import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/form_validators.dart';
import '../repositories/auth_repository.dart';
import 'login_screen.dart';

class VerificationPage extends StatefulWidget {
  final String? email;

  const VerificationPage({super.key, this.email});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late final TextEditingController _codeController;
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _canResend = true;
  String? _errorMessage;

  bool get _hasFixedEmail => widget.email?.isNotEmpty == true;
  String get _email => (_hasFixedEmail ? widget.email! : _emailController.text)
      .trim()
      .toLowerCase();

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _emailController = TextEditingController(text: widget.email);
  }

  Future<void> _verifyCode() async {
    final emailError = FormValidators.email(_email);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }
    if (_codeController.text.trim().length != 6) {
      setState(() => _errorMessage = '6 rəqəmli doğrulama kodunu daxil edin.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await context.read<AuthRepository>().verifyEmailCode(
        _email,
        _codeController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-poçt təsdiqləndi. İndi daxil ola bilərsiniz.'),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Gözlənilməz xəta baş verdi.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    final emailError = FormValidators.email(_email);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }
    setState(() {
      _isLoading = true;
      _canResend = false;
      _errorMessage = null;
    });
    try {
      await context.read<AuthRepository>().resendVerificationCode(_email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeni doğrulama kodu e-poçta göndərildi.'),
        ),
      );
      Future<void>.delayed(const Duration(seconds: 30), () {
        if (mounted) setState(() => _canResend = true);
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Kodu göndərmək mümkün olmadı.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('E-poçtu təsdiqlə')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFEAF7E5),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 44,
              color: Color(0xFF2F7623),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _hasFixedEmail
                ? '6 rəqəmli kod ${widget.email} ünvanına göndərildi.'
                : 'E-poçt ünvanınızı və 6 rəqəmli kodu daxil edin.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_hasFixedEmail) ...[
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-poçt',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Doğrulama kodu',
              prefixIcon: Icon(Icons.verified_outlined),
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _verifyCode,
              child: _isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Təsdiqlə'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading || !_canResend ? null : _resendCode,
            child: Text(
              _canResend
                  ? 'Yeni kod göndər'
                  : 'Yeni kod üçün 30 saniyə gözləyin',
            ),
          ),
        ],
      ),
    ),
  );
}
