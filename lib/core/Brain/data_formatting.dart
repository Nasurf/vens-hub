class TheoryQuestion {
  final String courseName;
  final String topic;
  final String difficulty;
  final String question;
  final String questionType;
  final String sampleAnswer;
  final List<String> keyConcepts;
  final List<String> markingCriteria;

  TheoryQuestion({
    required this.courseName,
    required this.topic,
    required this.difficulty,
    required this.question,
    required this.questionType,
    required this.sampleAnswer,
    required this.keyConcepts,
    required this.markingCriteria,
  });

  TheoryQuestion copyWith({
    String? courseName,
    String? topic,
    String? difficulty,
    String? question,
    String? questionType,
    String? sampleAnswer,
    List<String>? keyConcepts,
    List<String>? markingCriteria,
  }) {
    return TheoryQuestion(
      courseName: courseName ?? this.courseName,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      question: question ?? this.question,
      questionType: questionType ?? this.questionType,
      sampleAnswer: sampleAnswer ?? this.sampleAnswer,
      keyConcepts: keyConcepts ?? this.keyConcepts,
      markingCriteria: markingCriteria ?? this.markingCriteria,
    );
  }

  Map<String, dynamic> toJson() => {
    'courseName': courseName,
    'topic': topic,
    'difficulty': difficulty,
    'question': question,
    'questionType': questionType,
    'sampleAnswer': sampleAnswer,
    'keyConcepts': keyConcepts,
    'markingCriteria': markingCriteria,
  };

  factory TheoryQuestion.fromJson(Map<String, dynamic> json) {
    return TheoryQuestion(
      courseName: json['course_name'] ?? json['courseName'],
      topic: json['topic'],
      difficulty: json['difficulty'],
      question: json['question'],
      questionType: json['question_type'] ?? json['questionType'],
      sampleAnswer: json['sample_answer'] ?? json['sampleAnswer'],
      keyConcepts: List<String>.from(
        json['key_concepts'] ?? json['keyConcepts'] ?? [],
      ),
      markingCriteria: List<String>.from(
        json['marking_criteria'] ?? json['markingCriteria'] ?? [],
      ),
    );
  }
}

class GapFillQuestion {
  final String courseName;
  final String topic;
  final String difficulty;
  final String prompt;
  final List<String> answers;
  final String explanation;
  final List<String> options; // Single list of options for all gaps
  final bool isDragAndDrop; // Whether this is a drag and drop question

  GapFillQuestion({
    required this.courseName,
    required this.topic,
    required this.difficulty,
    required this.prompt,
    required this.answers,
    required this.explanation,
    this.options = const [],
    this.isDragAndDrop = false,
  });

  GapFillQuestion copyWith({
    String? courseName,
    String? topic,
    String? difficulty,
    String? prompt,
    List<String>? answers,
    String? explanation,
    List<String>? options,
    bool? isDragAndDrop,
  }) {
    return GapFillQuestion(
      courseName: courseName ?? this.courseName,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      prompt: prompt ?? this.prompt,
      answers: answers ?? this.answers,
      explanation: explanation ?? this.explanation,
      options: options ?? this.options,
      isDragAndDrop: isDragAndDrop ?? this.isDragAndDrop,
    );
  }

  Map<String, dynamic> toJson() => {
    'courseName': courseName,
    'topic': topic,
    'difficulty': difficulty,
    'prompt': prompt,
    'answers': answers,
    'explanation': explanation,
    'options': options,
    'isDragAndDrop': isDragAndDrop,
  };

  factory GapFillQuestion.fromJson(Map<String, dynamic> json) {
    return GapFillQuestion(
      courseName: json['course_name'] ?? json['courseName'],
      topic: json['topic'],
      difficulty: json['difficulty'],
      prompt: json['prompt'],
      answers: List<String>.from(json['answers'] ?? []),
      explanation: json['explanation'],
      options: List<String>.from(json['options'] ?? []),
      isDragAndDrop: json['isDragAndDrop'] ?? false,
    );
  }
}
