import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

class ReportIssuePayload {
  final String questionType;
  final String questionText;
  final String? questionId;
  final String? courseName;
  final String? topic;
  final String? difficulty;
  final int? questionIndex;

  const ReportIssuePayload({
    required this.questionType,
    required this.questionText,
    this.questionId,
    this.courseName,
    this.topic,
    this.difficulty,
    this.questionIndex,
  });
}

Future<void> showReportIssueDialog(
  BuildContext context, {
  required ReportIssuePayload payload,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ReportIssueDialog(payload: payload),
  );
}

class _ReportIssueDialog extends StatefulWidget {
  const _ReportIssueDialog({required this.payload});

  final ReportIssuePayload payload;

  @override
  State<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<_ReportIssueDialog> {
  final TextEditingController _natureController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  bool _includeLogs = true;
  bool _submitting = false;

  @override
  void dispose() {
    _natureController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;

    final viewInsets = MediaQuery.of(context).viewInsets;
    final contentPadding = EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: 20 + viewInsets.bottom,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: contentPadding,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Report issue',
                      style: GoogleFonts.rubik(
                        textStyle: theme.textTheme.titleLarge,
                      ).copyWith(fontWeight: FontWeight.w800, color: onSurface),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: onSurface.withValues(alpha: 0.7),
                      onPressed:
                          _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Nature of the issue',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _natureController,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. LaTeX not rendering, wrong answer, typo, unclear wording',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Give more details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _detailsController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.multiline,
                  minLines: 4,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText:
                        'Tell us what went wrong or how to reproduce the problem…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    // Darker fill to give visual distinction
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _includeLogs,
                      onChanged:
                          _submitting
                              ? null
                              : (v) {
                                setState(() => _includeLogs = v ?? true);
                              },
                    ),
                    Expanded(
                      child: Text(
                        'Include logs and context (question metadata, device/theme).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child:
                          _submitting
                              ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                              : const Text('Submit report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final nature = _natureController.text.trim();
    final details = _detailsController.text.trim();
    if (nature.isEmpty) {
      AppNotifier.warning(
        context: context,
        message: 'Please describe the nature of the issue',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid =
          Get.isRegistered<HomeController>()
              ? Get.find<HomeController>().currentUser.value?.id
              : null;

      final theme = Theme.of(context);
      final payload = widget.payload;

      final logs =
          _includeLogs
              ? <String, dynamic>{
                'theme': theme.brightness.name,
                'platform_brightness':
                    MediaQuery.of(context).platformBrightness.name,
                'locale': Localizations.localeOf(context).toLanguageTag(),
              }
              : null;

      await FireStoreServices.find.submitQuestionReport(
        uid: uid,
        questionType: payload.questionType,
        questionId: payload.questionId,
        questionText: payload.questionText,
        courseName: payload.courseName,
        topic: payload.topic,
        difficulty: payload.difficulty,
        questionIndex: payload.questionIndex,
        issueNature: nature,
        issueDetails: details,
        includeLogs: _includeLogs,
        logs: logs,
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppNotifier.success(
          context: context,
          message: 'Thanks! Your report was submitted.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.error(
          context: context,
          message: 'Failed to submit report: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
