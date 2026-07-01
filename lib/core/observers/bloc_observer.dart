import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:vens_hub/core/di/injection_container.dart'; // For sl

class MyObserver extends BlocObserver {
  @override
  void onEvent(Bloc bloc, Object? event) {
    // TODO: implement onEvent
    super.onEvent(bloc, event);
    log("EVENT:${bloc.runtimeType}, ${bloc.state}");
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    log(
      "TRANSITION LOG: ${bloc.runtimeType} $transition",
    ); // Corrected to bloc.runtimeType
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    log(
      "ERROR LOG: ${bloc.runtimeType} Error: $error",
    ); // Corrected to bloc.runtimeType

    // Add Analytics logging
    sl<AnalyticsService>().logError(
      'BLoC Error: ${bloc.runtimeType}', // Description
      error: error,
      stackTrace: stackTrace,
      fatal: false, // BLoC errors might not always be fatal, can be adjusted
    );
  }
}
