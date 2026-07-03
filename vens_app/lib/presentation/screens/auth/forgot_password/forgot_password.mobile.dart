import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/presentation/widgets/common/utility_widgets.dart';

class MobileForgotPassword extends StatefulWidget {
  final bool isResetMode;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const MobileForgotPassword({
    super.key,
    required this.isResetMode,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  State<MobileForgotPassword> createState() => _MobileForgotPasswordState();
}

class _MobileForgotPasswordState extends State<MobileForgotPassword> {
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Get.offAllNamed(AppRoutes.onBoarding),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        // Header Icon
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isResetMode
                                  ? Icons.lock_reset_rounded
                                  : Icons.mark_email_read_rounded,
                              size: 40,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          widget.isResetMode
                              ? 'Reset Password'
                              : 'Forgot Password?',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.isResetMode
                              ? 'Enter your new password below to secure your account.'
                              : 'Don\'t worry! It happens. Please enter the email associated with your account.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Form Fields
                        if (!widget.isResetMode) ...[
                          utilityFormItemLarge(
                            context,
                            'Email Address',
                            keyboardType: TextInputType.emailAddress,
                            obscureText: false,
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!GetUtils.isEmail(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            formItemContoller: widget.emailController,
                          ),
                        ] else ...[
                          utilityFormItemLarge(
                            context,
                            'New Password',
                            keyboardType: TextInputType.visiblePassword,
                            isPassword: true,
                            obscureText: !_passwordVisible,
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: colorScheme.onSurfaceVariant,
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
                            formItemContoller: widget.passwordController,
                            onTogglePassword:
                                () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                          ),
                          const SizedBox(height: 20),
                          utilityFormItemLarge(
                            context,
                            'Confirm Password',
                            keyboardType: TextInputType.visiblePassword,
                            isPassword: true,
                            obscureText: !_confirmPasswordVisible,
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != widget.passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            formItemContoller: widget.confirmPasswordController,
                            onTogglePassword:
                                () => setState(
                                  () =>
                                      _confirmPasswordVisible =
                                          !_confirmPasswordVisible,
                                ),
                          ),
                        ],
                        const SizedBox(height: 32),

                        // Action Button
                        SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed:
                                widget.isSubmitting
                                    ? null
                                    : () {
                                      if (_formKey.currentState!.validate()) {
                                        widget.onSubmit();
                                      }
                                    },
                            child:
                                widget.isSubmitting
                                    ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: colorScheme.onPrimary,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                    : Text(
                                      widget.isResetMode
                                          ? 'Reset Password'
                                          : 'Send Reset Link',
                                    ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Back to Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Remember your password? ",
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  () => Get.offAllNamed(AppRoutes.signIn),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Log in'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
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
