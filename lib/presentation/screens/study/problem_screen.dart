import 'package:flutter/material.dart';

import '../../../data/models/question_model.dart'; // Adjusted import path

class ProblemScreen extends StatefulWidget {
  final Question question;

  const ProblemScreen({super.key, required this.question});

  @override
  State<ProblemScreen> createState() => _ProblemScreenState();
}

class _ProblemScreenState extends State<ProblemScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Problem'), // You can customize the title
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Question:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              widget
                  .question
                  .text, // Assuming 'text' is a field in your Question model
              style: TextStyle(fontSize: 16),
            ),
            // TODO: Add TextField for user answer
            // TODO: Add Submit button
          ],
        ),
      ),
    );
  }
}
