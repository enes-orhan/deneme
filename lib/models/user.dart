import 'package:uuid/uuid.dart';

class User {
  final String id;
  final String username;
  final String name;
  final String password; // Gerçek uygulamada şifreleri hash'lenmiş olarak saklamalısınız
  final String role; // admin, personel, vb.
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isActive;

  User({
    String? id,
    required this.username,
    required this.name,
    required this.password,
    required this.role,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    this.isActive = true,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    lastLoginAt = lastLoginAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'password': password,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      name: map['name'] as String,
      password: map['password'] as String,
      role: map['role'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastLoginAt: DateTime.parse(map['lastLoginAt'] as String),
      isActive: map['isActive'] as bool,
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? name,
    String? password,
    String? role,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return name;
  }
} 