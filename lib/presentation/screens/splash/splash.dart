// lib/presentation/screens/splash/splash.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart'; // For navigation
import 'package:vens_hub/core/router/routes.dart'; // For AppRoutes
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_state.dart';

class SplashScreen extends StatelessWidget {
  // Can be StatelessWidget now
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          Get.offAllNamed(
            AppRoutes.main,
          ); // Navigate to home for authenticated and verified users
        } else if (state is AuthAwaitingVerification) {
          Get.offAllNamed(
            AppRoutes.emailVerification,
          ); // Navigate to email verification for unverified users
        } else if (state is Unauthenticated || state is AuthFailureState) {
          Get.offAllNamed(
            AppRoutes.onBoarding,
          ); // Navigate to onboarding for unauthenticated users
        }
        // AuthLoading and AuthInitial are handled by showing the splash screen itself
      },
      child: Scaffold(
        body: Center(
          child: SpinKitCubeGrid(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
