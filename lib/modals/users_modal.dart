import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String userId;
  final String email;
  final String role; // "student" or "instructor"
  final String? bio; // Optional for instructors
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.userId,
    required this.email,
    required this.role,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
  });

  // Use fromJson for deserializing Firestore documents
  factory User.fromJson(Map<String, dynamic> json) => User(
        userId: json['userId'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        bio: json['bio'] as String?, // Make sure it's nullable
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      );

  // Use toJson for serializing the User model to Firestore
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'role': role,
        if (bio != null) 'bio': bio,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
