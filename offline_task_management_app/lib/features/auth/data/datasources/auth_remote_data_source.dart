import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';
import 'google_auth_service.dart';

/// Contract for "everything auth-related that leaves the device".
abstract interface class AuthRemoteDataSource {
  /// The session Supabase keeps on disk (access token + refresh token).
  /// Non-null means "this device remembers a login", even with no internet.
  Session? get currentUserSession;

  /// Builds a user purely from the locally stored session — zero network.
  /// This is what makes the app usable offline right after a cold start.
  UserModel? get cachedUserFromSession;

  Future<UserModel> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
  });

  Future<UserModel> loginWithEmailPassword({
    required String email,
    required String password,
  });

  Future<UserModel> signInWithGoogle();

  Future<UserModel?> getCurrentUserData();

  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;
  final GoogleAuthService googleAuthService;

  const AuthRemoteDataSourceImpl({
    required this.supabaseClient,
    required this.googleAuthService,
  });

  @override
  Session? get currentUserSession => supabaseClient.auth.currentSession;

  @override
  UserModel? get cachedUserFromSession {
    final session = currentUserSession;
    if (session == null) return null;
    final authUser = session.user;
    return UserModel(
      id: authUser.id,
      email: authUser.email ?? '',
      name: _nameFromMetadata(authUser.userMetadata, authUser.email),
    );
  }

  @override
  Future<UserModel> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // POST /auth/v1/signup
      // Body: { email, password, data: { name } }
      // `data` lands in auth.users.raw_user_meta_data, and our Postgres
      // trigger copies it into the public.profiles row.
      final response = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      final authUser = response.user;
      if (authUser == null) {
        throw const ServerException('Sign up failed: no user returned.');
      }
      return await _fetchProfile(authUser.id, fallbackEmail: authUser.email);
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<UserModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      // POST /auth/v1/token?grant_type=password
      final response = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw const ServerException('Login failed: no user returned.');
      }
      return await _fetchProfile(authUser.id, fallbackEmail: authUser.email);
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      // 1. Ask Google (not Supabase) to identify the user -> signed ID token.
      final idToken = await googleAuthService.getIdToken();

      // 2. Trade Google's token for a Supabase session.
      //    POST /auth/v1/token?grant_type=id_token
      final response = await supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw const ServerException('Google sign-in failed: no user returned.');
      }
      return await _fetchProfile(authUser.id, fallbackEmail: authUser.email);
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<UserModel?> getCurrentUserData() async {
    try {
      final session = currentUserSession;
      if (session == null) return null;
      return await _fetchProfile(
        session.user.id,
        fallbackEmail: session.user.email,
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await googleAuthService.signOut();
    } catch (_) {
      // Not being signed in to Google is not a reason to block logout.
    }
    await supabaseClient.auth.signOut();
  }

  /// SELECT id, name FROM profiles WHERE id = :userId LIMIT 1;
  ///
  /// Row Level Security makes this safe: Postgres silently adds
  /// `AND id = auth.uid()`, so one user can never read another's row.
  Future<UserModel> _fetchProfile(
    String userId, {
    String? fallbackEmail,
  }) async {
    final rows = await supabaseClient
        .from('profiles')
        .select('id, name')
        .eq('id', userId)
        .limit(1);

    if (rows.isEmpty) {
      // The trigger has not run (or the table is missing). Degrade gracefully
      // instead of crashing the whole login.
      return cachedUserFromSession ??
          UserModel(id: userId, email: fallbackEmail ?? '', name: '');
    }

    return UserModel.fromJson({
      ...rows.first,
      'email': fallbackEmail ?? '',
    });
  }

  String _nameFromMetadata(Map<String, dynamic>? metadata, String? email) {
    final fromSignUp = metadata?['name'] as String?;
    final fromGoogle = metadata?['full_name'] as String?;
    return fromSignUp ?? fromGoogle ?? (email?.split('@').first ?? '');
  }
}
