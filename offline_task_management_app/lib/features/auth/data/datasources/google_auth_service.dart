import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/secrets/app_secrets.dart';

/// One job only: open the native Google account picker and hand back the
/// **ID token** Google signs for us. It knows nothing about Supabase.
///
/// Single Responsibility: Google talk lives here, Supabase talk lives in
/// [AuthRemoteDataSourceImpl]. Testing the data source only needs a fake of
/// this tiny interface.
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
  /// `serverClientId` is the **Web** OAuth client ID. It tells Google:
  /// "mint the ID token for this audience". Supabase then checks that the
  /// token's `aud` claim equals the Client ID you pasted into its Google
  /// provider settings — that is how it knows the token is really yours.
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
