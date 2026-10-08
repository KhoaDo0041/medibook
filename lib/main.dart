import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'core/supabase_config.dart';
import 'features/auth/cong_vao_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kết nối Supabase một lần duy nhất khi mở app
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const MediBookApp());
}

class MediBookApp extends StatelessWidget {
  const MediBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const CongVaoApp(),
    );
  }
}
