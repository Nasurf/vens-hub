import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  static const String routeName = '/complete-profile';

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _department;
  String? _level;
  bool _saving = false;

  static const Map<String, String> _departments = {
    'EEE': 'Electrical Engineering',
    'MEE': 'Mechanical Engineering',
    'MCT': 'Mechatronics Engineering',
    'COE': 'Computer Engineering',
    'CHE': 'Chemical Engineering',
    'BME': 'Biomedical Engineering',
    'AAE': 'Aeronautics Engineering',
    'CVE': 'Civil Engineering',
    'PTE': 'Petroleum Engineering',
  };

  static const List<String> _levels = ['100', '200', '300', '400', '500'];

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final String userId = args['userId'] ?? '';
    final String email = args['email'] ?? '';
    final String firstName = args['firstName'] ?? '';
    final String lastName = args['lastName'] ?? '';

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome, ${firstName.isNotEmpty ? firstName : email}',
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your department and level to set up your home and load your courses.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _department,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      items:
                          _departments.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text('${e.value} (${e.key})'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _department = v),
                      validator:
                          (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Please choose a department'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _level,
                      decoration: const InputDecoration(
                        labelText: 'Level',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items:
                          _levels
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _level = v),
                      validator:
                          (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Please choose a level'
                                  : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon:
                            _saving
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.check_circle_outline),
                        label: Text(_saving ? 'Saving…' : 'Save and Continue'),
                        onPressed:
                            _saving
                                ? null
                                : () async {
                                  if (!(_formKey.currentState?.validate() ??
                                      false)) {
                                    return;
                                  }
                                  setState(() => _saving = true);
                                  final repo = di.sl<AuthRepository>();
                                  final result = await repo
                                      .completeUserProfileDataStorage(
                                        userId: userId,
                                        email: email,
                                        firstName: firstName,
                                        lastName: lastName,
                                        department: _department!,
                                        selectedCourses: const [],
                                      );
                                  result.fold(
                                    (failure) {
                                      AppNotifier.error(
                                        context: context,
                                        message: failure.message,
                                      );
                                    },
                                    (user) async {
                                      // Refresh home controller cache so UI shows updated info immediately
                                      if (Get.isRegistered<HomeController>()) {
                                        await Get.find<HomeController>()
                                            .refreshUserDetails(
                                              forceRefresh: true,
                                            );
                                      }
                                      if (mounted) {
                                        Get.offAllNamed(AppRoutes.main);
                                      }
                                    },
                                  );
                                  if (mounted) setState(() => _saving = false);
                                },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We’ll pre-fill your courses for the selected department and level. You can adjust later.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
