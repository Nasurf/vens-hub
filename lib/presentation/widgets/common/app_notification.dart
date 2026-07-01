import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Type of notification to display.
enum AppNotificationType { success, info, warning, error }

/// Lightweight widget used inside SnackBars/GetSnackBars for consistent styling.
class AppNotification extends StatelessWidget {
  const AppNotification({
    super.key,
    required this.message,
    this.title,
    required this.type,
    this.action,
  });

  final String message;
  final String? title;
  final AppNotificationType type;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colorsForType(theme.colorScheme);

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(colors.icon, color: colors.iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title!.trim().isNotEmpty)
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }

  _ColorTokens _colorsForType(ColorScheme scheme) {
    switch (type) {
      case AppNotificationType.success:
        return _ColorTokens(
          background: scheme.primaryContainer.withValues(alpha: 0.9),
          border: scheme.primary.withValues(alpha: 0.3),
          shadow: scheme.primary.withValues(alpha: 0.2),
          icon: Icons.check_circle_rounded,
          iconColor: scheme.primary,
          textColor: scheme.onPrimaryContainer,
        );
      case AppNotificationType.warning:
        return _ColorTokens(
          background: scheme.tertiaryContainer.withValues(alpha: 0.95),
          border: scheme.tertiary.withValues(alpha: 0.3),
          shadow: scheme.tertiary.withValues(alpha: 0.2),
          icon: Icons.warning_rounded,
          iconColor: scheme.tertiary,
          textColor: scheme.onTertiaryContainer,
        );
      case AppNotificationType.error:
        return _ColorTokens(
          background: scheme.errorContainer.withValues(alpha: 0.95),
          border: scheme.error.withValues(alpha: 0.3),
          shadow: scheme.error.withValues(alpha: 0.2),
          icon: Icons.error_rounded,
          iconColor: scheme.error,
          textColor: scheme.onErrorContainer,
        );
      case AppNotificationType.info:
        return _ColorTokens(
          background: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          border: scheme.outline.withValues(alpha: 0.2),
          shadow: scheme.shadow.withValues(alpha: 0.12),
          icon: Icons.info_rounded,
          iconColor: scheme.secondary,
          textColor: scheme.onSurface,
        );
    }
  }
}

class _ColorTokens {
  _ColorTokens({
    required this.background,
    required this.border,
    required this.shadow,
    required this.icon,
    required this.iconColor,
    required this.textColor,
  });

  final Color background;
  final Color border;
  final Color shadow;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
}

/// Helper for showing notifications from anywhere in the app.
class AppNotifier {
  const AppNotifier._();

  static Future<void> show({
    BuildContext? context,
    String? title,
    required String message,
    AppNotificationType type = AppNotificationType.info,
    Duration duration = const Duration(seconds: 4),
    Widget? action,
  }) async {
    BuildContext? ctx = context;
    ctx ??= Get.context;
    if (ctx == null) return;

    final notification = AppNotification(
      title: title,
      message: message,
      type: type,
      action: action,
    );

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: notification,
      duration: duration,
    );

    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(snackBar);
      return;
    }

    // Fallback to GetX snackbar if there is no scaffold messenger.
    Get.showSnackbar(
      GetSnackBar(
        animationDuration: const Duration(milliseconds: 250),
        duration: duration,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 18,
        messageText: notification,
      ),
    );
  }

  static Future<void> success({
    BuildContext? context,
    String? title,
    required String message,
    Widget? action,
  }) => show(
    context: context,
    title: title,
    message: message,
    type: AppNotificationType.success,
    action: action,
  );

  static Future<void> error({
    BuildContext? context,
    String? title,
    required String message,
    Widget? action,
  }) => show(
    context: context,
    title: title,
    message: message,
    type: AppNotificationType.error,
    action: action,
  );

  static Future<void> warning({
    BuildContext? context,
    String? title,
    required String message,
    Widget? action,
  }) => show(
    context: context,
    title: title,
    message: message,
    type: AppNotificationType.warning,
    action: action,
  );

  static Future<void> info({
    BuildContext? context,
    String? title,
    required String message,
    Widget? action,
  }) => show(
    context: context,
    title: title,
    message: message,
    type: AppNotificationType.info,
    action: action,
  );
}
