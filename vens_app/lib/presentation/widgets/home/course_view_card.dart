import 'package:flutter/material.dart';
import 'package:vens_hub/core/constants/ui_constants.dart';

int numberOfTags = 3;
List<String> courseCategories = [
  "Circuits",
  "Electronics",
  "Power Systems",
  "Signals",
];

Widget buildCourseViewCard({
  required BuildContext context,
  required String title,
  required List<dynamic> tags,
  required String buttonText,
  IconData? icon,
  required VoidCallback? onStartButtonTapped,
  required Function(String tag) onChipItemClicked, // <-- change here
}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: AppConstants.cardOuterPadding),
    child: Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.inverseSurface.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, // Use the title directly
                      style: TextStyle(
                        fontSize: 16.5,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children:
                          tags
                              .take(numberOfTags)
                              .map(
                                (tag) => _buildCourseTag(
                                  tag,
                                  onChipTap:
                                      () => onChipItemClicked(
                                        tag,
                                      ), // <-- pass tag
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
              icon != null
                  ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  )
                  : const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onStartButtonTapped,
            child: Text(
              buttonText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCourseTag(String tag, {required VoidCallback onChipTap}) {
  return GestureDetector(
    onTap: onChipTap,
    child: Chip(
      label: Text(
        tag,
        style: const TextStyle(
          fontSize: 12.5,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Colors.black,
      side: const BorderSide(color: Colors.white10),
    ),
  );
}
