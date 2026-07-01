// Auth flow: signin, signup, email verification, forgot password, Google SSO
import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/screens/auth/signin/signin.desktop.dart';
import 'package:vens_hub/presentation/screens/auth/signin/signin.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(mobile: MobileSignIn(), desktop: DesktopSignIn());
  }
}
