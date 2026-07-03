import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_event.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_state.dart';
import 'package:vens_hub/presentation/widgets/common/utility_widgets.dart';
import 'package:vens_hub/presentation/widgets/common/themed_logo.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

class MobileSignIn extends StatefulWidget {
  const MobileSignIn({super.key});

  @override
  State<MobileSignIn> createState() => _MobileSignInState();
}

class _MobileSignInState extends State<MobileSignIn> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthSignInRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ),
    );
  }

  void _handleGoogleSignIn() {
    context.read<AuthBloc>().add(AuthGoogleSignInRequested());
  }

  void _handleForgotPassword() {
    AppRouter.navigateTo(AppRoutes.forgotPassword);
  }

  // AppBar back button moved to Scaffold.appBar

  Widget _buildGoogleButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final bool isLoading = state is AuthGoogleSignInLoading;
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              side: BorderSide(color: colorScheme.outline),
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
            ),
            onPressed: isLoading ? null : _handleGoogleSignIn,
            child:
                isLoading
                    ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/google_g_logo.svg',
                          height: 20,
                          width: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text('Continue with Google'),
                      ],
                    ),
          ),
        );
      },
    );
  }

  Widget _buildOrDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outline)),
        const SizedBox(width: 8),
        Text(
          'OR',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface.withAlpha((0.6 * 255).round()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: colorScheme.outline)),
      ],
    );
  }

  Widget _textForm() {
    return Column(
      children: [
        utilityFormItemLarge(
          context,
          'Email',
          keyboardType: TextInputType.emailAddress,
          obscureText: false,
          prefixIcon: Icon(
            Icons.mail_outline,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@') || !value.contains('.')) {
              return 'Please enter a valid email';
            }
            return null;
          },
          formItemContoller: _emailController,
        ),
        const SizedBox(height: 24),
        utilityFormItemLarge(
          context,
          'Password',
          keyboardType: TextInputType.visiblePassword,
          isPassword: true,
          obscureText: !_passwordVisible,
          prefixIcon: Icon(
            Icons.lock_outline,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          onTogglePassword:
              () => setState(() => _passwordVisible = !_passwordVisible),
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final bool isLoading = state is AuthSignInLoading;
        return SizedBox(
          height: 55,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 12),
              disabledBackgroundColor: colorScheme.primary.withAlpha(
                (0.5 * 255).round(),
              ),
              disabledForegroundColor: colorScheme.onPrimary.withAlpha(
                (0.7 * 255).round(),
              ),
            ),
            onPressed: isLoading ? null : _handleSignIn,
            child:
                isLoading
                    ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3.0,
                      ),
                    )
                    : Text(
                      'Log In',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          onPressed: () => AppRouter.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color:
                Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth;
              final double formWidth = maxWidth > 520 ? 480.0 : double.infinity;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: formWidth),
                    child: BlocListener<AuthBloc, AuthState>(
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
                          if (state.message.contains(
                            'No account found with this email',
                          )) {
                            errorMessage =
                                'Failed to sign in because you haven\'t created an account yet. Create an account to proceed.';
                          }

                          AppNotifier.error(
                            context: context,
                            message: errorMessage,
                          );
                        }
                      },
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            const Center(child: ThemedLogo(height: 56)),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome back',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Log in to continue your learning journey",
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Card(
                              elevation: 0,
                              color: colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildGoogleButton(context),
                                    const SizedBox(height: 16),
                                    _buildOrDivider(context),
                                    const SizedBox(height: 16),
                                    _textForm(),
                                    const SizedBox(height: 20),
                                    _buildLoginButton(context),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.center,
                                      child: TextButton(
                                        onPressed: _handleForgotPassword,
                                        style: TextButton.styleFrom(
                                          foregroundColor: colorScheme.primary,
                                        ),
                                        child: const Text('Forgot password?'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Get.toNamed(AppRoutes.signUp),
                                  style: TextButton.styleFrom(
                                    foregroundColor: colorScheme.primary,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Create one'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
