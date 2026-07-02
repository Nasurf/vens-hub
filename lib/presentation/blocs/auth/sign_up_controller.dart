import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_event.dart';
import 'package:vens_hub/core/config/environment_config.dart';
import 'package:http/http.dart' as http;

class SignUpController extends GetxController {
  final pageController = PageController();
  final totalSteps = 4; // Name → Department → Courses → Credentials
  final RxInt currentStep = 0.obs;

  // Form Keys
  final formKey1 = GlobalKey<FormState>();
  final formKey4 = GlobalKey<FormState>();

  // Form Controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // State
  final RxString selectedDepartmentCode = ''.obs;
  final RxString selectedDepartmentName = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool passwordVisible = false.obs;
  final RxBool confirmPasswordVisible = false.obs;

  // Department & Course data (fetched from Worker API)
  final RxList<Map<String, dynamic>> departments = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> availableCourses = <Map<String, dynamic>>[].obs;
  final RxList<String> selectedCourses = <String>[].obs;
  final RxBool isFetchingCourses = false.obs;
  final RxString coursesError = ''.obs;

  // Course search & filter
  final RxString courseSearchQuery = ''.obs;
  final RxString courseTypeFilter = ''.obs; // '' = all, 'CORE', 'ELECTIVE'

  /// Filtered courses based on search query and type filter
  List<Map<String, dynamic>> get filteredCourses {
    var courses = availableCourses.toList();
    final query = courseSearchQuery.value.trim().toLowerCase();
    final typeFilter = courseTypeFilter.value;

    if (query.isNotEmpty) {
      courses = courses.where((c) =>
        (c['code'] as String? ?? '').toLowerCase().contains(query) ||
        (c['title'] as String? ?? '').toLowerCase().contains(query)
      ).toList();
    }
    if (typeFilter.isNotEmpty) {
      courses = courses.where((c) =>
        (c['type'] as String? ?? '') == typeFilter
      ).toList();
    }
    return courses;
  }

  @override
  void onInit() {
    super.onInit();
    pageController.addListener(() {
      final page = pageController.page?.round() ?? currentStep.value;
      if (currentStep.value != page) {
        currentStep.value = page;
        update();
      }
    });

    firstNameController.addListener(() => update());
    lastNameController.addListener(() => update());
    emailController.addListener(() => update());
    passwordController.addListener(() => update());
    confirmPasswordController.addListener(() => update());

    // Fetch departments on init
    fetchDepartments();
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

  Future<void> fetchDepartments() async {
    try {
      final uri = Uri.parse('${EnvironmentConfig.apiBaseUrl}/departments');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        departments.assignAll((data['departments'] as List).cast<Map<String, dynamic>>());
      }
    } catch (_) {
      // Fallback to static department list if API fails
      departments.assignAll([
        {'name': 'AERONAUTICAL ENGINEERING', 'code': 'AER'},
        {'name': 'BIOMEDICAL ENGINEERING', 'code': 'BIO'},
        {'name': 'CHEMICAL ENGINEERING', 'code': 'CHE'},
        {'name': 'CIVIL ENGINEERING', 'code': 'CIV'},
        {'name': 'COMPUTER ENGINEERING', 'code': 'COM'},
        {'name': 'ELECTRICAL AND ELECTRONICS ENGINEERING', 'code': 'ELE'},
        {'name': 'MECHANICAL ENGINEERING', 'code': 'MEC'},
        {'name': 'MECHATRONICS ENGINEERING', 'code': 'MCT'},
        {'name': 'PETROLEUM ENGINEERING', 'code': 'PET'},
      ]);
    }
  }

  Future<void> fetchCoursesForDepartment(String deptCode) async {
    isFetchingCourses.value = true;
    coursesError.value = '';
    try {
      final uri = Uri.parse('${EnvironmentConfig.apiBaseUrl}/departments/$deptCode/courses');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        availableCourses.assignAll((data['courses'] as List).cast<Map<String, dynamic>>());
      } else {
        coursesError.value = 'Failed to load courses';
      }
    } catch (e) {
      coursesError.value = 'Network error loading courses';
    } finally {
      isFetchingCourses.value = false;
    }
  }

  void selectDepartment(String code, String name) {
    selectedDepartmentCode.value = code;
    selectedDepartmentName.value = name;
    selectedCourses.clear();
    availableCourses.clear();
    fetchCoursesForDepartment(code);
    update();
  }

  void toggleCourse(String courseCode) {
    if (selectedCourses.contains(courseCode)) {
      selectedCourses.remove(courseCode);
    } else if (selectedCourses.length < 10) {
      selectedCourses.add(courseCode);
    }
    update();
  }

  bool get canProceed {
    switch (currentStep.value) {
      case 0:
        return firstNameController.text.trim().isNotEmpty &&
            lastNameController.text.trim().isNotEmpty;
      case 1:
        return selectedDepartmentCode.value.isNotEmpty;
      case 2:
        return selectedCourses.isNotEmpty; // At least 1 course required
      case 3:
        return GetUtils.isEmail(emailController.text.trim()) &&
            passwordController.text.trim().length >= 6 &&
            passwordController.text.trim() ==
                confirmPasswordController.text.trim();
      default:
        return false;
    }
  }

  void nextStep() {
    Get.focusScope?.unfocus();
    if (currentStep.value == 0) {
      if (!formKey1.currentState!.validate()) return;
    }
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

  void completeSignUp(BuildContext context) {
    Get.focusScope?.unfocus();
    if (!formKey4.currentState!.validate()) return;

    context.read<AuthBloc>().add(
      AuthSignUpRequested(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        department: selectedDepartmentCode.value,
        selectedCourses: selectedCourses.toList(),
      ),
    );
  }
}
