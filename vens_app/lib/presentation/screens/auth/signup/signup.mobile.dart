import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_state.dart';
import 'package:vens_hub/presentation/blocs/auth/sign_up_controller.dart';
import 'package:vens_hub/presentation/screens/auth/signup/signup_widgets.dart';

class MobileSignUpScreen extends StatelessWidget {
  const MobileSignUpScreen({super.key});

  // The form steps now use the public, shared widgets.
  final List<Widget> _formSteps = const [
    NameStepContent(),
    DepartmentStepContent(),
    CourseSelectionStepContent(),
    CredentialsStepContent(),
  ];
  @override
  Widget build(BuildContext context) {
    // Initialize the controller using Get.put()
    final controller = Get.put(SignUpController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: Obx(
          () => IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
            onPressed:
                controller.currentStep.value == 0
                    ? () => Get.back()
                    : controller.previousStep,
          ),
        ),
        title: Obx(
          () => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (controller.currentStep.value + 1) / controller.totalSteps,
              backgroundColor: colorScheme.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 8,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            controller.isLoading.value = (state is AuthSignUpLoading);

            if (state is Authenticated) {
              AppNotifier.success(
                context: context,
                title: 'Sign Up Successful',
                message: 'Welcome',
              );
            } else if (state is AuthFailureState) {
              AppNotifier.error(
                context: context,
                title: 'Sign Up Failed',
                message: state.message,
              );
            }
          },
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: controller.pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children:
                              _formSteps
                                  .map(
                                    (step) => Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 520,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24.0,
                                            vertical: 16.0,
                                          ),
                                          child: Card(
                                            elevation: 0,
                                            color:
                                                colorScheme
                                                    .surfaceContainerHighest,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                16.0,
                                              ),
                                              child: SingleChildScrollView(
                                                primary: false,
                                                child: step,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  disabledBackgroundColor: colorScheme.onSurface
                                      .withValues(alpha: 0.12),
                                  disabledForegroundColor: colorScheme.onSurface
                                      .withValues(alpha: 0.38),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  textStyle: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                child: Obx(
                                  () =>
                                      ctrl.isLoading.value
                                          ? const SizedBox(
                                            height: 24.0,
                                            width: 24.0,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3.0,
                                            ),
                                          )
                                          : Text(
                                            isLastStep
                                                ? 'Create Account'
                                                : 'Continue',
                                          ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// The _build...Step methods and custom widgets (StepHeader, SelectionCard)
// have been replaced by the shared widgets in signup_widgets.dart and can be removed.
