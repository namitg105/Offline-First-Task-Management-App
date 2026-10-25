/// Project-specific keys. The Supabase publishable key is public by design; Row
/// Level Security is what protects the data. Real values go in the gitignored
/// `app_secrets.dart` (a copy of this file).
class AppSecrets {
  const AppSecrets._();

  /// Supabase Dashboard -> Project Settings -> API -> Project URL
  static const String supabaseUrl = 'https://YOUR-PROJECT-REF.supabase.co';

  /// Supabase Dashboard -> Project Settings -> API Keys -> publishable key
  /// (Supabase renamed this; it used to be called the 'anon public' key)
  static const String supabasePublishableKey = 'YOUR-ANON-PUBLIC-KEY';

  /// Google Cloud Console -> Credentials -> OAuth 2.0 Client IDs -> **Web** client.
  /// Sent as `serverClientId` so the ID token's `aud` matches what Supabase expects.
  static const String googleWebClientId = 'YOUR-WEB-CLIENT-ID.apps.googleusercontent.com';

  /// Google Cloud Console -> Credentials -> OAuth 2.0 Client IDs -> **iOS** client.
  /// Leave null on Android-only builds.
  static const String? googleIosClientId = null;
}
