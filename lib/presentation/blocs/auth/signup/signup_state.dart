import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SignUpState extends Equatable {
  final int currentStep;
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String confirmPassword;
  final String selectedLevel;
  final String selectedDepartment;
  final bool isLoading;
  final bool passwordVisible;
  final bool confirmPasswordVisible;
  final GlobalKey<FormState> formKey1;
  final GlobalKey<FormState> formKey4;

  const SignUpState({
    this.currentStep = 0,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.selectedLevel = '',
    this.selectedDepartment = '',
    this.isLoading = false,
    this.passwordVisible = false,
    this.confirmPasswordVisible = false,
    required this.formKey1,
    required this.formKey4,
  });

  SignUpState copyWith({
    int? currentStep,
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    String? confirmPassword,
    String? selectedLevel,
    String? selectedDepartment,
    bool? isLoading,
    bool? passwordVisible,
    bool? confirmPasswordVisible,
  }) {
    return SignUpState(
      currentStep: currentStep ?? this.currentStep,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      isLoading: isLoading ?? this.isLoading,
      passwordVisible: passwordVisible ?? this.passwordVisible,
      confirmPasswordVisible:
          confirmPasswordVisible ?? this.confirmPasswordVisible,
      formKey1: formKey1,
      formKey4: formKey4,
    );
  }

  @override
  List<Object> get props => [
    currentStep,
    firstName,
    lastName,
    email,
    password,
    confirmPassword,
    selectedLevel,
    selectedDepartment,
    isLoading,
    passwordVisible,
    confirmPasswordVisible,
  ];
}
