// lib/presentation/blocs/auth/auth_bloc.dart

import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/domain/auth/usecases/get_current_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/sign_in_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/sign_up_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/sign_out_user_usecase.dart';

import 'package:vens_hub/domain/auth/usecases/complete_user_profile_data_storage_usecase.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/auth/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final SignInUserUseCase signInUserUseCase;
  final SignUpUserUseCase signUpUserUseCase;
  final SignOutUserUseCase signOutUserUseCase;

  final CompleteUserProfileDataStorageUseCase
  completeUserProfileDataStorageUseCase;

  // Do not cache currentUser at construction; always query fresh from AuthService.

  AuthBloc({
    required this.getCurrentUserUseCase,
    required this.signInUserUseCase,
    required this.signUpUserUseCase,
    required this.signOutUserUseCase,
    required this.completeUserProfileDataStorageUseCase,
  }) : super(AuthInitial()) {
    on<AuthAppStarted>(_onAppStarted);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignOut>(_signOutRequested);
  }

  Future<void> _signOutRequested(
    AuthSignOut event,
    Emitter<AuthState> emit,
  ) async {
    final analyticsService = di.sl<AnalyticsService>();
    final startTime = DateTime.now();

    // Log sign-out attempt
    await analyticsService.logAuthEvent(
      authAction: 'sign_out_attempt',
      method: 'standard',
    );

    final signOutOrFailure = await signOutUserUseCase(NoParams());
    final duration = DateTime.now().difference(startTime);

    signOutOrFailure.fold(
      (failure) {
        analyticsService.logAuthEvent(
          authAction: 'sign_out',
          method: 'standard',
          success: false,
          errorCode: 'sign_out_failure',
        );
        analyticsService.logError(
          'Sign out failed',
          error: failure.message,
          fatal: false,
        );
        emit(AuthFailureState("Unable To Sign Out"));
      },
      (_) {
        analyticsService.logAuthEvent(
          authAction: 'sign_out',
          method: 'standard',
          success: true,
        );
        analyticsService.logPerformanceMetric(
          metricName: 'auth_sign_out_duration',
          value: duration.inMilliseconds,
          unit: 'ms',
        );
        emit(Unauthenticated());
      },
    );
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final analyticsService = di.sl<AnalyticsService>();
    final startTime = DateTime.now();

    emit(AuthSignInLoading());

    await analyticsService.logAuthEvent(
      authAction: 'sign_in_attempt',
      method: 'email_password',
    );

    final failureOrUser = await signInUserUseCase(
      SignInParams(email: event.email, password: event.password),
    );

    final duration = DateTime.now().difference(startTime);

    failureOrUser.fold(
      (failure) {
        // If the user authenticated via Firebase but has no profile in Firestore,
        // route them to complete profile (choose department/level and seed courses).
        if (failure.message.contains('User profile not found')) {
          final authSvc = di.sl<AuthService>();
          final fbUser = authSvc.currentUser;
          if (fbUser != null) {
            final displayName = fbUser.displayName ?? '';
            String firstName = '';
            String lastName = '';
            if (displayName.isNotEmpty) {
              final parts = displayName.trim().split(' ');
              firstName = parts.isNotEmpty ? parts.first : '';
              lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            }

            analyticsService.logUserJourney(
              fromScreen: 'sign_in',
              toScreen: 'profile_completion',
              action: 'no_profile_in_firestore',
              context: {
                'user_id': fbUser.uid,
                'email': fbUser.email ?? event.email,
              },
            );

            emit(
              AuthAwaitingProfileCompletion(
                userId: fbUser.uid,
                email: fbUser.email ?? event.email,
                firstName: firstName,
                lastName: lastName,
              ),
            );
            return;
          }
        }
        analyticsService.logAuthEvent(
          authAction: 'sign_in',
          method: 'email_password',
          success: false,
          errorCode: failure.message,
        );
        analyticsService.logPerformanceMetric(
          metricName: 'auth_sign_in_failed_duration',
          value: duration.inMilliseconds,
          unit: 'ms',
          tags: {'error': failure.message},
        );
        analyticsService.logError(
          'Sign in failed',
          error: failure.message,
          fatal: false,
        );
        emit(AuthFailureState(failure.message));
      },
      (user) {
        analyticsService.logAuthEvent(
          authAction: 'sign_in',
          method: 'email_password',
          success: true,
        );
        analyticsService.logPerformanceMetric(
          metricName: 'auth_sign_in_duration',
          value: duration.inMilliseconds,
          unit: 'ms',
        );
        analyticsService.logUserJourney(
          fromScreen: 'sign_in',
          toScreen: 'authenticated_home',
          action: 'successful_sign_in',
          context: {
            'user_id': user.id ?? 'unknown',
            'department': user.department,
            'level': user.level,
          },
        );
        emit(Authenticated(user));
      },
    );
  }

  Future<void> _onAppStarted(
    AuthAppStarted event,
    Emitter<AuthState> emit,
  ) async {
    final analyticsService = di.sl<AnalyticsService>();

    emit(AuthAppStartLoading());

    await analyticsService.logAuthEvent(
      authAction: 'app_start_auth_check',
      method: 'session',
    );

    final failureOrUser = await getCurrentUserUseCase(NoParams());
    await failureOrUser.fold(
      (failure) async {
        await analyticsService.logAuthEvent(
          authAction: 'app_start_no_user',
          method: 'session',
          success: false,
          errorCode: failure.message,
        );
        emit(Unauthenticated());
      },
      (user) async {
        if (user != null) {
          final authSvc = di.sl<AuthService>();
          try {
            await authSvc.reloadCurrentUser();
          } on NetworkException catch (e) {
            await analyticsService.logAuthEvent(
              authAction: 'app_start_refresh_failed',
              method: 'session',
              success: false,
              errorCode: 'network_unavailable',
            );
            emit(AuthFailureState(e.message));
            return;
          } on AuthenticationException catch (e) {
            await analyticsService.logAuthEvent(
              authAction: 'app_start_refresh_failed',
              method: 'session',
              success: false,
              errorCode: 'reload_failed',
            );
            emit(AuthFailureState(e.message));
            return;
          } catch (e) {
            await analyticsService.logError(
              'Unexpected error refreshing user on app start',
              error: e.toString(),
              fatal: false,
            );
            emit(AuthFailureState('Something went wrong. Please try again.'));
            return;
          }
          await analyticsService.logAuthEvent(
            authAction: 'app_start_authenticated',
            method: 'session',
            success: true,
          );
          await analyticsService.logUserJourney(
            fromScreen: 'app_start',
            toScreen: 'authenticated_home',
            action: 'session_restored',
            context: {
              'user_id': user.id ?? 'unknown',
              'department': user.department,
              'level': user.level,
            },
          );
          emit(Authenticated(user));
        } else {
          await analyticsService.logAuthEvent(
            authAction: 'app_start_no_session',
            method: 'session',
            success: false,
          );
          emit(Unauthenticated());
        }
      },
    );
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final analyticsService = di.sl<AnalyticsService>();
    final startTime = DateTime.now();

    emit(AuthGoogleSignInLoading());

    await analyticsService.logAuthEvent(
      authAction: 'google_sign_in_attempt',
      method: 'google',
    );

    final failureOrUser =
        await signInUserUseCase.authRepository.signInWithGoogle();
    final duration = DateTime.now().difference(startTime);

    await failureOrUser.fold(
      (failure) {
        analyticsService.logAuthEvent(
          authAction: 'google_sign_in',
          method: 'google',
          success: false,
          errorCode: failure.message,
        );
        analyticsService.logPerformanceMetric(
          metricName: 'auth_google_sign_in_failed_duration',
          value: duration.inMilliseconds,
          unit: 'ms',
          tags: {'error': failure.message},
        );
        analyticsService.logError(
          'Google sign in failed',
          error: failure.message,
          fatal: false,
        );
        emit(AuthFailureState(failure.message));
      },
      (user) {
        analyticsService.logAuthEvent(
          authAction: 'google_sign_in',
          method: 'google',
          success: true,
        );
        analyticsService.logPerformanceMetric(
          metricName: 'auth_google_sign_in_duration',
          value: duration.inMilliseconds,
          unit: 'ms',
        );

        if (user.level.isEmpty || user.department.isEmpty) {
          // User needs to complete profile
          analyticsService.logUserJourney(
            fromScreen: 'google_sign_in',
            toScreen: 'profile_completion',
            action: 'profile_incomplete',
            context: {'user_id': user.id ?? 'unknown', 'email': user.email},
          );
          emit(
            AuthAwaitingProfileCompletion(
              userId: user.id ?? '',
              email: user.email,
              firstName: user.firstName,
              lastName: user.lastName,
            ),
          );
        } else {
          analyticsService.logUserJourney(
            fromScreen: 'google_sign_in',
            toScreen: 'authenticated_home',
            action: 'successful_google_sign_in',
            context: {
              'user_id': user.id ?? 'unknown',
              'department': user.department,
              'level': user.level,
            },
          );
          emit(Authenticated(user));
        }
      },
    );
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    final analyticsService = di.sl<AnalyticsService>();
    final startTime = DateTime.now();

    emit(AuthSignUpLoading());

    await analyticsService.logAuthEvent(
      authAction: 'sign_up_attempt',
      method: 'email_password',
    );

    final failureOrUser = await signUpUserUseCase(
      SignUpParams(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        department: event.department,
        selectedCourses: event.selectedCourses,
      ),
    );

    final duration = DateTime.now().difference(startTime);

    await failureOrUser.fold(
      (failure) async {
        await analyticsService.logAuthEvent(
          authAction: 'sign_up',
          method: 'email_password',
          success: false,
          errorCode: failure.message,
        );
        await analyticsService.logPerformanceMetric(
          metricName: 'auth_sign_up_failed_duration',
          value: duration.inMilliseconds,
          unit: 'ms',
          tags: {
            'error': failure.message,
            'department': event.department,
          },
        );
        await analyticsService.logError(
          'Sign up failed',
          error: failure.message,
          fatal: false,
        );
        emit(AuthFailureState(failure.message));
      },
      (user) async {
        await analyticsService.logAuthEvent(
          authAction: 'sign_up',
          method: 'email_password',
          success: true,
        );
        await analyticsService.logPerformanceMetric(
          metricName: 'auth_sign_up_duration',
          value: duration.inMilliseconds,
          unit: 'ms',
          tags: {'department': event.department},
        );

        final authSvc = di.sl<AuthService>();
        try {
          await authSvc.reloadCurrentUser();
        } on NetworkException catch (e) {
          await analyticsService.logAuthEvent(
            authAction: 'sign_up_reload_failed',
            method: 'email_password',
            success: false,
            errorCode: 'network_unavailable',
          );
          emit(AuthFailureState(e.message));
          return;
        } on AuthenticationException catch (e) {
          await analyticsService.logAuthEvent(
            authAction: 'sign_up_reload_failed',
            method: 'email_password',
            success: false,
            errorCode: 'reload_failed',
          );
          emit(AuthFailureState(e.message));
          return;
        } catch (e) {
          await analyticsService.logError(
            'Unexpected error refreshing user after sign up',
            error: e.toString(),
            fatal: false,
          );
          emit(AuthFailureState('Something went wrong. Please try again.'));
          return;
        }
        await analyticsService.logUserJourney(
          fromScreen: 'sign_up',
          toScreen: 'authenticated_home',
          action: 'successful_sign_up',
          context: {
            'user_id': user.id ?? 'unknown',
            'department': user.department,
            'level': user.level,
          },
        );
        emit(Authenticated(user));
      },
    );
  }
}
