import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/core/theme/app_colors.dart';
import 'package:vens_hub/presentation/widgets/common/gradient_hero_panel.dart';
import 'package:vens_hub/presentation/widgets/common/utility_widgets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DesktopForgotPassword extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSendLink;
  final VoidCallback onResetPassword;
  final bool isResetMode;

  const DesktopForgotPassword({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSendLink,
    required this.onResetPassword,
    required this.isResetMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // Left Side - Form
          Expanded(
            flex: 5,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      TextButton.icon(
                        onPressed: () => AppRouter.navigateTo(AppRoutes.signIn),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        label: const Text("Back to Login"),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark
                                  ? AppColors.onSurfaceVariantDark
                                  : AppColors.onSurfaceVariantLight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Icon & Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isResetMode
                              ? Icons.lock_reset_rounded
                              : Icons.mark_email_read_rounded,
                          size: 32,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        isResetMode ? "Reset Password" : "Forgot Password?",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              isDark
                                  ? AppColors.onSurfaceDark
                                  : AppColors.onSurfaceLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isResetMode
                            ? "Enter your new password below to secure your account."
                            : "Don't worry! It happens. Please enter the email associated with your account.",
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color:
                              isDark
                                  ? AppColors.onSurfaceVariantDark
                                  : AppColors.onSurfaceVariantLight,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Form Fields
                      if (isResetMode) ...[
                        utilityFormItemLarge(
                          context,
                          "Enter your new password",
                          formItemContoller: passwordController,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        utilityFormItemLarge(
                          context,
                          "Re-enter your new password",
                          formItemContoller: confirmPasswordController,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          isPassword: true,
                          validator: (value) {
                            if (value != passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        utilityFormItemLarge(
                          context,
                          "Enter your email",
                          formItemContoller: emailController,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!GetUtils.isEmail(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : (isResetMode
                                      ? onResetPassword
                                      : onSendLink),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          child:
                              isLoading
                                  ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    isResetMode
                                        ? "Reset Password"
                                        : "Send Reset Link",
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Right Side - Hero Panel
          const Expanded(
            flex: 4,
            child: GradientHeroPanel(
              title: "Secure Your Account",
              subtitle:
                  "We take security seriously. Follow the steps to regain access to your Engineering Hub account.",
              imagePath: "assets/images/forgot_password_illustration.png",
            ),
          ),
        ],
      ),
    );
  }
}
