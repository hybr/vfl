import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SupabaseConfig {
  static const String supabaseUrl = 'https://clitxbssfloylyiuhekv.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsaXR4YnNzZmxveWx5aXVoZWt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxMTAxNjksImV4cCI6MjA3MzY4NjE2OX0.TYlmmNe46t4YXjzAFb4axCBr7VFx1AIg6Rlq1zsJU3c';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: !kIsWeb, // Disable debug mode for web to avoid developer extension issues
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseQueryBuilder from(String table) => client.from(table);
}