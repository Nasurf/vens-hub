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

/// Department selection step: pick your engineering department.
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
                      ctrl.departments.map((dept) {
                        final name = dept['name'] as String;
                        final code = dept['code'] as String;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SelectionCard(
                            title: name,
                            icon: _deptIcon(code),
                            isSelected: ctrl.selectedDepartmentCode.value == code,
                            onTap: () => ctrl.selectDepartment(code, name),
                          ),
                        );
                      }).toList(),
                ),
          ),
        ],
      ),
    );
  }

  IconData _deptIcon(String code) {
    switch (code) {
      case 'AER': return Icons.flight_takeoff;
      case 'BIO': return Icons.biotech;
      case 'CHE': return Icons.science_outlined;
      case 'CIV': return Icons.maps_home_work_outlined;
      case 'COM': return Icons.computer;
      case 'ELE': return Icons.electrical_services_outlined;
      case 'MEC': return Icons.settings_outlined;
      case 'MCT': return Icons.memory;
      case 'PET': return Icons.local_gas_station_outlined;
      default: return Icons.school;
    }
  }
}

/// Course selection step: search, filter, and pick up to 10 courses.
class CourseSelectionStepContent extends StatelessWidget {
  const CourseSelectionStepContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GetBuilder<SignUpController>(
      builder: (ctrl) {
        if (ctrl.isFetchingCourses.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Loading courses..."),
              ],
            ),
          );
        }

        if (ctrl.coursesError.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(ctrl.coursesError.value),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ctrl.fetchCoursesForDepartment(
                    ctrl.selectedDepartmentCode.value,
                  ),
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Selected count + next hint
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Select up to 10 courses",
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: ctrl.selectedCourses.length >= 10
                          ? colorScheme.errorContainer
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${ctrl.selectedCourses.length}/10",
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ctrl.selectedCourses.length >= 10
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: "Search courses...",
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: ctrl.courseSearchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => ctrl.courseSearchQuery.value = '',
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => ctrl.courseSearchQuery.value = v,
            ),
            const SizedBox(height: 8),

            // Type filter chips
            Row(
              children: [
                _FilterChip(
                  label: "All",
                  selected: ctrl.courseTypeFilter.value.isEmpty,
                  onTap: () => ctrl.courseTypeFilter.value = '',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: "CORE",
                  selected: ctrl.courseTypeFilter.value == 'CORE',
                  onTap: () => ctrl.courseTypeFilter.value = 'CORE',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: "ELECTIVE",
                  selected: ctrl.courseTypeFilter.value == 'ELECTIVE',
                  onTap: () => ctrl.courseTypeFilter.value = 'ELECTIVE',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Course list
            Expanded(
              child: ctrl.filteredCourses.isEmpty
                  ? Center(
                      child: Text(
                        ctrl.courseSearchQuery.value.isNotEmpty
                            ? "No courses match your search"
                            : "No courses available",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: ctrl.filteredCourses.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final course = ctrl.filteredCourses[index];
                        final code = course['code'] as String? ?? '';
                        final title = course['title'] as String? ?? '';
                        final type = course['type'] as String? ?? '';
                        final units = course['units'] as int? ?? 0;
                        final isSelected = ctrl.selectedCourses.contains(code);
                        final isMaxed = ctrl.selectedCourses.length >= 10 && !isSelected;

                        return Opacity(
                          opacity: isMaxed ? 0.5 : 1.0,
                          child: ListTile(
                            dense: true,
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: isMaxed
                                  ? null
                                  : (_) => ctrl.toggleCourse(code),
                            ),
                            title: Text(
                              code,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              "$type · $units unit${units != 1 ? 's' : ''}",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: type == 'CORE'
                                    ? colorScheme.primary
                                    : colorScheme.tertiary,
                              ),
                            ),
                            onTap: isMaxed ? null : () => ctrl.toggleCourse(code),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : Colors.transparent,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          ),
        ),
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
