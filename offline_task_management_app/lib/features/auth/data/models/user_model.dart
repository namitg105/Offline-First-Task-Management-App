import '../../../../core/common/entities/user.dart';

/// A [User] that also knows how to talk JSON. The conversion lives here, not on the
/// entity, so the domain never learns the backend's wire format.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
  });

  /// Maps a row of the Postgres `profiles` table into our model.
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
