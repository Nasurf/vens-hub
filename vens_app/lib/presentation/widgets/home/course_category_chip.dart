import 'package:flutter/material.dart';
import 'package:vens_hub/core/constants/ui_constants.dart';

List<String> courseCategories = [
  "Circuits",
  "Electronics",
  "Power Systems",
  "Signals",
];

Widget buildCourseCategories(BuildContext context) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (int i = 0; i < courseCategories.length; i++)
          _buildCategoryChip(context, courseCategories[i]),
      ],
    ),
  );
}

Widget _buildCategoryChip(BuildContext context, String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: Chip(
      label: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppConstants.courseCategoryTagBorderRadius,
        ),
      ),
      side: const BorderSide(color: Colors.white10, width: 3),
    ),
  );
}
