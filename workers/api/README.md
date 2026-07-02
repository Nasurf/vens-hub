# Vens Hub API

Cloudflare Worker backed by D1 database (`vens-hub-questions`). 9 engineering departments, 426 courses, ~142K questions + user performance monitoring.

**Base URL is set via `API_BASE_URL` in your `assets/.env` file — see `.env.example` for the template.**

---

## Authentication

**All user-scoped endpoints** require the `X-User-Id` header set to the Firebase Auth UID:

```
X-User-Id: <firebase-uid>
```

The header is passed by the Flutter/web client after the user logs in via Firebase Auth. The Worker trusts this value (hackathon scope — add token verification later for production).

---

## Content endpoints (no auth required)

### Health check
```
GET /health
```
Response: `{ "status": "ok", "db": "vens-hub-questions" }`

### List all departments
```
GET /departments
```
Response: `{ "departments": [{ "name", "code", "course_count" }, ...] }`

**Department codes:** `AER`, `BIO`, `CHE`, `CIV`, `COM`, `ELE`, `MEC`, `MCT`, `PET`

### List courses for a department
```
GET /departments/:code/courses
```
Example: `/departments/AER/courses`

### List all courses
```
GET /courses
```

### Get a single course
```
GET /courses/:courseCode
```
Example: `/courses/AAE%20101` (URL-encode spaces)

### Get questions for a course
```
GET /courses/:courseCode/questions
GET /questions/:courseCode
```
Example: `/courses/AAE%20101/questions`
Returns array of question objects with topic, options, correct answer, explanation.

### Study material signed upload flow

```
POST /uploads/presign
PUT  /uploads/direct?object_key=...
POST /uploads/finalize
```

The React web migration calls `/uploads/presign`, uploads the file bytes to the returned `upload.url`, then calls `/uploads/finalize` for the metadata record. The Worker stores bytes in the `STUDY_MATERIALS_BUCKET` R2 binding and returns public URLs using `R2_PUBLIC_DOMAIN`.

Required Worker configuration:

```bash
wrangler secret put UPLOAD_SIGNING_SECRET
# optional, only if the assistant is enabled
wrangler secret put GEMINI_API_KEY
```

### AI assistant

```
POST /assistant
```

Request:

```json
{ "question": "Explain lift", "context": "AAE 101 quiz" }
```

The endpoint uses `GEMINI_API_KEY` and `GEMINI_MODEL` to call Gemini and returns `{ "answer": "..." }`. If the secret is not configured, the endpoint returns a clear 501 error so the web client can fall back safely.

---

## Adaptive endpoints (stateless BKT)

### Submit answer (single)
```
POST /adaptive/submit-answer
```
Request body:
```json
{
  "questionId": 162512,
  "selectedAnswerIndex": 0,
  "attemptId": "<uuid>",
  "clientElapsedSeconds": 30,
  "kcState": null
}
```
- `kcState` — optional, the current KC state for this topic (null on first attempt)
- `attemptId` — client-generated UUID for dedup

Response:
```json
{
  "status": "applied",
  "isCorrect": true,
  "masteryBefore": 0.15,
  "masteryAfter": 0.43,
  "sParameter": 1.0,
  "kcStatus": "learning",
  "totalAttempts": 1,
  "correctAttempts": 1,
  "updatedKcState": { ... }
}
```

If `X-User-Id` header is set, the Worker additionally:
1. **Inserts** a row into `user_attempts` (answer log)
2. **Upserts** the mastery state into `user_mastery`

### Submit batch (quiz completion)
```
POST /adaptive/submit-batch
```
Used by the Flutter completion screen to sync quiz results to the adaptive engine.
Accepts per-topic results and runs BKT for each.

Request body:
```json
{
  "results": [
    { "topicName": "Aerodynamics", "courseCode": "AAE 101", "isCorrect": true },
    { "topicName": "Aerodynamics", "courseCode": "AAE 101", "isCorrect": false }
  ]
}
```
Response: `{ "status": "applied", "count": 2 }`

Each result:
- `topicName` — topic/KC name (maps to question topics in D1)
- `courseCode` — course code
- `isCorrect` — whether the answer was correct

The Worker loads existing mastery from D1 (if any), runs BKT, inserts attempt log, and upserts mastery.

### Get state summary (course aggregation)
```
POST /adaptive/state
```
Request: `{ "kcStates": { "<topic>": { "masteryProb": 0.85, ... }, ... } }`

Response:
```json
{
  "courses": {
    "AAE 101": {
      "masteryAvg": 0.72,
      "totalKcs": 5,
      "masteredKcs": 3,
      "status": "learning"
    }
  }
}
```

---

## User Performance endpoints (require `X-User-Id`)

### Get all mastery records
```
GET /user/mastery
Header: X-User-Id: <firebase-uid>
```
Returns every KC (topic) the user has studied:
```json
{
  "topics": [
    {
      "topic_name": "Aerodynamics",
      "course_code": "AAE 101",
      "mastery_prob": 0.85,
      "s_parameter": 4.0,
      "status": "reviewing",
      "total_attempts": 12,
      "correct_attempts": 9,
      "last_attempt_at": "2026-07-02T10:30:00.000Z",
      "next_review_due": "2026-07-06T10:30:00.000Z"
    }
  ]
}
```

### Get mastery for a specific course
```
GET /user/mastery/:courseCode
Header: X-User-Id: <firebase-uid>
```
Example: `/user/mastery/AAE%20101`

Returns per-topic mastery plus course aggregates:
```json
{
  "courseCode": "AAE 101",
  "topics": [ ... ],
  "avgMastery": 0.72,
  "masteredKcs": 3,
  "totalKcs": 5
}
```

### Get course-level stats
```
GET /user/stats
Header: X-User-Id: <firebase-uid>
```
Returns rollup stats per course:
```json
{
  "courses": {
    "AAE 101": {
      "totalKcs": 5,
      "masteredKcs": 3,
      "avgMastery": 0.72,
      "totalAttempts": 42,
      "correctAttempts": 31,
      "lastActivityAt": "2026-07-02T10:30:00.000Z"
    }
  }
}
```

### Get attempt history (paginated)
```
GET /user/attempts?course=AAE%20101&limit=50&cursor=2026-07-01T12:00:00.000Z
Header: X-User-Id: <firebase-uid>
```
Optional query params:
- `course` — filter by course code
- `limit` — page size (default 50, max 200)
- `cursor` — ISO 8601 timestamp for cursor-based pagination (use `nextCursor` from previous response)

Response:
```json
{
  "attempts": [
    {
      "id": "<uuid>",
      "user_id": "<uid>",
      "question_id": 162512,
      "course_code": "AAE 101",
      "topic_name": "Aerodynamics",
      "is_correct": 1,
      "selected_answer_index": 0,
      "elapsed_seconds": 30,
      "mastery_before": 0.15,
      "mastery_after": 0.43,
      "created_at": "2026-07-02T10:30:00.000Z"
    }
  ],
  "nextCursor": "2026-07-01T09:15:00.000Z",
  "limit": 50
}
```

### Seed mastery from client cache
```
POST /user/seed-mastery
Header: X-User-Id: <firebase-uid>
```
One-time upload for migrating existing local KC states (from Flutter's get_storage) to the server:
```json
{
  "kcStates": {
    "<topic_name>": {
      "masteryProb": 0.85,
      "sParameter": 4.0,
      "status": "reviewing",
      "totalAttempts": 10,
      "correctAttempts": 8,
      "lastAttemptAt": "2026-07-01T10:00:00.000Z"
    }
  }
}
```
Response: `{ "seeded": 12, "message": "Seeded 12 KC states for user <uid>" }`

---

## Error responses

**400 — Bad request:**
```json
{ "error": "questionId, selectedAnswerIndex, and attemptId required" }
```
**401 — Missing auth:**
```json
{ "error": "X-User-Id header required" }
```
**404 — Not found:**
```json
{ "error": "Not found" }
```
**500 — Internal error:**
```json
{ "error": "Internal error: <message>" }
```

---

## D1 schema

### Static data
- `courses` — 426 engineering courses
- `departments` — 9 departments
- `questions` — ~142K questions with topic, difficulty, options

### User performance
- `user_attempts` — per-answer log (pk: uuid, indexed on user+course+created)
- `user_mastery` — per-KC master state (pk: user_id, course_code, topic_name)

```sql
CREATE TABLE user_attempts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  question_id INTEGER NOT NULL,
  course_code TEXT NOT NULL,
  topic_name TEXT DEFAULT '',
  is_correct INTEGER NOT NULL,
  selected_answer_index INTEGER NOT NULL,
  elapsed_seconds INTEGER DEFAULT 0,
  mastery_before REAL DEFAULT 0.15,
  mastery_after REAL DEFAULT 0.15,
  created_at TEXT NOT NULL
);

CREATE TABLE user_mastery (
  user_id TEXT NOT NULL,
  course_code TEXT NOT NULL,
  topic_name TEXT NOT NULL,
  mastery_prob REAL DEFAULT 0.15,
  s_parameter REAL DEFAULT 1.0,
  status TEXT DEFAULT 'learning',
  total_attempts INTEGER DEFAULT 0,
  correct_attempts INTEGER DEFAULT 0,
  last_attempt_at TEXT NOT NULL,
  next_review_due TEXT DEFAULT '',
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, course_code, topic_name)
);
```

---

## Deployment

```bash
cd workers/api
npx wrangler deploy --env=""
```

The Worker is at `workers/api/src/index.js` with D1 binding `QUESTIONS_DB` → `vens-hub-questions`.
