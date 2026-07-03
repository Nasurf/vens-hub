import 'package:flutter/material.dart';
// import 'package:vens_hub/data/Models/improvement_area_model.dart'; // Added import for ImprovementArea
import 'package:vens_hub/core/Brain/latex_support.dart';

import '../../data/models/answer_feedback_model.dart'; // Added import for FormattedMathText

class FeedbackDialog extends StatelessWidget {
  final AnswerFeedback feedback;

  const FeedbackDialog({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 600, // Increased max width
          maxHeight: 700, // Increased max height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRatingSection(context),
                    const SizedBox(height: 20),
                    _buildOverallFeedback(context),
                    if (feedback.hasStrengths) ...[
                      const SizedBox(height: 20),
                      _buildStrengthsSection(context),
                    ],
                    if (feedback.hasEnhancements && _isExcellent) ...[
                      const SizedBox(height: 20),
                      _buildEnhancementsSection(context),
                    ],
                    if (feedback.hasImprovements && !_isExcellent) ...[
                      const SizedBox(height: 20),
                      _buildImprovementsSection(context),
                    ],
                    const SizedBox(height: 20),
                    _buildCorrectSolution(context),
                  ],
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.feedback_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Feedback on Your Answer',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis, // Prevent overflow
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    final ratingColor = FeedbackRating.getRatingColor(feedback.rating);
    final ratingIcon = _getRatingIcon(feedback.rating);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ratingColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ratingColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(ratingIcon, color: ratingColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Rating',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  feedback.rating,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ratingColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallFeedback(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall Feedback',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FormattedMathText(
            // Use FormattedMathText
            content: feedback.overallFeedback,
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
              // color and size will now be respected by Math.tex
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrengthsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.thumb_up,
              color: Colors.green[700], // Use darker green
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'What You Did Well',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...feedback.strengths.map(
          (strength) => _buildBulletPoint(context, strength, Colors.green),
        ),
      ],
    );
  }

  Widget _buildImprovementsSection(BuildContext context) {
    // Determine heading text based on rating
    final heading =
        _isPositiveButIncomplete
            ? 'Things you could add'
            : 'Why this is incorrect';
    final icon =
        _isPositiveButIncomplete ? Icons.add_circle_outline : Icons.info;
    final iconColor =
        _isPositiveButIncomplete ? Colors.blue[700] : Colors.deepOrange[700];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                heading,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...feedback.areasForImprovement.expand(
          (area) => [
            FormattedMathText(
              // Use FormattedMathText
              content: area.explanation,
              textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
                color: Colors.grey[700], // Dark grey color for the reason text
              ),
            ),
            if (area.suggestedCorrection != null) ...[
              const SizedBox(height: 12),
              Text(
                'Suggested correction:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              FormattedMathText(
                // Use FormattedMathText
                content: area.suggestedCorrection!,
                textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  // color and size will now be respected by Math.tex
                ),
              ),
            ],
            const SizedBox(height: 16), // Space between improvement areas
          ],
        ),
      ],
    );
  }

  Widget _buildCorrectSolution(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.blue[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Correct Solution Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!, width: 1),
          ),
          child: FormattedMathText(
            // Use FormattedMathText
            content: feedback.correctSolutionSummary,
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: Colors.blue[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FormattedMathText(
              // Use FormattedMathText
              content: text,
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.4,
                // color and size will now be respected by Math.tex
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          // Add shadow for definition
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Got it!',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  IconData _getRatingIcon(String rating) {
    switch (rating) {
      case 'Excellent':
        return Icons.star;
      case 'Good':
        return Icons.thumb_up;
      case 'Satisfactory':
        return Icons.thumbs_up_down;
      case 'Needs Improvement':
        return Icons.thumb_down;
      case 'Incorrect':
        return Icons.close;
      default:
        return Icons.help_outline;
    }
  }

  bool get _isExcellent => feedback.rating == FeedbackRating.excellent;

  bool get _isPositiveButIncomplete =>
      feedback.rating == FeedbackRating.good ||
      feedback.rating == FeedbackRating.satisfactory;

  Widget _buildEnhancementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Extra insights you could include',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...feedback.enhancements.map(
          (enh) => _buildBulletPoint(context, enh, Colors.amber),
        ),
      ],
    );
  }
}
