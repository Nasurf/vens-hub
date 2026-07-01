import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Re-add Bloc for context.read
import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart'; // Re-add AuthBloc
import 'package:vens_hub/presentation/blocs/auth/auth_event.dart'; // Re-add AuthEvent
// GetX AuthenticationRepository is removed from here
// RegistrationOnboardingModel is not directly used here now, AuthSignUpRequested takes individual fields
// AppRouter and Routes are used by UI listening to AuthBloc state, not directly by controller for this action
// EmailVerificationScreenArgs is used by UI listening to AuthBloc state

class SignUpController extends GetxController {
  // final AuthenticationRepository _authRepository = Get.find(); // Removed

  // UI and Step Management
  final pageController = PageController();
  final totalSteps = 4;
  final RxInt currentStep = 0.obs;

  // Form Keys
  final formKey1 = GlobalKey<FormState>(); // Names
  final formKey4 = GlobalKey<FormState>(); // Credentials

  // Form Controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // State
  final RxString selectedLevel = ''.obs;
  final RxString selectedDepartment = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool passwordVisible = false.obs;
  final RxBool confirmPasswordVisible = false.obs;

  // Data for UI Selection Cards
  final Map<String, IconData> levelOptions = {
    '100 Lvl': Icons.looks_one_outlined,
    '200 Lvl': Icons.looks_two_outlined,
    '300 Lvl': Icons.looks_3_outlined,
    '400 Lvl': Icons.looks_4_outlined,
    '500 Lvl': Icons.looks_5_outlined,
  };
  final Map<String, IconData> departmentOptions = {
    'Aeronautics Engineering': Icons.flight_takeoff,
    'Biomedical Engineering': Icons.biotech,
    'Chemical Engineering': Icons.science_outlined,
    'Civil Engineering': Icons.maps_home_work_outlined,
    'Computer Engineering': Icons.computer,
    'Electrical Engineering': Icons.electrical_services_outlined,
    'Mechanical Engineering': Icons.settings_outlined,
    'Mechatronics Engineering': Icons.memory,
    'Petroleum Engineering': Icons.local_gas_station_outlined,
  };

  // Map for converting UI department names to Firestore collection codes
  final Map<String, String> _departmentNameToCodeMap = {
    'Electrical Engineering': 'EEE',
    'Mechanical Engineering': 'MEE',
    'Mechatronics Engineering': 'MCT',
    'Computer Engineering': 'COE',
    'Chemical Engineering': 'CHE',
    'Biomedical Engineering': 'BME',
    'Aeronautics Engineering': 'AAE',
    'Civil Engineering': 'CVE',
    'Petroleum Engineering': 'PTE',
  };

  @override
  void onInit() {
    super.onInit();
    // Add a listener to sync the current step with the PageView's page.
    // This is more robust than relying on onPageChanged callbacks.
    pageController.addListener(() {
      final page = pageController.page?.round() ?? currentStep.value;
      if (currentStep.value != page) {
        currentStep.value = page;
        update(); // Notify GetBuilder listeners of the change
      }
    });

    // These listeners correctly call update() to rebuild the GetBuilder.
    firstNameController.addListener(() => update());
    lastNameController.addListener(() => update());
    emailController.addListener(() => update());
    passwordController.addListener(() => update());
    confirmPasswordController.addListener(() => update());
  }

  @override
  void onClose() {
    pageController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  // MODIFIED: This getter is now "pure" and does not call .validate()
  bool get canProceed {
    switch (currentStep.value) {
      case 0:
        return firstNameController.text.trim().isNotEmpty &&
            lastNameController.text.trim().isNotEmpty;
      case 1:
        return selectedLevel.value.isNotEmpty;
      case 2:
        return selectedDepartment.value.isNotEmpty;
      case 3:
        // This is a "silent" check. It checks the conditions without
        // triggering a UI update on the FormFields themselves.
        return GetUtils.isEmail(emailController.text.trim()) &&
            passwordController.text.trim().length >= 6 &&
            passwordController.text.trim() ==
                confirmPasswordController.text.trim();
      default:
        return false;
    }
  }

  void selectLevel(String level) {
    selectedLevel.value = level;
    update(); // Manually trigger an update for GetBuilder
  }

  void selectDepartment(String department) {
    selectedDepartment.value = department;
    update(); // Manually trigger an update for GetBuilder
  }

  void togglePasswordVisibility() =>
      passwordVisible.value = !passwordVisible.value;
  void toggleConfirmPasswordVisibility() =>
      confirmPasswordVisible.value = !confirmPasswordVisible.value;

  void nextStep() {
    Get.focusScope?.unfocus();

    // Step-specific validation.
    // For the name step, trigger form validation.
    if (currentStep.value == 0) {
      if (!formKey1.currentState!.validate()) {
        return; // Stop if the form is invalid.
      }
    }

    // For other steps (1 and 2), the `canProceed` getter already ensures
    // a selection has been made, so the button would be disabled otherwise.
    // No need for extra validation here.

    // Proceed to the next page if we are not on the last step.
    if (currentStep.value < totalSteps - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void previousStep() {
    Get.focusScope?.unfocus();
    pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // MODIFIED: The .validate() call is now correctly placed here.
  void completeSignUp(BuildContext context) {
    Get.focusScope?.unfocus();

    // Call .validate() here, as part of the user's explicit action.
    // This is the correct place to trigger UI updates for form errors.
    if (!formKey4.currentState!.validate()) {
      return; // If validation fails, stop execution.
    }

    final String departmentFullName = selectedDepartment.value;
    final String? departmentCode = _departmentNameToCodeMap[departmentFullName];

    if (departmentCode == null) {
      AppNotifier.error(
        context: Get.context,
        title: 'Error',
        message: 'An internal error occurred with the department selection.',
      );
      return;
    }

    final String levelCode = selectedLevel.value.replaceAll(' Lvl', '').trim();

    // isLoading state will be handled by AuthBloc (AuthLoading state)
    // isLoading.value = true;

    context.read<AuthBloc>().add(
      AuthSignUpRequested(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        level: levelCode,
        department: departmentCode,
      ),
    );
    // Navigation to EmailVerificationScreen will be handled by the UI
    // listening to AuthBloc state changes (specifically AuthVerificationEmailSent state).
  }
}
