/// Supabase configuration via compile-time environment variables or defaults.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xrumgoeuzufxidxwwusm.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhydW1nb2V1enVmeGlkeHd3dXNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwMDU2MzMsImV4cCI6MjEwMDU4MTYzM30.0KoZ7wRiGxKs2XDenMfnVnR-rMoDDheFXuTClOHYYlc',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
