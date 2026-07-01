import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_state.dart';
import 'package:vens_hub/presentation/blocs/auth/sign_up_controller.dart';
import 'package:vens_hub/presentation/screens/auth/signup/signup_widgets.dart';

/// A desktop-optimized sign-up screen with a two-panel layout.
/// It features a persistent progress panel on the left and the form steps on the right.
class DesktopSignUpScreen extends StatelessWidget {
  const DesktopSignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the controller. GetX will ensure only one instance is created.
    final controller = Get.put(SignUpController());
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: BlocListener<AuthBloc, AuthState>(
        // The BlocListener can wrap the whole page
        listener: (context, state) {
          controller.isLoading.value = (state is AuthSignUpLoading);

          if (state is Authenticated) {
            Get.offAllNamed(AppRoutes.main);
          } else if (state is AuthFailureState) {
            AppNotifier.error(
              context: context,
              title: 'Sign Up Failed',
              message: state.message,
            );
          }
        },
        child: Row(
          children: [
            // Left Panel: Progress and Navigation
            Expanded(flex: 3, child: _ProgressPanel(controller: controller)),
            // Right Panel: Form Content
            Expanded(flex: 5, child: _FormPanel(controller: controller)),
          ],
        ),
      ),
    );
  }
}

// ============== WIDGETS FOR THE DESKTOP LAYOUT ==============

/// The left panel displaying the sign-up steps and progress.
class _ProgressPanel extends StatelessWidget {
  final SignUpController controller;

  const _ProgressPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const stepTitles = [
      "Your Name",
      "Your Level",
      "Your Department",
      "Your Credentials",
    ];

    return Container(
      color: colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back navigation
            Obx(
              () => Visibility(
                visible: controller.currentStep.value > 0,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: BackButton(
                  onPressed: controller.previousStep,
                  color:
                      colorScheme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "Create Account",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Follow the steps to set up your new account.",
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            // Vertical step indicator
            Obx(
              () => Column(
                children: List.generate(stepTitles.length, (index) {
                  return _StepIndicator(
                    stepNumber: index + 1,
                    title: stepTitles[index],
                    isCurrent: controller.currentStep.value == index,
                    isCompleted: controller.currentStep.value > index,
                  );
                }),
              ),
            ),
            const Spacer(),

            TextButton(
              onPressed: () => Get.offAllNamed(AppRoutes.signIn),
              child: const Text("Already have an account? Sign In"),
            ),
          ],
        ),
      ),
    );
  }
}

/// The right panel containing the PageView with the form steps.
class _FormPanel extends StatelessWidget {
  final SignUpController controller;

  const _FormPanel({required this.controller});

  // The form steps now use the public, shared widgets.
  final List<Widget> _formSteps = const [
    NameStepContent(),
    LevelStepContent(),
    DepartmentStepContent(),
    CredentialsStepContent(),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 40.0),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: PageView(
                    controller: controller.pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _formSteps,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action button
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: GetBuilder<SignUpController>(
                builder: (ctrl) {
                  final isLastStep =
                      ctrl.currentStep.value == ctrl.totalSteps - 1;
                  return SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed:
                          (ctrl.isLoading.value || !ctrl.canProceed)
                              ? null
                              : () =>
                                  isLastStep
                                      ? ctrl.completeSignUp(context)
                                      : ctrl.nextStep(),
                      style: ElevatedButton.styleFrom(
                        // Use theme colors for consistency
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        disabledBackgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.12),
                        disabledForegroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Obx(
                        () =>
                            ctrl.isLoading.value
                                ? SizedBox(
                                  height: 24.0,
                                  width: 24.0,
                                  child: CircularProgressIndicator(
                                    // Use the foreground color from the button's style
                                    strokeWidth: 3.0,
                                  ),
                                )
                                : Text(
                                  isLastStep ? 'Create Account' : 'Continue',
                                ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A visual indicator for a single step in the progress panel.
class _StepIndicator extends StatelessWidget {
  final int stepNumber;
  final String title;
  final bool isCurrent;
  final bool isCompleted;

  const _StepIndicator({
    required this.stepNumber,
    required this.title,
    required this.isCurrent,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color circleColor;
    Color textColor;
    FontWeight fontWeight;
    Widget circleChild;

    if (isCompleted) {
      circleColor = colorScheme.primary;
      textColor = colorScheme.onSurfaceVariant;
      fontWeight = FontWeight.normal;
      circleChild = Icon(Icons.check, color: colorScheme.onPrimary, size: 16);
    } else if (isCurrent) {
      circleColor = colorScheme.primaryContainer;
      textColor = colorScheme.onPrimaryContainer;
      fontWeight = FontWeight.bold;
      circleChild = Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
        ),
      );
    } else {
      circleColor = colorScheme.surfaceContainerHighest;
      textColor = colorScheme.onSurfaceVariant;
      fontWeight = FontWeight.normal;
      circleChild = Container();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: circleChild,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: fontWeight,
            ),
          ),
        ],
      ),
    );
  }
}

// ============== REUSABLE FORM STEP WIDGETS ==============
// These widgets have been moved to lib/presentation/screens/auth/signup/signup_widgets.dart
// to be shared with the mobile layout. This section can be removed.
