import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Topic extends Equatable {
  final String title;
  final List<String> sources;
  final List<String> subtopics;

  const Topic({
    required this.title,
    required this.sources,
    required this.subtopics,
  });

  factory Topic.fromJson(dynamic json) {
    if (json == null) return const Topic(title: '', sources: [], subtopics: []);
    if (json is String) {
      return Topic(title: json, sources: const [], subtopics: const []);
    }
    final map = json as Map<String, dynamic>? ?? {};

    List<String> parseList(dynamic val) {
      if (val is List) return List<String>.from(val.map((e) => e.toString()));
      if (val is String && val.isNotEmpty) return [val];
      return const [];
    }

    return Topic(
      title: map['title']?.toString() ?? '',
      sources: parseList(map['sources']),
      subtopics: parseList(map['subtopics']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'sources': sources, 'subtopics': subtopics};
  }

  @override
  List<Object?> get props => [title, sources, subtopics];
}

class CourseInfo extends Equatable {
  final String id;
  final String title;
  final String code;
  final List<String> semester;
  final String? description;
  final String? imageUrl;
  final List<String> tags;
  final List<String> departmentCodes;
  final List<Topic> topics;

  const CourseInfo({
    required this.id,
    required this.title,
    required this.code,
    required this.semester,
    this.description,
    this.imageUrl,
    required this.tags,
    required this.departmentCodes,
    required this.topics,
  });

  factory CourseInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    List<String> parseList(dynamic val) {
      if (val is List) return List<String>.from(val.map((e) => e.toString()));
      if (val is String && val.isNotEmpty) return [val];
      return const [];
    }

    return CourseInfo(
      id: doc.id,
      title: data['title']?.toString() ?? data['course']?.toString() ?? '',
      code: data['code']?.toString() ?? '',
      description: data['description']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      tags: parseList(data['tags']),
      topics:
          (data['topics'] is List)
              ? (data['topics'] as List).map((t) => Topic.fromJson(t)).toList()
              : (data['topics'] is String
                  ? [Topic.fromJson(data['topics'])]
                  : []),
      semester: parseList(data['semester']),
      departmentCodes: parseList(
        data['department_codes'] ??
            data['department codes'] ??
            data['department_code'] ??
            data['department code'],
      ),
    );
  }

  factory CourseInfo.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) return List<String>.from(val.map((e) => e.toString()));
      if (val is String && val.isNotEmpty) return [val];
      return const [];
    }

    return CourseInfo(
      id: json["id"]?.toString() ?? '',
      title: json["title"]?.toString() ?? json["course"]?.toString() ?? '',
      code: json["code"]?.toString() ?? '',
      description: json["description"]?.toString(),
      imageUrl: json["imageUrl"]?.toString(),
      tags: parseList(json['tags']),
      topics:
          (json['topics'] is List)
              ? (json['topics'] as List).map((t) => Topic.fromJson(t)).toList()
              : (json['topics'] is String
                  ? [Topic.fromJson(json['topics'])]
                  : []),
      semester: parseList(json['semester']),
      departmentCodes: parseList(
        json['department_codes'] ??
            json['department codes'] ??
            json['department_code'] ??
            json['department code'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'code': code,
      'description': description,
      'imageUrl': imageUrl,
      'tags': tags,
      'topics': topics.map((t) => t.toJson()).toList(),
      "semester": semester,
      'department_codes': departmentCodes,
    };
  }

  CourseInfo copyWith({
    String? id,
    String? title,
    String? code,
    String? description,
    String? imageUrl,
    List<String>? tags,
    List<Topic>? topics,
    List<String>? semester,
    List<String>? departmentCodes,
  }) {
    return CourseInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      semester: semester ?? this.semester,
      code: code ?? this.code,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      topics: topics ?? this.topics,
      departmentCodes: departmentCodes ?? this.departmentCodes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    semester,
    code,
    description,
    imageUrl,
    tags,
    topics,
    departmentCodes,
  ];
}
