import 'package:equatable/equatable.dart';

/// The app's own idea of a user. Pure Dart: no Supabase, no JSON, no Flutter.
///
/// It lives in `core/common` (not inside `features/auth`) because other
/// features — the Tasks feature, for example — need to know who owns a task,
/// and a feature must never import another feature's internals.
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
