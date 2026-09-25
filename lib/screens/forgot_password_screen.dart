import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  bool _loading = false;
  bool _emailSent = false;

  Future<void> _sendResetEmail() async {
  final email = _emailController.text.trim();

  if (email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enter your email address'),
      ),
    );
    return;
  }

  setState(() {
    _loading = true;
  });

  try {
    await Supabase.instance.client.auth.resetPasswordForEmail(
  email,
  redirectTo:
      'com.example.flutter_application_1://reset-password',
);
    if (!mounted) return;

    setState(() {
      _emailSent = true;
    });
  } on AuthException catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    if (_emailSent) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Check your email'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'We sent you a password reset link. '
              'Open the email and tap Reset Password.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _loading ? null : _sendResetEmail,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Send reset link'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}