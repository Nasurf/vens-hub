import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vens_hub/core/theme/app_theme.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';
import 'package:vens_hub/core/controllers/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  runApp(const VensHubApp());
}

class VensHubApp extends StatelessWidget {
  const VensHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Vens Hub',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.greenLightTheme,
      darkTheme: AppThemes.greenDarkTheme,
      themeMode: ThemeMode.dark,
      home: const Scaffold(
        body: Center(
          child: Text('Vens Hub'),
        ),
      ),
    );
  }
}
