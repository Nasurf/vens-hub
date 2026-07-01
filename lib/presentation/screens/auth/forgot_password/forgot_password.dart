import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'forgot_password.desktop.dart';
import 'forgot_password.mobile.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSubmitting = false;
  String? _oobCode;

  @override
  void initState() {
    super.initState();
    // Check for oobCode in URL parameters (for password reset link)
    _oobCode = Get.parameters['oobCode'];
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    try {
      Feedback.forTap(context);
      setState(() => _isSubmitting = true);

      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());

      if (mounted) {
        await AppNotifier.success(
          context: context,
          message:
              'Password reset link sent to ${_emailController.text.trim()}',
        );
        _emailController.clear();
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      if (mounted) {
        await AppNotifier.error(
          context: context,
          message: 'An unexpected error occurred: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_oobCode == null) return;

    try {
      Feedback.forTap(context);
      setState(() => _isSubmitting = true);

      await _auth.confirmPasswordReset(
        code: _oobCode!,
        newPassword: _passwordController.text,
      );

      if (mounted) {
        await AppNotifier.success(
          context: context,
          message: 'Password has been reset successfully. Please log in.',
        );
        // Navigate to login after success
        Get.offAllNamed(AppRoutes.signIn);
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      if (mounted) {
        await AppNotifier.error(
          context: context,
          message: 'An unexpected error occurred: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    if (!mounted) return;
    String message;
    switch (e.code) {
      case 'invalid-email':
        message = 'The email address is not valid.';
        break;
      case 'user-not-found':
        message = 'No user found with that email.';
        break;
      case 'too-many-requests':
        message = 'Too many requests. Try again later.';
        break;
      case 'expired-action-code':
        message = 'The password reset link has expired.';
        break;
      case 'invalid-action-code':
        message =
            'The password reset link is invalid. It may have been used already.';
        break;
      case 'weak-password':
        message = 'The password is too weak.';
        break;
      default:
        message = 'An error occurred: ${e.message}';
        break;
    }
    AppNotifier.error(context: context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final isResetMode = _oobCode != null;

    return AppLayoutBuilder(
      mobile: MobileForgotPassword(
        isResetMode: isResetMode,
        emailController: _emailController,
        passwordController: _passwordController,
        confirmPasswordController: _confirmPasswordController,
        isSubmitting: _isSubmitting,
        onSubmit: isResetMode ? _resetPassword : _sendResetLink,
      ),
      desktop: DesktopForgotPassword(
        emailController: _emailController,
        passwordController: _passwordController,
        confirmPasswordController: _confirmPasswordController,
        isLoading: _isSubmitting,
        onSendLink: _sendResetLink,
        onResetPassword: _resetPassword,
        isResetMode: isResetMode,
      ),
    );
  }
}
