import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/admin_main_screen.dart';
import 'package:flutter_application_1/screens/employee_main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_screen.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _handleLogin() async {
    if (_isLoading) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool shouldResetLoading = true;

    try {
      final supabase = Supabase.instance.client;

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw Exception('Login failed.');
      }

      debugPrint('================ LOGIN DEBUG ================');
      debugPrint('LOGGED IN USER ID: ${user.id}');
      debugPrint('LOGGED IN EMAIL: ${user.email}');

      // ========================================================
      // CHECK ADMIN FIRST
      // ========================================================

      final admin = await supabase
          .from('company_admins')
          .select('id, company_id, auth_user_id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      debugPrint('ADMIN RESULT: $admin');

      if (admin != null) {
        debugPrint('USER TYPE: ADMIN');

        shouldResetLoading = false;

        if (!mounted) {
          return;
        }

        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const AdminMainScreen(),
          ),
        );

        return;
      }

      // ========================================================
      // CHECK EMPLOYEE
      // ========================================================

      final employee = await supabase
          .from('employees')
          .select(
            'id, company_id, employee_code, full_name, auth_user_id',
          )
          .eq('auth_user_id', user.id)
          .maybeSingle();

      debugPrint('EMPLOYEE RESULT: $employee');

      if (employee != null) {
        debugPrint('USER TYPE: EMPLOYEE');

        shouldResetLoading = false;

        if (!mounted) {
          return;
        }

        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const EmployeeMainScreen(),
          ),
        );

        return;
      }

      // ========================================================
      // NO PROFILE FOUND
      // ========================================================

      debugPrint('USER TYPE: UNKNOWN');

      await supabase.auth.signOut();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account is not connected to an employee or admin profile.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AuthException catch (e) {
      debugPrint('AUTH ERROR: ${e.message}');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: $e',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // IMPORTANT:
      // Do not call setState after navigation has replaced this screen.
      if (shouldResetLoading && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _showForgotPasswordDialog() async {
    final initialEmail = _emailController.text.trim();

    final shouldSend = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _ForgotPasswordDialog(
          initialEmail: initialEmail,
        );
      },
    );

    if (shouldSend == null || shouldSend.trim().isEmpty) {
      return;
    }

    final email = shouldSend.trim();

    if (!mounted) {
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo:
            'https://bhattdhruva.github.io/flutter_application_1/',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset link sent to $email',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('PASSWORD RESET ERROR: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send password reset email: $e',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0066FF);
    const textColor = Color(0xFF0F172A);
    const iconColor = Color(0xFF64748B);
    const hintColor = Color(0xFF94A3B8);
    const borderLineColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // IMAGE
                    // ==================================================

                    Center(
                      child: SizedBox(
                        height: 220,
                        child: Image.asset(
                          'assets/illustration/signin.jpg',
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_outlined,
                              size: 80,
                              color: borderLineColor,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // TITLE
                    // ==================================================

                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // FORM
                    // ==================================================

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          // ==================================================
                          // EMAIL
                          // ==================================================

                          TextFormField(
                            controller: _emailController,
                            keyboardType:
                                TextInputType.emailAddress,
                            textInputAction:
                                TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            enabled: !_isLoading,
                            style: const TextStyle(
                              fontSize: 15,
                              color: textColor,
                            ),
                            decoration:
                                const InputDecoration(
                              hintText: 'Email ID',
                              hintStyle: TextStyle(
                                color: hintColor,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.alternate_email,
                                color: iconColor,
                                size: 20,
                              ),
                              prefixIconConstraints:
                                  BoxConstraints(
                                minWidth: 36,
                              ),
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              enabledBorder:
                                  UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: borderLineColor,
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder:
                                  UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder:
                                  UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.red,
                                  width: 1.2,
                                ),
                              ),
                              focusedErrorBorder:
                                  UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.red,
                                  width: 1.5,
                                ),
                              ),
                            ),
                         validator: (value) {
  final email =
      value?.trim() ?? '';

  if (email.isEmpty) {
    return 'Please enter your email';
  }

  if (!RegExp(
    r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$',
  ).hasMatch(email)) {
    return 'Please enter a valid email';
  }

  return null;
},
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // PASSWORD
                          // ==================================================

                          TextFormField(
                            controller: _passwordController,
                            obscureText:
                                !_isPasswordVisible,
                            textInputAction:
                                TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.password,
                            ],
                            enabled: !_isLoading,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) {
                                _handleLogin();
                              }
                            },
                            style: const TextStyle(
                              fontSize: 15,
                              color: textColor,
                            ),
                            decoration:
                                InputDecoration(
                              hintText: 'Password',
                              hintStyle:
                                  const TextStyle(
                                color: hintColor,
                                fontSize: 14,
                              ),
                              prefixIcon:
                                  const Icon(
                                Icons
                                    .lock_outline_rounded,
                                color: iconColor,
                                size: 20,
                              ),
                              prefixIconConstraints:
                                  const BoxConstraints(
                                minWidth: 36,
                              ),
                              suffixIcon:
                                  Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip:
                                        _isPasswordVisible
                                            ? 'Hide password'
                                            : 'Show password',
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons
                                              .visibility_outlined
                                          : Icons
                                              .visibility_off_outlined,
                                      color:
                                          iconColor,
                                      size: 18,
                                    ),
                                    onPressed:
                                        _isLoading
                                            ? null
                                            : () {
                                                if (!mounted) {
                                                  return;
                                                }

                                                setState(() {
                                                  _isPasswordVisible =
                                                      !_isPasswordVisible;
                                                });
                                              },
                                  ),
                                  GestureDetector(
                                    onTap:
                                        _isLoading
                                            ? null
                                            : _showForgotPasswordDialog,
                                    child:
                                        const Padding(
                                      padding:
                                          EdgeInsets.only(
                                        right: 12,
                                        left: 2,
                                      ),
                                      child: Text(
                                        'Forgot?',
                                        style:
                                            TextStyle(
                                          color:
                                              primaryColor,
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets
                                      .symmetric(
                                vertical: 14,
                              ),
                              enabledBorder:
                                  const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(
                                  color:
                                      borderLineColor,
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder:
                                  const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(
                                  color:
                                      primaryColor,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder:
                                  const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(
                                  color: Colors.red,
                                  width: 1.2,
                                ),
                              ),
                              focusedErrorBorder:
                                  const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(
                                  color: Colors.red,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'Please enter your password';
                              }

                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 32),

                          // ==================================================
                          // LOGIN BUTTON
                          // ==================================================

                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              key: const Key(
                                'login_button',
                              ),
                              onPressed:
                                  _isLoading
                                      ? null
                                      : _handleLogin,
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    primaryColor,
                                foregroundColor:
                                    Colors.white,
                                disabledBackgroundColor:
                                    primaryColor
                                        .withOpacity(0.55),
                                disabledForegroundColor:
                                    Colors.white,
                                elevation: 0,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    14,
                                  ),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style:
                                          TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==================================================
                    // REGISTER
                    // ==================================================

                    Center(
                      child: Wrap(
                        alignment:
                            WrapAlignment.center,
                        crossAxisAlignment:
                            WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'New to iThickLogistics? ',
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 15,
                            ),
                          ),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SignUpScreen(),
                                      ),
                                    );
                                  },
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================================================================
// FORGOT PASSWORD DIALOG
//
// Separate StatefulWidget.
// Owns its controller.
// Controller is disposed only when this dialog itself is destroyed.
// ==================================================================

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({
    required this.initialEmail,
  });

  @override
  State<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState
    extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(
      text: widget.initialEmail,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.lock_reset,
            color: Color(0xFF0066FF),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text('Reset Password'),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your registered email address to receive password reset instructions.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType:
                    TextInputType.emailAddress,
                textInputAction:
                    TextInputAction.done,
                autofocus: true,
                onFieldSubmitted: (_) => _submit(),
                decoration:
                    const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email =
                      value?.trim() ?? '';

                  if (email.isEmpty) {
                    return 'Please enter your email';
                  }

                  if (!RegExp(
                    r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$',
                  ).hasMatch(email)) {
                    return 'Please enter a valid email';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                const Color(0xFF0066FF),
            foregroundColor: Colors.white,
          ),
          child: const Text('Send Link'),
        ),
      ],
    );
  }
}