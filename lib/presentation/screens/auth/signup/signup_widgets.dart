import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/blocs/auth/sign_up_controller.dart';

// ============== REUSABLE FORM STEP WIDGETS ==============

class NameStepContent extends StatelessWidget {
  const NameStepContent({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SignUpController>();
    return Form(
      key: controller.formKey1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            icon: Icons.person_outline,
            title: "Hey! What should we call you?",
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: controller.firstNameController,
            decoration: const InputDecoration(labelText: "First name"),
            validator:
                (val) => val == null || val.trim().isEmpty ? "Required" : null,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller.lastNameController,
            decoration: const InputDecoration(labelText: "Last name"),
            validator:
                (val) => val == null || val.trim().isEmpty ? "Required" : null,
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }
}

class LevelStepContent extends StatelessWidget {
  const LevelStepContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            icon: Icons.school_outlined,
            title: "What level are you in?",
          ),
          const SizedBox(height: 32),
          GetBuilder<SignUpController>(
            builder:
                (ctrl) => Column(
                  children:
                      ctrl.levelOptions.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SelectionCard(
                            title: entry.key,
                            icon: entry.value,
                            isSelected: ctrl.selectedLevel.value == entry.key,
                            onTap: () => ctrl.selectLevel(entry.key),
                          ),
                        );
                      }).toList(),
                ),
          ),
        ],
      ),
    );
  }
}

class DepartmentStepContent extends StatelessWidget {
  const DepartmentStepContent({super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            icon: Icons.business_center_outlined,
            title: "Which department are you in?",
          ),
          const SizedBox(height: 32),
          GetBuilder<SignUpController>(
            builder:
                (ctrl) => Column(
                  children:
                      ctrl.departmentOptions.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SelectionCard(
                            title: entry.key,
                            icon: entry.value,
                            isSelected:
                                ctrl.selectedDepartment.value == entry.key,
                            onTap: () => ctrl.selectDepartment(entry.key),
                          ),
                        );
                      }).toList(),
                ),
          ),
        ],
      ),
    );
  }
}

class CredentialsStepContent extends StatelessWidget {
  const CredentialsStepContent({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SignUpController>();
    return SingleChildScrollView(
      child: Form(
        key: controller.formKey4,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepHeader(
              icon: Icons.lock_outline,
              title: "Last step, set up your login.",
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: controller.emailController,
              decoration: const InputDecoration(labelText: "Email address"),
              validator:
                  (val) =>
                      GetUtils.isEmail(val ?? "")
                          ? null
                          : "Enter a valid email",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Obx(
              () => TextFormField(
                controller: controller.passwordController,
                obscureText: !controller.passwordVisible.value,
                decoration: InputDecoration(
                  labelText: "Create password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.passwordVisible.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: controller.togglePasswordVisibility,
                  ),
                ),
                validator:
                    (val) =>
                        (val?.length ?? 0) < 6
                            ? "Password must be 6+ characters"
                            : null,
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => TextFormField(
                controller: controller.confirmPasswordController,
                obscureText: !controller.confirmPasswordVisible.value,
                decoration: InputDecoration(
                  labelText: "Confirm password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.confirmPasswordVisible.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: controller.toggleConfirmPasswordVisibility,
                  ),
                ),
                validator:
                    (val) =>
                        val != controller.passwordController.text
                            ? "Passwords do not match"
                            : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============== CUSTOM WIDGETS ==============

class StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const StepHeader({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1.5,
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                topLeft: Radius.circular(20),
              ),
            ),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SelectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          border: Border.all(
            color:
                isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
