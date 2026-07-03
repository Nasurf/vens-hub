import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';

import '../../../core/di/injection_container.dart' as di; // Import AppException

class SignInController extends GetxController {
  // Dependencies
  final _authRepo = di.sl<AuthRepository>();

  // Form controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // State
  final RxBool isLoading = false.obs;
  final RxBool passwordVisible = false.obs;
  final formKey = GlobalKey<FormState>();

  void togglePasswordVisibility() {
    passwordVisible.value = !passwordVisible.value;
  }

  Future<void> signIn() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      await _authRepo.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Clear fields on success
      emailController.clear();
      passwordController.clear();
    } on AuthenticationException catch (e) {
      // Changed to AuthenticationException
      passwordController.clear(); // Clear password for security
      // The new AuthenticationException and its subtypes carry the message directly.
      // The specific messages are now set in the service layer.
      throw e.message; // Rethrow the message from the caught exception
    } catch (e) {
      passwordController.clear();
      // For unknown errors, provide a generic message or rethrow if appropriate.
      // To keep it simple for legacy, throw a generic message.
      throw 'An unexpected error occurred during sign in. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
