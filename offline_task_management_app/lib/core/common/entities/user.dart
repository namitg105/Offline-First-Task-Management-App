import 'package:equatable/equatable.dart';

/// The app's own idea of a user. Pure Dart: no Supabase, JSON or Flutter.
///
/// Lives in `core/common` so other features (Tasks) can reference a task's owner
/// without importing `features/auth`.
class User extends Equatable {
  final String id;
  final String email;
  final String name;

  const User({
    required this.id,
    required this.email,
    required this.name,
  });

  @override
  List<Object?> get props => [id, email, name];
}
