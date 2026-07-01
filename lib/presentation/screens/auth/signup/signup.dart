import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/screens/auth/signup/signup.desktop.dart';
import 'package:vens_hub/presentation/screens/auth/signup/signup.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: MobileSignUpScreen(),
      desktop: DesktopSignUpScreen(),
    );
  }
}
