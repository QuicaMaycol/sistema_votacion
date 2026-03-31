import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://mqsupabase.dashbportal.com';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzcyODM4MjkwLCJleHAiOjIwODgxOTgyOTB9.NdfHsNVkPwxgCu4K73CxkRZe2mbizFiasQQE9FElBNY';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      postgrestOptions: const PostgrestClientOptions(schema: 'votaciones'),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
