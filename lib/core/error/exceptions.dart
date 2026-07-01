class ServerException implements Exception {
  final String message;
  ServerException({this.message = "An unexpected server error occurred."});
}

class CacheException implements Exception {
  final String message;
  CacheException({this.message = "An unexpected cache error occurred."});
}

class NetworkException implements Exception {
  final String message;
  NetworkException({
    this.message = "A network error occurred. Please check your connection.",
  });
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException({required this.message});
}

class StorageException implements Exception {
  final String message;
  StorageException({required this.message});
  @override
  String toString() => 'StorageException: $message';
}

class EmailNotVerifiedException implements Exception {
  final String message;

  EmailNotVerifiedException({this.message = 'Email not verified.'});
}

// Appended specific Authentication Exceptions

class InvalidEmailException extends AuthenticationException {
  InvalidEmailException({
    super.message = "The email address is badly formatted.",
  });
}

class UserDisabledException extends AuthenticationException {
  UserDisabledException({
    super.message = "This user account has been disabled.",
  });
}

class UserNotFoundException extends AuthenticationException {
  UserNotFoundException({super.message = "No user found for this email."});
}

class WrongPasswordException extends AuthenticationException {
  WrongPasswordException({super.message = "Incorrect password."});
}

class EmailAlreadyInUseException extends AuthenticationException {
  EmailAlreadyInUseException({
    super.message = "This email address is already in use by another account.",
  });
}

class WeakPasswordException extends AuthenticationException {
  WeakPasswordException({super.message = "The password provided is too weak."});
}

class OperationNotAllowedException extends AuthenticationException {
  OperationNotAllowedException({
    super.message =
        "This operation is not allowed. Email/password accounts may not be enabled.",
  });
}

class QuestionGenerationException implements Exception {
  final String message;
  QuestionGenerationException(this.message);
  @override
  String toString() => 'QuestionGenerationException: $message';
}

class AIServiceException implements Exception {
  final String message;
  final dynamic
  underlyingException; // Optional: to store the original exception

  AIServiceException({required this.message, this.underlyingException});

  @override
  String toString() {
    if (underlyingException != null) {
      return 'AIServiceException: $message (Caused by: $underlyingException)';
    }
    return 'AIServiceException: $message';
  }
}

class FirestoreServiceException implements Exception {
  final String message;
  final dynamic underlyingException; // Optional

  FirestoreServiceException({required this.message, this.underlyingException});

  @override
  String toString() {
    if (underlyingException != null) {
      return 'FirestoreServiceException: $message (Caused by: $underlyingException)';
    }
    return 'FirestoreServiceException: $message';
  }
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => 'ValidationException: $message';
}

class CustomFirebaseStorageException implements Exception {
  // Renamed to avoid clash with SDK's
  final String message;
  CustomFirebaseStorageException(this.message);
  @override
  String toString() => 'CustomFirebaseStorageException: $message';
}

class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);
  @override
  String toString() => 'PermissionException: $message';
}
