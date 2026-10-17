/// Project-specific keys.
///
/// The Supabase anon key is NOT a password — it is a public, publishable key
/// that only says "I am this project's mobile app". What actually protects
/// your rows is Row Level Security in Postgres, which reads the signed JWT of
/// the logged-in user. Still, keep this file out of git so you can rotate
/// keys and keep project URLs private.
class AppSecrets {
  const AppSecrets._();

  /// Supabase Dashboard -> Project Settings -> API -> Project URL
  static const String supabaseUrl = 'https://YOUR-PROJECT-REF.supabase.co';

  /// Supabase Dashboard -> Project Settings -> API Keys -> publishable key
  /// (Supabase renamed this; it used to be called the 'anon public' key)
  static const String supabasePublishableKey = 'YOUR-ANON-PUBLIC-KEY';

  /// Google Cloud Console -> Credentials -> OAuth 2.0 Client IDs -> **Web** client.
  /// Android/iOS both send this as `serverClientId` so Google mints an ID token
  /// whose `aud` claim matches what Supabase expects.
  static const String googleWebClientId = 'YOUR-WEB-CLIENT-ID.apps.googleusercontent.com';

  /// Google Cloud Console -> Credentials -> OAuth 2.0 Client IDs -> **iOS** client.
  /// Leave null on Android-only builds.
  static const String? googleIosClientId = null;
}
