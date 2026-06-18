/// App configuration and environment variables.
///
/// For production store builds, pass credentials via `--dart-define`:
/// ```bash
/// flutter build appbundle --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key
/// flutter build ipa --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// ```
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bxcwlrwelomwdraclnmq.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_lXaE5yGrJbk3cAwEtnt7Sg_GJW3-dZt',
  );

  /// True if Supabase is configured (not using placeholders).
  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR_PROJECT_REF') &&
      !supabaseUrl.contains('your_project_ref') &&
      supabaseAnonKey != 'YOUR_ANON_KEY';
}
