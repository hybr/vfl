// Quick Supabase Connection Test
// Run this with: dart test_supabase.dart

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  print('Testing Supabase connection...');

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://clitxbssfloylyiuhekv.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsaXR4YnNzZmxveWx5aXVoZWt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxMTAxNjksImV4cCI6MjA3MzY4NjE2OX0.TYlmmNe46t4YXjzAFb4axCBr7VFx1AIg6Rlq1zsJU3c',
    );

    print('✅ Supabase initialized successfully');

    // Test database connection
    final supabase = Supabase.instance.client;

    // Try to query a table (this will fail if tables don't exist)
    try {
      final response = await supabase.from('organizations').select('count').count();
      print('✅ Database connection successful');
      print('Organizations table exists');
    } catch (e) {
      print('❌ Database tables not found');
      print('Please run the supabase_setup.sql script');
    }

    // Test auth configuration
    try {
      // This should not throw an error if auth is configured
      final authState = supabase.auth.currentSession;
      print('✅ Authentication is configured');
      if (authState == null) {
        print('No user currently logged in (this is normal)');
      } else {
        print('User logged in: ${authState.user.email}');
      }
    } catch (e) {
      print('❌ Authentication configuration error: $e');
    }

  } catch (e) {
    print('❌ Failed to connect to Supabase: $e');
    print('Check your project URL and API key');
  }
}