import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/data/models/user_model.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';
import 'package:vens_hub/domain/auth/usecases/get_current_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/sign_in_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/sign_up_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/sign_out_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/complete_user_profile_data_storage_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/send_verification_email_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/check_email_verification_usecase.dart';
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:vens_hub/core/services/auth/auth_service.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_event.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_state.dart';

class MockAnalyticsService implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class MockAuthService implements AuthService {
  final fb_auth.User? Function()? onGetCurrentUser;
  final Future<void> Function()? onReloadCurrentUser;

  MockAuthService({
    this.onGetCurrentUser,
    this.onReloadCurrentUser,
  });

  @override
  fb_auth.User? get currentUser => onGetCurrentUser != null ? onGetCurrentUser!() : null;

  @override
  Future<void> reloadCurrentUser() async {
    if (onReloadCurrentUser != null) {
      await onReloadCurrentUser!();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class MockFirebaseUser implements fb_auth.User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  MockFirebaseUser({
    required this.uid,
    this.email,
    this.displayName,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAuthRepository implements AuthRepository {
  final Future<Either<Failure, UserModel>> Function()? onSignInWithGoogle;

  MockAuthRepository({this.onSignInWithGoogle});

  @override
  Future<Either<Failure, UserModel>> signInWithGoogle() {
    if (onSignInWithGoogle != null) {
      return onSignInWithGoogle!();
    }
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class MockGetCurrentUserUseCase implements GetCurrentUserUseCase {
  final Future<Either<Failure, UserModel?>> Function() onCall;
  MockGetCurrentUserUseCase(this.onCall);
  @override
  Future<Either<Failure, UserModel?>> call(NoParams params) => onCall();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockSignInUserUseCase implements SignInUserUseCase {
  final Future<Either<Failure, UserModel>> Function(SignInParams) onCall;
  @override
  final AuthRepository authRepository;

  MockSignInUserUseCase({
    required this.onCall,
    required this.authRepository,
  });

  @override
  Future<Either<Failure, UserModel>> call(SignInParams params) => onCall(params);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockSignUpUserUseCase implements SignUpUserUseCase {
  final Future<Either<Failure, UserModel>> Function(SignUpParams) onCall;
  MockSignUpUserUseCase(this.onCall);
  @override
  Future<Either<Failure, UserModel>> call(SignUpParams params) => onCall(params);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockSignOutUserUseCase implements SignOutUserUseCase {
  final Future<Either<Failure, void>> Function() onCall;
  MockSignOutUserUseCase(this.onCall);
  @override
  Future<Either<Failure, void>> call(NoParams params) => onCall();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockCompleteUserProfileDataStorageUseCase implements CompleteUserProfileDataStorageUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockSendVerificationEmailUseCase implements SendVerificationEmailUseCase {
  final Future<Either<Failure, void>> Function()? onCall;
  MockSendVerificationEmailUseCase({this.onCall});
  @override
  Future<Either<Failure, void>> call(NoParams params) => onCall != null ? onCall!() : Future.value(const Right(null));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockCheckEmailVerificationUseCase implements CheckEmailVerificationUseCase {
  final Future<Either<Failure, bool>> Function()? onCall;
  MockCheckEmailVerificationUseCase({this.onCall});
  @override
  Future<Either<Failure, bool>> call(NoParams params) => onCall != null ? onCall!() : Future.value(const Right(true));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late MockAnalyticsService mockAnalyticsService;
  late MockAuthService mockAuthService;

  final testUser = UserModel(
    id: '123',
    email: 'test@example.com',
    firstName: 'John',
    lastName: 'Doe',
    level: '400',
    department: 'COE',
    courseInfo: const [],
    createdAt: DateTime(2026, 1, 1),
    isEmailVerified: true,
  );

  setUp(() async {
    mockAnalyticsService = MockAnalyticsService();
    mockAuthService = MockAuthService();

    // Reset and register dependencies in di.sl
    await di.sl.reset();
    di.sl.registerLazySingleton<AnalyticsService>(() => mockAnalyticsService);
    di.sl.registerLazySingleton<AuthService>(() => mockAuthService);
  });

  group('AuthBloc Tests', () {
    test('initial state should be AuthInitial', () {
      final authBloc = AuthBloc(
        getCurrentUserUseCase: MockGetCurrentUserUseCase(() async => const Right(null)),
        signInUserUseCase: MockSignInUserUseCase(
          onCall: (_) async => Right(testUser),
          authRepository: MockAuthRepository(),
        ),
        signUpUserUseCase: MockSignUpUserUseCase((_) async => Right(testUser)),
        signOutUserUseCase: MockSignOutUserUseCase(() async => const Right(null)),
        completeUserProfileDataStorageUseCase: MockCompleteUserProfileDataStorageUseCase(),
        sendVerificationEmailUseCase: MockSendVerificationEmailUseCase(),
        checkEmailVerificationUseCase: MockCheckEmailVerificationUseCase(),
      );

      expect(authBloc.state, equals(AuthInitial()));
      authBloc.close();
    });

    test('AuthAppStarted should emit [AuthAppStartLoading, Authenticated] when session exists', () async {
      mockAuthService = MockAuthService(
        onGetCurrentUser: () => MockFirebaseUser(uid: '123', email: 'test@example.com'),
        onReloadCurrentUser: () async {},
      );
      await di.sl.reset();
      di.sl.registerLazySingleton<AnalyticsService>(() => mockAnalyticsService);
      di.sl.registerLazySingleton<AuthService>(() => mockAuthService);

      final authBloc = AuthBloc(
        getCurrentUserUseCase: MockGetCurrentUserUseCase(() async => Right(testUser)),
        signInUserUseCase: MockSignInUserUseCase(
          onCall: (_) async => Right(testUser),
          authRepository: MockAuthRepository(),
        ),
        signUpUserUseCase: MockSignUpUserUseCase((_) async => Right(testUser)),
        signOutUserUseCase: MockSignOutUserUseCase(() async => const Right(null)),
        completeUserProfileDataStorageUseCase: MockCompleteUserProfileDataStorageUseCase(),
        sendVerificationEmailUseCase: MockSendVerificationEmailUseCase(),
        checkEmailVerificationUseCase: MockCheckEmailVerificationUseCase(),
      );

      final expectedStates = [
        AuthAppStartLoading(),
        Authenticated(testUser),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));
      authBloc.add(AuthAppStarted());
    });

    test('AuthAppStarted should emit [AuthAppStartLoading, Unauthenticated] when no session exists', () async {
      final authBloc = AuthBloc(
        getCurrentUserUseCase: MockGetCurrentUserUseCase(() async => const Right(null)),
        signInUserUseCase: MockSignInUserUseCase(
          onCall: (_) async => Right(testUser),
          authRepository: MockAuthRepository(),
        ),
        signUpUserUseCase: MockSignUpUserUseCase((_) async => Right(testUser)),
        signOutUserUseCase: MockSignOutUserUseCase(() async => const Right(null)),
        completeUserProfileDataStorageUseCase: MockCompleteUserProfileDataStorageUseCase(),
        sendVerificationEmailUseCase: MockSendVerificationEmailUseCase(),
        checkEmailVerificationUseCase: MockCheckEmailVerificationUseCase(),
      );

      final expectedStates = [
        AuthAppStartLoading(),
        Unauthenticated(),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));
      authBloc.add(AuthAppStarted());
    });

    test('AuthSignInRequested should emit [AuthSignInLoading, Authenticated] on success', () async {
      final authBloc = AuthBloc(
        getCurrentUserUseCase: MockGetCurrentUserUseCase(() async => const Right(null)),
        signInUserUseCase: MockSignInUserUseCase(
          onCall: (params) async => Right(testUser),
          authRepository: MockAuthRepository(),
        ),
        signUpUserUseCase: MockSignUpUserUseCase((_) async => Right(testUser)),
        signOutUserUseCase: MockSignOutUserUseCase(() async => const Right(null)),
        completeUserProfileDataStorageUseCase: MockCompleteUserProfileDataStorageUseCase(),
        sendVerificationEmailUseCase: MockSendVerificationEmailUseCase(),
        checkEmailVerificationUseCase: MockCheckEmailVerificationUseCase(),
      );

      final expectedStates = [
        AuthSignInLoading(),
        Authenticated(testUser),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));
      authBloc.add(const AuthSignInRequested(email: 'test@example.com', password: 'password123'));
    });

    test('AuthSignInRequested should emit [AuthSignInLoading, AuthFailureState] on failure', () async {
      final authBloc = AuthBloc(
        getCurrentUserUseCase: MockGetCurrentUserUseCase(() async => const Right(null)),
        signInUserUseCase: MockSignInUserUseCase(
          onCall: (params) async => const Left(AuthenticationFailure(message: 'Invalid credentials')),
          authRepository: MockAuthRepository(),
        ),
        signUpUserUseCase: MockSignUpUserUseCase((_) async => Right(testUser)),
        signOutUserUseCase: MockSignOutUserUseCase(() async => const Right(null)),
        completeUserProfileDataStorageUseCase: MockCompleteUserProfileDataStorageUseCase(),
        sendVerificationEmailUseCase: MockSendVerificationEmailUseCase(),
        checkEmailVerificationUseCase: MockCheckEmailVerificationUseCase(),
      );

      final expectedStates = [
        AuthSignInLoading(),
        const AuthFailureState('Invalid credentials'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));
      authBloc.add(const AuthSignInRequested(email: 'test@example.com', password: 'wrongpassword'));
    });

    test('AuthSignInRequested should emit [AuthSignInLoading, AuthAwaitingProfileCompletion] when user profile is missing', () async {
      mockAuthService = MockAuthService(
        onGetCurrentUser: () => MockFirebaseUser(uid: '123', email: 'test@example.com', displayName: 'John Doe'),
      );
      await di.sl.reset();
      di.sl.registerLazySingleton<AnalyticsService>(() => mockAnalyticsService);
      di.sl.registerLazySingleton<AuthService>(() => mockAuthService);

      final authBloc = AuthBloc(
        getCurrentUserUseCase: MockGetCurrentUserUseCase(() async => const Right(null)),
        signInUserUseCase: MockSignInUserUseCase(
          onCall: (params) async => const Left(AuthenticationFailure(message: 'User profile not found')),
          authRepository: MockAuthRepository(),
        ),
        signUpUserUseCase: MockSignUpUserUseCase((_) async => Right(testUser)),
        signOutUserUseCase: MockSignOutUserUseCase(() async => const Right(null)),
        completeUserProfileDataStorageUseCase: MockCompleteUserProfileDataStorageUseCase(),
        sendVerificationEmailUseCase: MockSendVerificationEmailUseCase(),
        checkEmailVerificationUseCase: MockCheckEmailVerificationUseCase(),
      );

      final expectedStates = [
        AuthSignInLoading(),
        const AuthAwaitingProfileCompletion(
          userId: '123',
          email: 'test@example.com',
          firstName: 'John',
          lastName: 'Doe',
        ),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));
      authBloc.add(const AuthSignInRequested(email: 'test@example.com', password: 'password123'));
    });

    test('AuthSignUpRequested should emit [AuthSignUpLoading, Authenticated] on success', () async {
      final authBloc = AuthBloc(
        getCurrentUserUseCase: MockGetCurrentUserUseCase(() async => const Right(null)),
        signInUserUseCase: MockSignInUserUseCase(
          onCall: (_) async => Right(testUser),
          authRepository: MockAuthRepository(),
        ),
        signUpUserUseCase: MockSignUpUserUseCase((params) async => Right(testUser)),
        signOutUserUseCase: MockSignOutUserUseCase(() async => const Right(null)),
        completeUserProfileDataStorageUseCase: MockCompleteUserProfileDataStorageUseCase(),
        sendVerificationEmailUseCase: MockSendVerificationEmailUseCase(),
        checkEmailVerificationUseCase: MockCheckEmailVerificationUseCase(),
      );

      final expectedStates = [
        AuthSignUpLoading(),
        Authenticated(testUser),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));
      authBloc.add(const AuthSignUpRequested(
        email: 'test@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
        level: '400',
        department: 'COE',
      ));
    });

    test('AuthSignOut should emit [Unauthenticated] when successful', () async {
      final authBloc = CloseableAuthBloc(
        getCurrentUserUseCase: MockGetCurrentUserUseCase(() async => const Right(null)),
        signInUserUseCase: MockSignInUserUseCase(
          onCall: (_) async => Right(testUser),
          authRepository: MockAuthRepository(),
        ),
        signUpUserUseCase: MockSignUpUserUseCase((_) async => Right(testUser)),
        signOutUserUseCase: MockSignOutUserUseCase(() async => const Right(null)),
        completeUserProfileDataStorageUseCase: MockCompleteUserProfileDataStorageUseCase(),
        sendVerificationEmailUseCase: MockSendVerificationEmailUseCase(),
        checkEmailVerificationUseCase: MockCheckEmailVerificationUseCase(),
      );

      final expectedStates = [
        Unauthenticated(),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));
      authBloc.add(AuthSignOut());
    });
  });
}

// Subclass to override close, in case flutter_bloc handles close asynchronously or throws in tests
class CloseableAuthBloc extends AuthBloc {
  CloseableAuthBloc({
    required super.getCurrentUserUseCase,
    required super.signInUserUseCase,
    required super.signUpUserUseCase,
    required super.signOutUserUseCase,
    required super.completeUserProfileDataStorageUseCase,
    required super.sendVerificationEmailUseCase,
    required super.checkEmailVerificationUseCase,
  });
}
