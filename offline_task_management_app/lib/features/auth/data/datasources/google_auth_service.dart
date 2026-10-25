import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/secrets/app_secrets.dart';

/// Opens the native Google account picker and returns the ID token Google signs.
/// Knows nothing about Supabase.
abstract interface class GoogleAuthService {
  /// Returns a JWT signed by Google (`accounts.google.com`).
  Future<String> getIdToken();

  Future<void> signOut();
}

class GoogleAuthServiceImpl implements GoogleAuthService {
  final GoogleSignIn googleSignIn;
  bool _initialized = false;

  GoogleAuthServiceImpl(this.googleSignIn);

  /// google_sign_in 7.x must be initialised once before any call.
  ///
  /// `serverClientId` is the **Web** OAuth client ID: Google mints the ID token for
  /// that audience, and Supabase checks the token's `aud` against the Client ID in
  /// its Google provider settings.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await googleSignIn.initialize(
      clientId: AppSecrets.googleIosClientId,
      serverClientId: AppSecrets.googleWebClientId,
    );
    _initialized = true;
  }

  @override
  Future<String> getIdToken() async {
    try {
      await _ensureInitialized();
        
      if (!googleSignIn.supportsAuthenticate()) {
        throw const ServerException(
          'Google sign-in is not supported on this platform.',
        );
      }

      final account = await googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const ServerException(
          'Google did not return an ID token. Check that serverClientId is the '
          'WEB client ID and that your SHA-1 fingerprint is registered.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const ServerException('Google sign-in was cancelled.');
      }
      throw ServerException('Google sign-in failed: ${e.description ?? e.code}');
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await googleSignIn.signOut();
  }
}
