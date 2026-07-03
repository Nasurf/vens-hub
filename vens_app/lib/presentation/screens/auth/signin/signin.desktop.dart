import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_event.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_state.dart';
import 'package:vens_hub/presentation/widgets/common/utility_widgets.dart';
import 'package:vens_hub/presentation/widgets/common/gradient_hero_panel.dart';
import 'package:vens_hub/presentation/widgets/common/themed_logo.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

/// A desktop-optimised sign-in screen inspired by the reference design the
/// user provided.  It features:
///  • Social sign-in (Google)
///  • Traditional e-mail/password sign-in
///  • A vertical divider that visually separates the marketing panel from the
///    authentication form ("that edge stuff" mentioned by the user).
class DesktopSignIn extends StatefulWidget {
  const DesktopSignIn({super.key});

  @override
  State<DesktopSignIn> createState() => _DesktopSignInState();
}

class _DesktopSignInState extends State<DesktopSignIn> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn(BuildContext context) {
    BlocProvider.of<AuthBloc>(context).add(AuthGoogleSignInRequested());
  }

  void _handleEmailSignIn(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    BlocProvider.of<AuthBloc>(context).add(
      AuthSignInRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
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
          } else if (state is AuthFailureState) {
            String errorMessage = state.message;

            // Show user-friendly message for Google sign-in without account
            if (state.message.contains('No account found with this email')) {
              errorMessage =
                  'Failed to sign in because you haven\'t created an account yet. Create an account to proceed.';
            }

            AppNotifier.error(context: context, message: errorMessage);
          }
        },
        child: Row(
          children: [
            // ===== Left panel – authentication form =====
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  // Back Button
                  Positioned(
                    top: 24,
                    left: 24,
                    child: IconButton(
                      onPressed: () => Get.offAllNamed(AppRoutes.onBoarding),
                      icon: Icon(
                        Icons.arrow_back,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(48),
                      child: SizedBox(
                        width: 420,
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: ThemedLogo(height: 40),
                              ),
                              const SizedBox(height: 60),

                              Text(
                                'Welcome back',
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please enter your details to sign in.',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ===== Email field =====
                              Text(
                                'Email Address',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              utilityFormItemLarge(
                                context,
                                'engineer@example.com',
                                keyboardType: TextInputType.emailAddress,
                                obscureText: false,
                                prefixIcon: Icon(
                                  Icons.mail_outline,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@') ||
                                      !value.contains('.')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                                formItemContoller: _emailController,
                              ),
                              const SizedBox(height: 20),

                              // ===== Password field =====
                              Text(
                                'Password',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              utilityFormItemLarge(
                                context,
                                '••••••••',
                                isPassword: true,
                                obscureText: !_passwordVisible,
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                                formItemContoller: _passwordController,
                                onTogglePassword: () {
                                  setState(
                                    () => _passwordVisible = !_passwordVisible,
                                  );
                                },
                                keyboardType: TextInputType.visiblePassword,
                              ),
                              const SizedBox(height: 16),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed:
                                      () =>
                                          Get.toNamed(AppRoutes.forgotPassword),
                                  child: Text(
                                    'Forgot password?',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ===== Email login button =====
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final colorScheme =
                                      Theme.of(context).colorScheme;
                                  final textTheme = Theme.of(context).textTheme;
                                  final bool isLoading =
                                      state is AuthSignInLoading;
                                  return SizedBox(
                                    height: 50,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed:
                                          isLoading
                                              ? null
                                              : () =>
                                                  _handleEmailSignIn(context),
                                      child:
                                          isLoading
                                              ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 3.0,
                                                    ),
                                              )
                                              : Text(
                                                'Sign in',
                                                style: textTheme.titleMedium
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme.onPrimary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),

                              // ===== Divider with text "Or continue with" =====
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // ===== Social buttons (only Google for now) =====
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final colorScheme =
                                      Theme.of(context).colorScheme;
                                  final bool isLoading =
                                      state is AuthGoogleSignInLoading;
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        side: BorderSide(
                                          color: colorScheme.outlineVariant,
                                        ),
                                        backgroundColor: colorScheme.surface,
                                        foregroundColor: colorScheme.onSurface,
                                      ),
                                      onPressed:
                                          isLoading
                                              ? null
                                              : () =>
                                                  _handleGoogleSignIn(context),
                                      child:
                                          isLoading
                                              ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.4,
                                                    ),
                                              )
                                              : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SvgPicture.asset(
                                                    'assets/svg/google_g_logo.svg',
                                                    height: 20,
                                                    width: 20,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    'Continue with Google',
                                                  ),
                                                ],
                                              ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 32),

                              // ===== Register link =====
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Get.toNamed(AppRoutes.signUp),
                                    child: Text(
                                      'Create account',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== Vertical divider ("edge stuff") =====
            Container(
              width: 1,
              height: double.infinity,
              color: colorScheme.outlineVariant,
            ),

            // ===== Right panel – replicate onboarding hero =====
            const Expanded(flex: 6, child: GradientHeroPanel()),
          ],
        ),
      ),
    );
  }
}
