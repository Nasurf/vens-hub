# Vens Hub API

Base URL: `https://vens-hub-api.nasurf25.workers.dev`

Cloudflare Worker backed by D1 database (`vens-hub-questions`). 9 engineering departments, 426 courses, ~142K questions.

---

## Endpoints

### Health check

```
GET /health
```

Response:
```json
{ "status": "ok", "db": "vens-hub-questions" }
```

### List all departments

```
GET /departments
```

Response:
```json
{
  "departments": [
    { "name": "AERONAUTICAL ENGINEERING", "code": "AER", "course_count": 93 },
    { "name": "BIOMEDICAL ENGINEERING",   "code": "BIO", "course_count": 107 },
    { "name": "CHEMICAL ENGINEERING",     "code": "CHE", "course_count": 95 },
    { "name": "CIVIL ENGINEERING",         "code": "CIV", "course_count": 108 },
    { "name": "COMPUTER ENGINEERING",     "code": "COM", "course_count": 78 },
    { "name": "ELECTRICAL AND ELECTRONICS ENGINEERING", "code": "ELE", "course_count": 102 },
    { "name": "MECHANICAL ENGINEERING",   "code": "MEC", "course_count": 96 },
    { "name": "MECHATRONICS ENGINEERING", "code": "MCT", "course_count": 80 },
    { "name": "PETROLEUM ENGINEERING",    "code": "PET", "course_count": 72 }
  ]
}
```

### List courses for a department

```
GET /departments/:code/courses
```

Example: `/departments/AER/courses`

Response:
```json
{
  "courses": [
    { "code": "AAE 101", "title": "INTRODUCTION TO AEROSPACE ENGINEERING", "type": "CORE", "units": 2, "levels": "[\"100\"]", "description": "...", "question_count": 540 }
  ]
}
```

**Department codes:** `AER`, `BIO`, `CHE`, `CIV`, `COM`, `ELE`, `MEC`, `MCT`, `PET`

### List all courses

```
GET /courses
```

Returns all 426 courses with metadata (department, question count).

### Get a single course

```
GET /courses/:courseCode
```

Example: `/courses/AAE%20101` (URL-encoded space)

Response:
```json
{
  "course": {
    "code": "AAE 101",
    "title": "INTRODUCTION TO AEROSPACE ENGINEERING",
    "type": "CORE",
    "units": 2,
    "levels": "[\"100\"]",
    "semesters": "[\"FIRST\"]",
    "description": "...",
    "outline": "[\"Aerodynamics and Flight Mechanics\", ...]",
    "department": "AERONAUTICAL ENGINEERING",
    "department_code": "AER",
    "question_count": 540
  }
}
```

### Get questions for a course

```
GET /questions/:courseCode
```

Example: `/questions/AAE%20101`

Response:
```json
{
  "questions": [
    {
      "id": 162512,
      "topic_name": "Aerodynamics and Flight Mechanics",
      "subtopic_name": "Aircraft Stability",
      "question_type": "calculation",
      "difficulty": "Easy",
      "difficulty_ranking": 2,
      "question": "An aircraft wing produces a lift of $75\\,\\text{kN}$...",
      "options": "[\"$-38.0\\,\\text{kN\\cdot m}$\", ...]",
      "correct_answer_index": 0,
      "correct_answer": "A",
      "correct_answer_text": "$-38.0\\,\\text{kN\\cdot m}$",
      "explanation": "The total pitching moment about the CG...",
      "solution_steps": "[\"Formula: $M_{CG} = M_{AC} + L(x_{CG} - x_{AC})$\", ...]",
      "rag_sources": "[{\"ref_id\": \"...\", \"path\": \"...\", ...}]"
    }
  ],
  "count": 540
}
```

**Note:** Course codes with spaces must be URL-encoded. `AAE 101` → `AAE%20101`.

---

## Flutter usage

Add to `assets/.env`:
```
API_BASE_URL=https://vens-hub-api.nasurf25.workers.dev
```

Then in `lib/core/config/environment_config.dart`:
```dart
static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
```

### Example HTTP call (using `http` package)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vens_hub/core/config/environment_config.dart';

class QuestionsApiService {
  final String _baseUrl = EnvironmentConfig.apiBaseUrl;

  Future<List<dynamic>> getQuestions(String courseCode) async {
    final encoded = Uri.encodeComponent(courseCode);
    final uri = Uri.parse('$_baseUrl/questions/$encoded');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['questions'];
    }
    throw Exception('Failed to load questions: ${response.statusCode}');
  }

  Future<List<dynamic>> getCourses() async {
    final uri = Uri.parse('$_baseUrl/courses');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['courses'];
    }
    throw Exception('Failed to load courses: ${response.statusCode}');
  }
}
```

---

## Error responses

**404 Not found:**
```json
{ "error": "Not found" }
```

**500 Internal error:**
```json
{ "error": "Internal error: <message>" }
```

---

## Deployment

```bash
cd workers/api
wrangler deploy --env=""
```

The Worker is in `workers/api/src/index.js` with D1 binding `QUESTIONS_DB` pointing to `vens-hub-questions`.
