import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  // final List properties; // Original plan had this, but message is more common.
  // If detailed properties are needed, it can be List<Object> or specific.
  // For now, keeping it simple with a message.

  const Failure({required this.message});

  @override
  List<Object> get props => [message];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

class UnknownFailure extends Failure {
  const UnknownFailure({required super.message});
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure({required super.message});
}

// Appended specific Authentication Failures

class InvalidEmailFailure extends AuthenticationFailure {
  const InvalidEmailFailure({
    super.message = "The email address is badly formatted.",
  });
}

class UserDisabledFailure extends AuthenticationFailure {
  const UserDisabledFailure({
    super.message = "This user account has been disabled.",
  });
}

class UserNotFoundFailure extends AuthenticationFailure {
  const UserNotFoundFailure({super.message = "No user found for this email."});
}

class WrongPasswordFailure extends AuthenticationFailure {
  const WrongPasswordFailure({super.message = "Incorrect password."});
}

class EmailAlreadyInUseFailure extends AuthenticationFailure {
  const EmailAlreadyInUseFailure({
    super.message = "This email address is already in use by another account.",
  });
}

class WeakPasswordFailure extends AuthenticationFailure {
  const WeakPasswordFailure({
    super.message = "The password provided is too weak.",
  });
}

class OperationNotAllowedFailure extends AuthenticationFailure {
  const OperationNotAllowedFailure({
    super.message =
        "This operation is not allowed. Email/password accounts may not be enabled.",
  });
}
