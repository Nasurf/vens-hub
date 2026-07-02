import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as fb_auth; // Import FirebaseAuth
import 'package:vens_hub/core/config/app_config.dart'; // Import new AppConfig
import 'package:vens_hub/core/services/auth/auth_service.dart';
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';
import 'package:vens_hub/data/auth/repositories/auth_repository_impl.dart';
import 'package:vens_hub/domain/auth/usecases/sign_in_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/sign_up_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/sign_out_user_usecase.dart';
import 'package:vens_hub/domain/auth/usecases/get_current_user_usecase.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart'; // Import AuthBloc
import 'package:firebase_performance/firebase_performance.dart';

// Course feature imports
import 'package:vens_hub/domain/course/repositories/course_repository.dart';
import 'package:vens_hub/data/course/repositories/course_repository_impl.dart';
import 'package:vens_hub/domain/course/usecases/get_user_courses_usecase.dart';
import 'package:vens_hub/domain/course/usecases/get_all_courses_usecase.dart';
import 'package:vens_hub/core/services/local_storage/onboarding_status_service.dart'; // Import OnboardingStatusService
import 'package:vens_hub/core/services/local_storage/user_cache_service.dart'; // Import UserCacheService
import 'package:vens_hub/core/services/local_storage/course_cache_service.dart'; // Import CourseCacheService
import 'package:vens_hub/core/services/local_storage/cache_clearing_service.dart'; // Import CacheClearingService
import 'package:vens_hub/core/services/local_storage/daily_cache_service.dart';
import 'package:vens_hub/core/services/local_storage/streak_service.dart'; // Import StreakService
import 'package:vens_hub/core/services/ai/gemini_client.dart'; // Import GeminiService
import 'package:vens_hub/presentation/blocs/course/course_bloc.dart'; // Import CourseBloc
import 'package:firebase_storage/firebase_storage.dart'; // Import FirebaseStorage
import 'package:vens_hub/core/services/storage/firebase_storage_service.dart'; // Import FirebaseStorageService
import 'package:vens_hub/core/services/storage/r2_storage_service.dart'; // Import R2StorageService
import 'package:vens_hub/core/services/storage/firestore_textbook_service.dart'; // Import FirestoreTextbookService
import 'package:vens_hub/domain/study/repositories/study_repository.dart'; // Import StudyRepository
import 'package:vens_hub/data/study/repositories/study_repository_impl.dart'; // Import StudyRepositoryImpl
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/presentation/blocs/study/study_bloc.dart'; // Import StudyBloc
import 'package:vens_hub/core/services/data/firestore_service.dart'; // Import FireStoreServices
import 'package:vens_hub/core/services/notifications/notification_service.dart'; // Import NotificationService
import 'package:vens_hub/core/services/notifications/notification_test_service.dart'; // Import NotificationTestService
import 'package:vens_hub/core/services/notifications/streak_reminder_service.dart'; // Import StreakReminderService
import 'package:vens_hub/core/services/notification_background_service.dart';

import 'package:vens_hub/domain/auth/usecases/complete_user_profile_data_storage_usecase.dart';

import '../../domain/auth/usecases/delete_account_usecase.dart';
import '../services/auth/firebase_auth_service.dart';

// Placeholder AppConfig class removed.

final sl = GetIt.instance; // Service Locator instance

Future<void> initDI() async {
  // Start a custom trace for DI initialization (if available)
  Trace? trace;
  try {
    if (sl.isRegistered<FirebasePerformance>()) {
      trace = sl<FirebasePerformance>().newTrace('initDI');
      await trace.start();
    }
  } catch (_) {
    // Ignore perf issues; DI should not fail on tracing
  }

  try {
    // Renamed to initDI to avoid clash if main.dart also has an init
    // External
    sl.registerLazySingleton(
      () => fb_auth.FirebaseAuth.instance,
    ); // Register FirebaseAuth
    sl.registerLazySingleton(() => FirebaseFirestore.instance);
    sl.registerLazySingleton(
      () => FirebaseStorage.instance,
    ); // Register FirebaseStorage
    sl.registerLazySingleton(() => AppConfig()); // Register AppConfig

    // Services
    sl.registerLazySingleton<AuthService>(
      () => FirebaseAuthService(firebaseAuth: sl()),
    );
    sl.registerLazySingleton(
      () => OnboardingStatusService(),
    ); // Register OnboardingStatusService
    sl.registerLazySingleton(
      () => UserCacheService(),
    ); // Register UserCacheService
    sl.registerLazySingleton(
      () => CourseCacheService(),
    ); // Register CourseCacheService
    sl.registerLazySingleton(() => DailyCacheService());
    sl.registerLazySingleton(
      () => CacheClearingService(),
    ); // Register CacheClearingService
    sl.registerLazySingleton(
      () => StreakService(db: sl(), auth: sl()),
    ); // Register StreakService with Firestore + Auth
    sl.registerLazySingleton(
      () => GeminiService(modelType: 'gemma-4-31b-it'),
    ); // Register GeminiService with Gemma 4 31B
    sl.registerLazySingleton(
      () => FirebaseStorageService(),
    ); // Register FirebaseStorageService
    sl.registerLazySingleton(
      () => R2StorageService(),
    ); // Register R2StorageService
    sl.registerLazySingleton(
      () => FirestoreTextbookService(),
    ); // Register FirestoreTextbookService
    sl.registerLazySingleton<AnalyticsService>(
      () => FirebaseAnalyticsService(),
    );
    // sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
    // ThemeService is registered with GetX instead
    // sl.registerLazySingleton(() => ThemeService());

    // ADD FireStoreServices registration
    sl.registerLazySingleton(() => FireStoreServices());

    // Register NotificationService and NotificationTestService
    sl.registerLazySingleton(() => NotificationService());
    sl.registerLazySingleton(() => NotificationTestService());

    // Register StreakReminderService
    sl.registerLazySingleton(() => StreakReminderService());

    // Register NotificationBackgroundService
    sl.registerLazySingleton(() => NotificationBackgroundService());

    // Repositories
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        authService: sl(),
        firestoreService: sl(), // MODIFIED: Inject FireStoreServices
        r2StorageService: sl(), // Inject R2StorageService
        userCacheService: sl(),
        cacheClearingService: sl(),
      ),
    );
    sl.registerLazySingleton<CourseRepository>(
      // Course Repository Registration
      () => CourseRepositoryImpl(
        firestoreService: sl(), // MODIFIED: Inject FireStoreServices
        authRepository: sl(),
        userCacheService: sl(),
        courseCacheService: sl(),
        dailyCacheService: sl(),
      ),
    );
    sl.registerLazySingleton<StudyRepository>(
      // Study Repository Registration
      () => StudyRepositoryImpl(storageService: sl()),
    );
    // Use cases
    // Auth Use Cases
    sl.registerLazySingleton(() => SignInUserUseCase(sl()));
    sl.registerLazySingleton(() => SignUpUserUseCase(sl()));
    sl.registerLazySingleton(() => SignOutUserUseCase(sl()));
    sl.registerLazySingleton(() => DeleteAccountUseCase(sl()));
    sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));

    sl.registerLazySingleton(() => CompleteUserProfileDataStorageUseCase(sl()));

    // Course Use Cases
    sl.registerLazySingleton(() => GetUserCoursesUseCase(sl()));
    sl.registerLazySingleton(() => GetAllCoursesUseCase(sl()));
    sl.registerLazySingleton(() => GetDepartmentCoursesUseCase(sl()));

    // Blocs
    // Auth BLoC
    sl.registerFactory(
      () => AuthBloc(
        getCurrentUserUseCase: sl(),
        signInUserUseCase: sl(),
        signUpUserUseCase: sl(),
        signOutUserUseCase: sl(),
        completeUserProfileDataStorageUseCase: sl(),
      ),
    );

    // Course BLoC
    sl.registerFactory(
      () => CourseBloc(
        getUserCoursesUseCase: sl(),
        getAllCoursesUseCase: sl(),
        getDepartmentCoursesUseCase: sl(),
      ),
    );

    sl.registerFactory(() => HomeController());

    // Study BLoC
    sl.registerFactory(() => StudyBloc(studyRepository: sl()));
  } finally {
    // Stop the trace when done
    try {
      await trace?.stop();
    } catch (_) {}
  }
}
