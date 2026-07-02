# Vens Hub — Worker API Reference

> **Base URL (production):** `https://api.vens-hub.workers.dev` (replace with your deployed URL)  
> **Content-Type:** All request/response bodies are `application/json`  
> **CORS:** All origins allowed (`*`). Preflight `OPTIONS` is handled automatically.

---

## Authentication

Most read endpoints are public. Endpoints that write or read user-specific data require the caller's Firebase Auth UID:

| Header | Description |
|---|---|
| `X-User-Id` | Firebase Auth UID. **Required** for all `/user/*` endpoints and adaptive write operations. |

Some `POST` bodies also accept `userId` as a body field as a fallback (e.g. `/adaptive/submit-answer`), but the header is preferred.

---

## 1. Health

### `GET /health`
Simple liveness check.

**Response**
```json
{ "status": "ok", "db": "vens-hub-questions" }
```

---

## 2. Courses

### `GET /courses`
List courses with optional filtering and pagination.

**Query params**

| Param | Type | Description |
|---|---|---|
| `q` | string | Title search (LIKE) |
| `department` | string | Filter by department name |
| `level` | string | Filter by academic level |
| `limit` | number | Max results (default `20`, max `50`) |
| `cursor` | number | Offset for pagination (default `0`) |

**Response**
```json
{
  "courses": [{ "code": "CSC301", "title": "...", "type": "...", "units": 3 }],
  "total": 120,
  "hasMore": true,
  "nextCursor": 20
}
```

---

### `GET /courses/:courseCode`
Get a single course by code.

**Response** `200` or `404`
```json
{ "course": { "code": "CSC301", "title": "...", "department": "..." } }
```

---

### `GET /courses/:courseCode/questions`
Get all questions for a course.

**Response**
```json
{
  "questions": [
    {
      "id": "q_abc123",
      "topic_name": "Sorting Algorithms",
      "subtopic_name": "QuickSort",
      "question_type": "mcq",
      "difficulty": "medium",
      "difficulty_ranking": 2,
      "question": "What is the average time complexity of QuickSort?",
      "options": ["O(n)", "O(n log n)", "O(n^2)", "O(log n)"],
      "correct_answer_index": 1,
      "correct_answer": "B",
      "correct_answer_text": "O(n log n)",
      "explanation": "...",
      "solution_steps": "...",
      "rag_sources": "..."
    }
  ],
  "count": 42
}
```

---

## 3. Departments

### `GET /departments`
List all departments.

**Response**
```json
{ "departments": [{ "name": "Computer Science", "code": "CSC", "course_count": 14 }] }
```

---

### `GET /departments/:deptCode/courses`
List courses for a specific department.

**Query params:** `q`, `limit`, `cursor` (same as `/courses`)

**Response** — same shape as `GET /courses`

---

## 4. Questions (legacy alias)

### `GET /questions/:courseCode`
Alias for `GET /courses/:courseCode/questions`. Returns the same question list.

---

## 5. AI Assistant

### `POST /assistant`

Ask a study question. Backed by **Gemini** (`gemma-4-31b-it` or whatever `GEMINI_MODEL` env var is set to).

**Request**
```json
{
  "question": "Explain Big O notation with examples.",
  "context": "We are studying CSC301 Data Structures."
}
```

| Field | Required | Description |
|---|---|---|
| `question` | Yes | The student's question |
| `context` | No | Extra context (course, topic) prepended to the prompt |

**Response** `200`
```json
{ "answer": "Big O notation describes the upper bound of an algorithm's time complexity..." }
```

**Error responses**

| Status | Meaning |
|---|---|
| `400` | `question` field missing |
| `501` | `GEMINI_API_KEY` not configured in the Worker |
| `5xx` | Gemini API error (body contains detail) |

> **Note:** `GEMINI_API_KEY` and `GEMINI_MODEL` are Worker environment secrets — never exposed to the client.

---

## 6. Adaptive Learning (BKT)

These endpoints implement a **Bayesian Knowledge Tracing (BKT)** engine. The mastery state for a knowledge component (KC) is a `KcState` object:

```ts
interface KcState {
  masteryProb: number;      // 0.0 to 1.0, probability of mastery
  sParameter: number;       // BKT slip/guess aggregate
  status: "learning" | "reviewing";
  totalAttempts: number;
  correctAttempts: number;
  lastAttemptAt: string;    // ISO 8601
  nextReviewDue: string;    // ISO 8601
}
```

---

### `POST /adaptive/submit-answer`

Submit a single question answer. Runs BKT update, persists attempt + mastery (if `userId` present).

**Headers:** `X-User-Id` (optional — mastery only persisted when provided)

**Request**
```json
{
  "questionId": "q_abc123",
  "selectedAnswerIndex": 1,
  "attemptId": "uuid-v4-client-generated",
  "kcState": { "masteryProb": 0.35, "sParameter": 0.9, "status": "learning", "totalAttempts": 4, "correctAttempts": 2 },
  "clientElapsedSeconds": 12
}
```

| Field | Required | Description |
|---|---|---|
| `questionId` | Yes | ID from the questions table |
| `selectedAnswerIndex` | Yes | 0-based index of chosen option |
| `attemptId` | Yes | Client-generated UUID (deduplication key) |
| `kcState` | No | Current client-side KC state for this topic |
| `clientElapsedSeconds` | No | Time taken to answer |

**Response** `200`
```json
{
  "status": "applied",
  "isCorrect": true,
  "correctAnswerIndex": 1,
  "correctAnswer": "B",
  "correctAnswerText": "O(n log n)",
  "explanation": "...",
  "kcKey": "Sorting Algorithms",
  "masteryBefore": 0.35,
  "masteryAfter": 0.61,
  "sParameter": 0.92,
  "kcStatus": "learning",
  "totalAttempts": 5,
  "correctAttempts": 3,
  "updatedKcState": { "masteryProb": 0.61, "..." : "..." }
}
```

> Duplicate `attemptId`s return `{ "status": "duplicate" }` with no side effects.

---

### `POST /adaptive/submit-batch`

Submit multiple topic-level results in one call (e.g. after a quiz). Does **not** require individual question IDs.

**Headers:** `X-User-Id` (optional)

**Request**
```json
{
  "results": [
    { "topicName": "Sorting Algorithms", "courseCode": "CSC301", "isCorrect": true },
    { "topicName": "Graph Theory",        "courseCode": "CSC301", "isCorrect": false }
  ]
}
```

**Response** `200`
```json
{ "status": "applied", "count": 2 }
```

---

### `POST /adaptive/state`

Compute course-level mastery summaries from a client KC state map.

**Request**
```json
{
  "kcStates": {
    "Sorting Algorithms": { "masteryProb": 0.82, "sParameter": 0.95, "status": "reviewing" },
    "Graph Theory":        { "masteryProb": 0.41, "sParameter": 0.80, "status": "learning" }
  }
}
```

**Response** `200`
```json
{
  "courses": {
    "CSC301": {
      "masteryAvg": 0.62,
      "totalKcs": 2,
      "masteredKcs": 1,
      "status": "learning"
    }
  }
}
```

---

## 7. User

All `/user/*` endpoints require the `X-User-Id` header.

---

### `GET /user/mastery`
All mastery records for the authenticated user.

**Response**
```json
{
  "topics": [
    {
      "topic_name": "Sorting Algorithms",
      "course_code": "CSC301",
      "mastery_prob": 0.82,
      "s_parameter": 0.95,
      "status": "reviewing",
      "total_attempts": 12,
      "correct_attempts": 10,
      "last_attempt_at": "2025-07-01T10:00:00Z",
      "next_review_due": "2025-07-08T10:00:00Z"
    }
  ]
}
```

---

### `GET /user/mastery/:courseCode`
Mastery records for a single course, plus aggregates.

**Response**
```json
{
  "courseCode": "CSC301",
  "topics": [ "..." ],
  "avgMastery": 0.71,
  "masteredKcs": 8,
  "totalKcs": 12
}
```

---

### `GET /user/stats`
Per-course attempt and mastery statistics.

**Response**
```json
{
  "courses": {
    "CSC301": {
      "totalKcs": 12,
      "masteredKcs": 8,
      "avgMastery": 0.71,
      "totalAttempts": 90,
      "correctAttempts": 67,
      "lastActivityAt": "2025-07-01T10:00:00Z"
    }
  }
}
```

---

### `GET /user/attempts`
Paginated attempt history.

**Query params**

| Param | Description |
|---|---|
| `course` | Filter by course code |
| `limit` | Page size (default `50`, max `200`) |
| `cursor` | ISO 8601 timestamp from previous `nextCursor` |

**Response**
```json
{
  "attempts": [
    {
      "id": "uuid",
      "question_id": "q_abc123",
      "course_code": "CSC301",
      "topic_name": "Sorting Algorithms",
      "is_correct": 1,
      "selected_answer_index": 1,
      "elapsed_seconds": 12,
      "mastery_before": 0.35,
      "mastery_after": 0.61,
      "created_at": "2025-07-01T10:00:00Z"
    }
  ],
  "nextCursor": "2025-06-30T08:00:00Z",
  "limit": 50
}
```

---

### `POST /user/seed-mastery`
Sync local KC states to the server (e.g. after sign-in with pre-existing local data).

**Headers:** `X-User-Id`

**Request**
```json
{
  "kcStates": {
    "Sorting Algorithms": {
      "masteryProb": 0.6,
      "sParameter": 0.9,
      "status": "learning",
      "totalAttempts": 5,
      "correctAttempts": 3,
      "lastAttemptAt": "2025-07-01T10:00:00Z",
      "nextReviewDue": "2025-07-08T10:00:00Z"
    }
  }
}
```

**Response**
```json
{ "seeded": 1, "message": "Seeded 1 KC states for user uid_xyz" }
```

> Topics not mapped to a course code in the questions table are silently skipped.

---

### `POST /user/profile`
Upsert the user profile (create or update on conflict).

**Headers:** `X-User-Id`

**Request**
```json
{
  "firstName": "Adaeze",
  "lastName": "Okonkwo",
  "email": "adaeze@example.com",
  "departmentCode": "CSC",
  "departmentName": "Computer Science",
  "selectedCourses": ["CSC301", "CSC401"]
}
```

| Field | Required |
|---|---|
| `firstName` | Yes |
| `email` | Yes |
| `departmentCode` | Yes |
| `lastName`, `departmentName`, `selectedCourses` | No |

**Response** `200`
```json
{ "ok": true, "userId": "uid_xyz" }
```

---

### `GET /user/profile`
Get the authenticated user's profile.

**Response** — `profile` is `null` if not yet created.
```json
{
  "profile": {
    "firstName": "Adaeze",
    "lastName": "Okonkwo",
    "email": "adaeze@example.com",
    "departmentCode": "CSC",
    "departmentName": "Computer Science",
    "selectedCourses": ["CSC301", "CSC401"]
  }
}
```

---

## 8. Study Material Uploads

A two-step signed upload flow using Cloudflare R2.

### Step 1 — `POST /uploads/presign`
Request a signed upload URL.

**Request**
```json
{
  "filename": "lecture-notes.pdf",
  "content_type": "application/pdf",
  "size_bytes": 204800,
  "object_key": "users/uid_xyz/csc301/lecture-notes.pdf"
}
```

**Response** `200`
```json
{
  "object_key": "users/uid_xyz/csc301/lecture-notes.pdf",
  "public_url": "https://files.nuesaabuad.ng/users/uid_xyz/csc301/lecture-notes.pdf",
  "finalize_url": "/uploads/finalize",
  "upload": {
    "url": "https://api.vens-hub.workers.dev/uploads/direct?object_key=...&...",
    "method": "PUT",
    "headers": {
      "x-vens-upload-expires": "1751480000000",
      "x-vens-upload-signature": "abc123..."
    }
  }
}
```

---

### Step 2 — `PUT /uploads/direct?...`
Upload the file body directly to the Worker (proxied to R2).

**URL params:** All params from the `upload.url` returned in Step 1.

**Required headers:** `x-vens-upload-expires`, `x-vens-upload-signature` (from Step 1), and `content-type`.

**Response** `200`
```json
{
  "object_key": "users/uid_xyz/csc301/lecture-notes.pdf",
  "public_url": "https://files.nuesaabuad.ng/...",
  "etag": "\"d41d8cd98f00b204e9800998ecf8427e\""
}
```

> Signatures expire after **10 minutes**.

---

### Step 3 — `POST /uploads/finalize`
Record upload metadata (optional — confirms the file is present in R2).

**Request**
```json
{
  "object_key": "users/uid_xyz/csc301/lecture-notes.pdf",
  "size_bytes": 204800,
  "metadata": { "course": "CSC301", "title": "Lecture 5" }
}
```

**Response** `200`
```json
{
  "record": {
    "object_key": "...",
    "url": "https://files.nuesaabuad.ng/...",
    "size_bytes": 204800,
    "content_type": "application/pdf",
    "status": "uploaded",
    "metadata": { "course": "CSC301", "title": "Lecture 5" },
    "created_at": "2025-07-02T12:00:00.000Z"
  }
}
```

---

## Error Responses

All errors use the same shape:

```json
{ "error": "Descriptive error message" }
```

| Status | Meaning |
|---|---|
| `400` | Bad request / missing required field |
| `401` | `X-User-Id` header required but not provided |
| `403` | Upload signature invalid or expired |
| `404` | Resource not found |
| `405` | Method not allowed |
| `500` | Internal Worker error |
| `501` | Worker binding (D1/R2/secret) not configured |

---

## Environment Variables / Bindings

| Name | Type | Purpose |
|---|---|---|
| `QUESTIONS_DB` | D1 Database | Questions, courses, departments, mastery, attempts, profiles |
| `STUDY_MATERIALS_BUCKET` | R2 Bucket | File storage (also checked as `MATERIALS_BUCKET`, `R2_BUCKET`) |
| `GEMINI_API_KEY` | Secret | Gemini API key for the AI assistant |
| `GEMINI_MODEL` | Env var | Gemini model name (default: `gemini-2.5-flash-lite`) |
| `UPLOAD_SIGNING_SECRET` | Secret | HMAC-SHA256 key for signing upload URLs |
| `R2_PUBLIC_DOMAIN` | Env var | Public base URL for R2 files (default: `https://files.nuesaabuad.ng`) |
