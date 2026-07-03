import 'package:equatable/equatable.dart';

class RegistrationOnboardingModel extends Equatable {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String level;
  final String department;

  const RegistrationOnboardingModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.level,
    required this.department,
  });

  RegistrationOnboardingModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    String? level,
    String? department,
  }) {
    return RegistrationOnboardingModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      password: password ?? this.password,
      level: level ?? this.level,
      department: department ?? this.department,
    );
  }

  factory RegistrationOnboardingModel.fromJson(Map<String, dynamic> json) {
    return RegistrationOnboardingModel(
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      level: json['level'] as String,
      department: json['department'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'level': level,
      'department': department,
    };
  }

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    email,
    password,
    level,
    department,
  ];
}
