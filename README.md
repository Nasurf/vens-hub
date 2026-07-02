# Vens Hub

Collaborative learning platform for Nigerian engineering students. Built for BuildVerse hackathon.

**Stack:** Flutter (mobile + web) · Cloudflare Workers API · D1 database · Firebase Auth

## Quick links

- **API docs:** [`workers/api/README.md`](workers/api/README.md)
- **D1 schema:** [`bin/d1_schema.sql`](bin/d1_schema.sql), [`bin/d1_migration_performance.sql`](bin/d1_migration_performance.sql)
- **Adaptive engine:** [`lib/adaptive/`](lib/adaptive/) — BKT-based (server-authoritative)
- **Worker source:** [`workers/api/src/index.js`](workers/api/src/index.js)

## Architecture

```
Web UI ──┐
         ├── HTTP ──▶ Cloudflare Worker ──▶ D1 (questions, courses, user stats)
Flutter ─┘              │
                        └── Firebase Auth (login only — email + Google)
```

- All data (questions, courses, user performance) lives on **Cloudflare D1**
- Adaptive engine runs **server-side** — BKT computation on the Worker
- **Firebase Auth** handles login only — the Worker receives the Firebase UID via `X-User-Id` header
- No Firebase Firestore dependency for backend data

## Setup

### Environment

Copy `assets/.env.example` to `assets/.env` and fill in the values.

### Flutter

```bash
flutter pub get
flutter run
```

### Worker deployment

```bash
# Quick deploy
./deploy.sh

# Or manually
cd workers/api
npx wrangler deploy --env=""
```

### Configure environment

```bash
# Configure secrets (Gemini API key, upload signing secret)
./configure.sh
```

### D1 migrations

```bash
# Apply performance tables to dev
npx wrangler d1 execute vens-hub-questions --file=../../bin/d1_migration_performance.sql
# Apply to production
npx wrangler d1 execute vens-hub-questions --file=../../bin/d1_migration_performance.sql --remote
```

### Backfill questions

If courses are missing questions in D1:

```bash
cd bin
python3 backfill_questions.py
```

For full deployment documentation, see [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).
## Adaptive Learning

The adaptive engine uses **Bayesian Knowledge Tracing (BKT)**:

- **Stateless** — client sends current KC state, Worker runs BKT, returns updated state
- **Persistent** — every answer is logged in `user_attempts` + per-KC mastery in `user_mastery`
- **Local cache** — Flutter caches KC states in `get_storage` for fast offline access
- **Server authority** — Worker is always the source of truth for mastery computation

### Data flow

1. User answers a question
2. Flutter sends `POST /adaptive/submit-answer` with `{ questionId, selectedAnswerIndex, attemptId, kcState? }`
3. Worker looks up question in D1, computes correctness, runs BKT
4. Worker persists attempt log + upserts mastery state to D1
5. Returns `{ isCorrect, masteryBefore, masteryAfter, updatedKcState, explanation }`

### Quiz completion sync

When a quiz ends, `AdaptiveService.submitBatch()` sends per-topic results to the Worker, which runs BKT and persists. This ensures every quiz session is recorded even if individual answer submissions don't happen.

## Project structure

```
lib/
├── adaptive/           # Adaptive engine client (Dart package)
│   └── lib/src/
│       ├── adaptive_service.dart   # HTTP client for Worker endpoints
│       ├── adaptive_types.dart     # Response/request models
│       └── adaptive_fixtures.dart  # Test fixtures
├── core/
│   ├── config/         # Environment config
│   ├── services/
│   │   ├── adaptive/   # AdaptiveStorageService (get_storage cache)
│   │   ├── auth/       # FirebaseAuthService
│   │   ├── data/       # FireStoreServices (timetables, events)
│   │   ├── storage/    # Cloudflare R2, Firebase Storage
│   │   └── analytics/  # Firebase Analytics wrapper
│   └── di/             # Dependency injection
├── data/
│   ├── auth/           # Auth repository
│   ├── models/         # UserModel, CourseInfo, Question
│   └── datasources/    # Remote data sources
├── domain/             # Domain layer (business logic)
└── presentation/
    ├── blocs/          # BLoC state management
    │   ├── auth/       # AuthBloc
    │   ├── quiz/       # QuizBloc
    │   └── home/       # HomeController (GetX)
    ├── screens/        # UI screens
    └── widgets/        # Shared widgets

workers/
└── api/
    └── src/
        ├── index.js    # Worker entry point (all routes)
        └── bkt.js      # BKT math engine
```

## D1 schema

### Questions & Courses (static data)

```sql
courses     -- 426 engineering courses, indexed by code
departments -- 9 engineering departments (AER, BIO, CHE, CIV, COM, ELE, MEC, MCT, PET)
questions   -- ~142K questions with topic, difficulty, options, explanations
```

### User Performance (dynamic data)

```sql
user_attempts -- Per-answer log (pk: uuid, indexed by user+course+created_at)
user_mastery  -- Per-KC mastery state (pk: user_id, course_code, topic_name)
```

## Deployment

### Worker

```bash
cd workers/api
npx wrangler deploy --env=""
```

### D1

```bash
wrangler d1 execute vens-hub-questions --remote --file=path/to/schema.sql
```
