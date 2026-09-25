import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/reset_password_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vvqmhbynwhllzvonsgzz.supabase.co',
    publishableKey:
        'sb_publishable_8hO469_QiCAWu6uZv2bcVA_p25SbWYT',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  debugPrint('========================================');
  debugPrint('SUPABASE INITIALIZED');
  debugPrint(
    'CURRENT SESSION: '
    '${Supabase.instance.client.auth.currentSession}',
  );
  debugPrint('========================================');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSubscription;

  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  bool _resetScreenOpened = false;

  @override
  void initState() {
    super.initState();

    debugPrint('========================================');
    debugPrint('APP INIT');
    debugPrint('SETTING UP AUTH LISTENER');
    debugPrint('========================================');

    _listenForAuthChanges();
  }

  void _listenForAuthChanges() {
    final supabase = Supabase.instance.client;

    _authSubscription =
        supabase.auth.onAuthStateChange.listen(
      (AuthState data) {
        debugPrint('========================================');
        debugPrint('SUPABASE AUTH EVENT');
        debugPrint('EVENT: ${data.event}');
        debugPrint(
          'SESSION EXISTS: ${data.session != null}',
        );
        debugPrint(
          'USER: ${data.session?.user.email}',
        );
        debugPrint('========================================');

        if (data.event ==
            AuthChangeEvent.passwordRecovery) {
          debugPrint(
            '******** PASSWORD RECOVERY DETECTED ********',
          );

          _openResetPasswordScreen();
        }
      },
      onError: (error, stackTrace) {
        debugPrint('========================================');
        debugPrint('SUPABASE AUTH LISTENER ERROR');
        debugPrint('ERROR: $error');
        debugPrint('STACK: $stackTrace');
        debugPrint('========================================');
      },
    );
  }

  void _openResetPasswordScreen() {
    if (_resetScreenOpened) {
      debugPrint(
        'RESET PASSWORD SCREEN ALREADY OPEN',
      );
      return;
    }

    _resetScreenOpened = true;

    debugPrint(
      'OPENING RESET PASSWORD SCREEN...',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _resetScreenOpened = false;
        return;
      }

      final navigator = _navigatorKey.currentState;

      if (navigator == null) {
        debugPrint(
          'ERROR: NAVIGATOR IS NULL',
        );

        _resetScreenOpened = false;
        return;
      }

      navigator
          .push(
        MaterialPageRoute(
          builder: (_) =>
              const ResetPasswordScreen(),
        ),
      )
          .then((_) {
        debugPrint(
          'RESET PASSWORD SCREEN CLOSED',
        );

        _resetScreenOpened = false;
      });
    });
  }

  @override
  void dispose() {
    debugPrint('APP DISPOSE');

    _authSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const LogInScreen(),
    );
  }
}