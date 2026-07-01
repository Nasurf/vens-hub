import 'package:equatable/equatable.dart';
import 'package:vens_hub/data/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

// Specific loading states for different auth operations
class AuthAppStartLoading extends AuthState {}

class AuthSignInLoading extends AuthState {}

class AuthGoogleSignInLoading extends AuthState {}

class AuthSignUpLoading extends AuthState {}

class AuthEmailVerificationLoading extends AuthState {}

class Authenticated extends AuthState {
  final UserModel authUser;

  const Authenticated(this.authUser);

  @override
  List<Object?> get props => [authUser];
}

class Unauthenticated extends AuthState {}

class AuthAwaitingVerification extends AuthState {
  final String email;
  final String firstName;
  final String lastName;
  final String level;
  final String department;

  const AuthAwaitingVerification({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.level,
    required this.department,
  });

  @override
  List<Object?> get props => [email, firstName, lastName, level, department];
}

class AuthFailureState extends AuthState {
  // Renamed to avoid clash with Failure class
  final String message;
  const AuthFailureState(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthAwaitingProfileCompletion extends AuthState {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;

  const AuthAwaitingProfileCompletion({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  @override
  List<Object?> get props => [userId, email, firstName, lastName];
}
