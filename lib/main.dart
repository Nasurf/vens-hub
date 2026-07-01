import 'dart:async';
import 'dart:developer';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vens_hub/data/auth/repositories/auth_repository_impl.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide Transition;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:vens_hub/core/services/storage/r2_storage_service.dart';
import 'package:vens_hub/core/services/local_storage/user_cache_service.dart';
import 'package:vens_hub/core/services/local_storage/cache_clearing_service.dart';
import 'package:vens_hub/domain/repositories/schedule_repository.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/core/observers/bloc_observer.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/study/study_bloc.dart';
import 'package:vens_hub/presentation/blocs/study/pdf_viewer_bloc.dart';
import 'package:vens_hub/core/services/auth/auth_service.dart';
import 'package:vens_hub/core/services/theme/theme_service.dart';
import 'package:vens_hub/core/observers/analytics_observer.dart';
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:vens_hub/core/services/performance/performance_service.dart';
import 'package:vens_hub/core/services/app/privacy_service.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'core/di/injection_container.dart' as di;
import 'core/diagnostics/startup_diagnostics.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_event.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_state.dart';
import 'dart:ui';
import 'core/services/crash_reporting/crashlytics_service.dart';
import 'firebase_options.dart';
import 'package:vens_hub/core/services/notifications/notification_service.dart';
import 'package:vens_hub/core/services/notifications/notification_prefs_service.dart';
import 'package:vens_hub/core/services/app/home_widget_service.dart';
import 'package:vens_hub/core/services/app/widget_intent_service.dart';
import 'package:vens_hub/core/services/notifications/streak_widget_service.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  Bloc.observer = MyObserver();
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final diag = Get.put(StartupDiagnosticsController(), permanent: true);

  await _bootstrapCore(diag);

  diag.start('runApp');
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => di.sl<AuthBloc>()..add(AuthAppStarted()),
        ),
        BlocProvider(create: (_) => di.sl<StudyBloc>()),
        BlocProvider(create: (context) => QuizBloc()),
        BlocProvider(create: (_) => PdfViewerBloc()),
      ],
      child: MyApp(initialRoute: "/"),
    ),
  );
  diag.success('runApp');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _runDeferredStartup(diag);
  });
}

Future<void> _bootstrapCore(StartupDiagnosticsController diag) async {
  diag.start('dotenv');
  await dotenv.load(fileName: "assets/.env");
  diag.success('dotenv');

  diag.start('Firebase.initializeApp');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  diag.success('Firebase.initializeApp');

  if (!kIsWeb) {
    diag.start('FCM.backgroundHandler');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    diag.success('FCM.backgroundHandler');
  } else {
    diag.skip('FCM.backgroundHandler', reason: 'web');
  }

  diag.start('DI.init');
  await di.initDI();
  diag.success('DI.init');

  diag.start('ThemeService.init');
  final themeService = await ThemeService().init();
  Get.put(themeService, permanent: true);
  diag.success('ThemeService.init');

  diag.start('FirestoreService.register');
  final firestoreService = FireStoreServices();
  Get.put(firestoreService);
  diag.success('FirestoreService.register');

  diag.start('ScheduleRepository.prepare');
  if (!Get.isRegistered<ScheduleRepository>()) {
    Get.lazyPut<ScheduleRepository>(() => ScheduleRepository(), fenix: true);
  }
  diag.success('ScheduleRepository.prepare');

  diag.start('NotificationPrefs.init');
  final notifPrefs = await NotificationPrefsService().init();
  Get.put(notifPrefs, permanent: true);
  diag.success('NotificationPrefs.init');

  diag.start('NotificationService.register');
  if (!Get.isRegistered<NotificationService>()) {
    Get.put(NotificationService(), permanent: true);
  }
  diag.success('NotificationService.register');

  diag.start('PrivacyService.register');
  if (!Get.isRegistered<PrivacyService>()) {
    Get.put(PrivacyService(), permanent: true);
    diag.success('PrivacyService.register');
  } else {
    diag.skip('PrivacyService.register', reason: 'already registered');
  }

  diag.start('AuthRepository.register');
  if (!Get.isRegistered<AuthRepository>()) {
    final authRepo = AuthRepositoryImpl(
      authService: di.sl<AuthService>(),
      firestoreService: firestoreService,
      r2StorageService: di.sl<R2StorageService>(),
      userCacheService: di.sl<UserCacheService>(),
      cacheClearingService: di.sl<CacheClearingService>(),
    );
    Get.put<AuthRepository>(authRepo, permanent: true);
  }
  diag.success('AuthRepository.register');

  diag.start('HomeController.register');
  if (!Get.isRegistered<HomeController>()) {
    Get.put(HomeController(), permanent: true);
    diag.success('HomeController.register');
  } else {
    diag.skip('HomeController.register', reason: 'already registered');
  }

  diag.start('HomeScreenWidgetService.register');
  if (!Get.isRegistered<HomeScreenWidgetService>()) {
    Get.put(HomeScreenWidgetService(), permanent: true);
    diag.success('HomeScreenWidgetService.register');
  } else {
    diag.skip('HomeScreenWidgetService.register', reason: 'already registered');
  }

  diag.start('StreakWidgetService.register');
  if (!Get.isRegistered<StreakWidgetService>()) {
    Get.put(StreakWidgetService(), permanent: true);
    diag.success('StreakWidgetService.register');
  } else {
    diag.skip('StreakWidgetService.register', reason: 'already registered');
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (di.sl.isRegistered<CrashlyticsService>()) {
      di.sl<CrashlyticsService>().recordFlutterError(details);
    }
    if (di.sl.isRegistered<AnalyticsService>()) {
      di.sl<AnalyticsService>().logError(
        'Flutter Error: ${details.exception}',
        error: details.exception,
        stackTrace: details.stack,
        fatal: false,
      );
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (di.sl.isRegistered<CrashlyticsService>()) {
      di.sl<CrashlyticsService>().recordError(
        error,
        stack,
        reason: 'PlatformDispatcher.onError',
        fatal: true,
      );
    }
    if (di.sl.isRegistered<AnalyticsService>()) {
      di.sl<AnalyticsService>().logError(
        'Platform Error: $error',
        error: error,
        stackTrace: stack,
        fatal: true,
      );
    }
    return true;
  };
}

void _runDeferredStartup(StartupDiagnosticsController diag) {
  unawaited(_initializeDeferredServices(diag));
}

Future<void> _initializeDeferredServices(
  StartupDiagnosticsController diag,
) async {
  if (!kIsWeb) {
    diag.start('FirebasePerformance.instance');
    try {
      final firebasePerformance = FirebasePerformance.instance;
      if (di.sl.isRegistered<FirebasePerformance>()) {
        di.sl.unregister<FirebasePerformance>();
      }
      di.sl.registerSingleton<FirebasePerformance>(firebasePerformance);
      diag.success('FirebasePerformance.instance');
    } catch (e) {
      diag.fail('FirebasePerformance.instance', e);
    }
  } else {
    diag.skip('FirebasePerformance.instance', reason: 'web');
  }

  diag.start('Analytics.initialize');
  try {
    await di.sl<AnalyticsService>().initialize();
    diag.success('Analytics.initialize');
  } catch (e) {
    diag.fail('Analytics.initialize', e);
  }

  diag.start('Crashlytics.initialize');
  try {
    final crashlyticsService = FirebaseCrashlyticsServiceImpl();
    await crashlyticsService.initialize();
    if (di.sl.isRegistered<CrashlyticsService>()) {
      di.sl.unregister<CrashlyticsService>();
    }
    di.sl.registerSingleton<CrashlyticsService>(crashlyticsService);
    diag.success('Crashlytics.initialize');
  } catch (e) {
    diag.fail('Crashlytics.initialize', e);
  }

  if (!kIsWeb) {
    diag.start('PerformanceService.initialize');
    try {
      final performanceService = FirebasePerformanceServiceImpl();
      await performanceService.initialize();
      if (di.sl.isRegistered<PerformanceService>()) {
        di.sl.unregister<PerformanceService>();
      }
      di.sl.registerSingleton<PerformanceService>(performanceService);
      diag.success('PerformanceService.initialize');
    } catch (e) {
      diag.fail('PerformanceService.initialize', e);
    }
  } else {
    diag.skip('PerformanceService.initialize', reason: 'web');
  }

  if (!kDebugMode) {
    diag.start('AppCheck.activate');
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
        webProvider: ReCaptchaV3Provider(
          '6LfbAGIrAAAAAKKYt2ScGHdAlKhEQO-lAHsiABhB',
        ),
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      diag.success('AppCheck.activate');
    } catch (e) {
      log('Firebase AppCheck initialization error: $e');
      diag.fail('AppCheck.activate', e);
    }
  } else {
    log('App Check disabled in debug mode to avoid rate limiting');
    diag.skip('AppCheck.activate', reason: 'debug mode');
  }

  diag.start('NotificationService.initialize');
  try {
    final notificationService = Get.find<NotificationService>();
    await notificationService.initialize();
    diag.success('NotificationService.initialize');
  } catch (e) {
    diag.fail('NotificationService.initialize', e);
  }

  diag.start('NotificationService.dailyReminders');
  try {
    final prefs = Get.find<NotificationPrefsService>();
    if (prefs.notificationsEnabled.value && prefs.dailyGeneralEnabled.value) {
      await Get.find<NotificationService>().scheduleDailyGeneralReminders();
      diag.success('NotificationService.dailyReminders');
    } else {
      diag.skip(
        'NotificationService.dailyReminders',
        reason: 'disabled by prefs',
      );
    }
  } catch (e) {
    diag.fail('NotificationService.dailyReminders', e);
  }

  diag.start('HomeWidget.update');
  try {
    if (Get.isRegistered<ScheduleRepository>()) {
      final scheduleRepo = Get.find<ScheduleRepository>();
      await scheduleRepo.ensureInitialized();
    }

    final homeWidgetService = Get.find<HomeScreenWidgetService>();
    await homeWidgetService.updateWithNextClass();
    homeWidgetService.startAutoUpdateIfPossible();
    diag.success('HomeWidget.update');
  } catch (e) {
    log('HomeWidget initialization error: $e');
    diag.fail('HomeWidget.update', e);
  }

  diag.start('StreakWidget.update');
  try {
    final streakWidgetService = Get.find<StreakWidgetService>();
    await streakWidgetService.updateStreakWidget();
    streakWidgetService.startAutoUpdateIfPossible();
    diag.success('StreakWidget.update');
  } catch (e) {
    log('StreakWidget initialization error: $e');
    diag.fail('StreakWidget.update', e);
  }

  diag.start('intl.initializeDateFormatting');
  try {
    await initializeDateFormatting();
    diag.success('intl.initializeDateFormatting');
  } catch (e) {
    log('initializeDateFormatting failed: $e');
    diag.fail('intl.initializeDateFormatting', e);
  }
}

class MyApp extends StatefulWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    di.sl<AnalyticsService>().logAppLifecycle(
      event: 'app_launched',
      sessionData: {'initial_route': widget.initialRoute},
    );

    final notificationService = Get.find<NotificationService>();
    if (Get.find<NotificationPrefsService>().notificationsEnabled.value &&
        Get.find<NotificationPrefsService>().classRemindersEnabled.value) {
      notificationService.scheduleTodayClassReminders();
    }

    WidgetIntentService.handleWidgetIntent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    try {
      if (Get.isRegistered<HomeScreenWidgetService>()) {
        final homeWidgetService = Get.find<HomeScreenWidgetService>();
        homeWidgetService.dispose();
      }
    } catch (e) {
      log('MyApp: Error disposing HomeScreenWidgetService: $e');
    }

    try {
      if (Get.isRegistered<StreakWidgetService>()) {
        final streakWidgetService = Get.find<StreakWidgetService>();
        streakWidgetService.dispose();
      }
    } catch (e) {
      log('MyApp: Error disposing StreakWidgetService: $e');
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    String eventName;
    switch (state) {
      case AppLifecycleState.resumed:
        eventName = 'app_resumed';
        final prefs = Get.find<NotificationPrefsService>();
        if (prefs.notificationsEnabled.value &&
            prefs.classRemindersEnabled.value) {
          Get.find<NotificationService>().scheduleTodayClassReminders();
        }
        WidgetIntentService.handleAppResume();
        break;
      case AppLifecycleState.paused:
        eventName = 'app_paused';
        break;
      case AppLifecycleState.detached:
        eventName = 'app_detached';
        break;
      case AppLifecycleState.inactive:
        eventName = 'app_inactive';
        break;
      case AppLifecycleState.hidden:
        eventName = 'app_hidden';
        break;
    }

    di.sl<AnalyticsService>().logAppLifecycle(
      event: eventName,
      sessionData: {'lifecycle_state': state.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (state is Authenticated) {
            Get.offAllNamed(AppRoutes.main);
          } else if (state is AuthAwaitingProfileCompletion) {
            Get.offAllNamed(
              AppRoutes.completeProfile,
              arguments: {
                'userId': state.userId,
                'email': state.email,
                'firstName': state.firstName,
                'lastName': state.lastName,
              },
            );
          } else if (state is AuthAwaitingVerification) {
            Get.offAllNamed(AppRoutes.emailVerification);
          } else if (state is Unauthenticated) {
            Get.offAllNamed(AppRoutes.onBoarding);
          }
        });
      },
      child: Obx(
        () => GetMaterialApp(
          debugShowCheckedModeBanner: false,
          defaultTransition: Transition.native,
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                if (kIsWeb && kDebugMode)
                  Overlay(
                    initialEntries: [
                      OverlayEntry(
                        builder: (_) => const StartupDiagnosticsOverlay(),
                      ),
                    ],
                  ),
              ],
            );
          },
          title: 'Vens Hub',
          navigatorObservers: [FirebaseAnalyticsObserver()],
          initialRoute: widget.initialRoute,
          getPages: AppRouter.routes,
          themeMode: themeService.getAppThemeMode(),
          theme: themeService.getLightThemeData(),
          darkTheme: themeService.getDarkThemeData(),
        ),
      ),
    );
  }
}
