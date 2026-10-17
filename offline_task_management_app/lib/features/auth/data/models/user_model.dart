import '../../../../core/common/entities/user.dart';

/// A [UserModel] is a [User] that also knows how to talk JSON.
///
/// Why not put fromJson/toJson on the entity itself? Because the entity lives
/// in the domain layer, and the domain must not know that your backend speaks
/// JSON. If tomorrow the backend returns XML, only this file changes.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
  });

  /// Maps a row of the Postgres `profiles` table (or Supabase auth metadata)
  /// into our model.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
      };

  UserModel copyWith({String? id, String? email, String? name}) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
    );
  }
}
