import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/widgets/common/button_strokes_painter.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

Widget utilityMediumVerticalGap() {
  // Renamed
  return SizedBox(height: 10);
}

Widget utilityMediumHorizontalGap() {
  // Renamed
  return SizedBox(height: 10); // Should this be width? Keeping as is for now.
}

class AppErrorSnackbar {
  // Renamed class
  static void showError({
    // Method name kept, could be showSnackbar
    required BuildContext context,
    required String title,
    required String message,
  }) {
    AppNotifier.error(context: context, title: title, message: message);
  }
}

Widget buildAppActionButton(
  // Renamed function
  BuildContext context, {
  Color textColor =
      Colors
          .white, // This might need to be Theme.of(context).colorScheme.onPrimary if backgroundColor is primary
  required String text,
  required VoidCallback onPressed,
  required Color backgroundColor,
}) {
  return SizedBox(
    width: double.infinity,
    child: CustomPaint(
      foregroundPainter: const ButtonStrokesPainter(
        cornerRadius: 28,
        strokeWidth: 2,
        color: Colors.white,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 1,
          shadowColor: Colors.black.withAlpha(
            (0.3 * 255).round(),
          ), // Updated opacity
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget utilityFormItemLarge(
  BuildContext context,
  String hintText, {
  bool isPassword = false,
  bool obscureText = true, // Default for password fields
  required String? Function(String? text) validator,
  required TextEditingController formItemContoller,
  ValueChanged<String>? onChanged,
  VoidCallback? onTogglePassword,
  TextInputType? keyboardType, // Added keyboardType
  Widget? prefixIcon, // Added prefixIcon parameter
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return TextFormField(
    obscureText: obscureText,
    controller: formItemContoller,
    decoration: InputDecoration(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(width: 5.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      prefixIcon: prefixIcon,
      suffixIcon:
          isPassword
              ? IconButton(
                onPressed: onTogglePassword,
                icon:
                    obscureText
                        ? Icon(Icons.remove_red_eye_outlined)
                        : Icon(Icons.remove_red_eye),
              )
              : null,
    ),
    style: TextStyle(color: colorScheme.onSurface),
    keyboardType: keyboardType,
    validator: validator,
    onChanged: onChanged,
  );
}
