import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vvqmhbynwhllzvonsgzz.supabase.co',
    publishableKey: 'sb_publishable_8hO469_QiCAWu6uZv2bcVA_p25SbWYT',
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LogInScreen(),
    );
  }
}