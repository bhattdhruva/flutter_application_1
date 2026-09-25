import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmPassword =
        _confirmPasswordController.text;

    if (password.isEmpty) {
      _showMessage('Enter a new password');
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must be at least 6 characters',
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        'Passwords do not match',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: password,
        ),
      );

      if (!mounted) return;

      _showMessage(
        'Password updated successfully',
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              const Text(
                'Create a new password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Your new password should be different '
                'from your previous password.',
              ),

              const SizedBox(height: 30),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller:
                    _confirmPasswordController,
                obscureText:
                    _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _loading ? null : _updatePassword,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Update Password',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}