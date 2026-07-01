import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vens_hub/data/models/course_info.dart'; // Corrected import path

class UserModel {
  final String? id;
  final String firstName;
  final String lastName;
  final String email;
  final String level;
  final String department;
  final String? photoUrl;
  final Map<String, dynamic>? analytics;
  final Map<String, dynamic>? schedule;
  final List<CourseInfo>? courseInfo;
  final DateTime? createdAt;
  final bool? isEmailVerified;
  UserModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.level,
    required this.department,
    this.photoUrl,
    this.courseInfo,
    this.analytics,
    this.schedule,
    this.createdAt,
    this.isEmailVerified,
  });

  static UserModel fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    DateTime? createdAt;
    if (data["createdAt"] != null) {
      if (data["createdAt"] is String) {
        createdAt = DateTime.tryParse(data["createdAt"]);
      } else if (data["createdAt"] is Timestamp) {
        createdAt = (data["createdAt"] as Timestamp).toDate();
      }
    }

    return UserModel(
      id: document.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      level: data['level'] ?? '',
      department: data['department'] ?? '',
      photoUrl: data['photoUrl'] as String?,
      analytics: data['analytics'],
      schedule: data['schedule'],
      courseInfo:
          data['courseInfo'] != null
              ? (data['courseInfo'] as List)
                  .map((i) => CourseInfo.fromJson(i as Map<String, dynamic>))
                  .toList()
              : null,
      createdAt: createdAt,
    );
  }

  static UserModel fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    if (json["createdAt"] != null) {
      if (json["createdAt"] is String) {
        createdAt = DateTime.tryParse(json["createdAt"]);
      } else if (json["createdAt"] is Timestamp) {
        createdAt = (json["createdAt"] as Timestamp).toDate();
      }
    }

    return UserModel(
      id: json['id'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      level: json['level'] ?? '',
      department: json['department'] ?? '',
      photoUrl: json['photoUrl'] as String?,
      analytics: json['analytics'],
      schedule: json['schedule'],
      courseInfo:
          json['courseInfo'] != null
              ? (json['courseInfo'] as List)
                  .map((i) => CourseInfo.fromJson(i as Map<String, dynamic>))
                  .toList()
              : null,
      createdAt: createdAt,
      isEmailVerified: json["isEmailVerified"] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'level': level,
      'department': department,
      'photoUrl': photoUrl,
      'analytics': analytics,
      'schedule': schedule,
      'courseInfo': courseInfo?.map((i) => i.toJson()).toList(),
      "createdAt": createdAt?.toIso8601String(),
      "isEmailVerified": isEmailVerified,
    };
  }

  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? level,
    String? department,
    String? photoUrl,
    Map<String, dynamic>? analytics,
    Map<String, dynamic>? schedule,
    List<CourseInfo>? courseInfo,
    DateTime? createdAt,
    bool? isEmailVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      level: level ?? this.level,
      department: department ?? this.department,
      photoUrl: photoUrl ?? this.photoUrl,
      analytics: analytics ?? this.analytics,
      schedule: schedule ?? this.schedule,
      courseInfo: courseInfo ?? this.courseInfo,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}
