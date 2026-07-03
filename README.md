# Vens Hub

Adaptive study platform for engineering students. Uses Bayesian Knowledge Tracing and spaced repetition to help students learn smarter, not harder.

**Built for BuildVerse 2026 · The John Amhanesi Foundation**

## Live

- **Web app:** [venshub.nasurf25.workers.dev](https://venshub.nasurf25.workers.dev)
- **API:** [vens-hub-api.nasurf25.workers.dev](https://vens-hub-api.nasurf25.workers.dev)

## Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Mobile | Flutter (Dart) | Native Android app |
| Web | React 19 + Vite 8 + TypeScript 6 | SPA web frontend |
| API | Cloudflare Workers | Edge API server |
| Database | Cloudflare D1 (SQLite) | 8 tables, 142K questions, 426 courses |
| Storage | Cloudflare R2 | Study material uploads (S3-compatible) |
| Auth | Firebase Auth | Email/password + Google sign-in |
| AI | Google Gemini (gemma-4-31b-it) | Quiz generation, AI assistant |
| Embeddings | Cloudflare Workers AI (BGE-M3) | Semantic search over course content |
| Content Gen | CourseGen (Python) | PDF → OCR → RAG → Question pipeline |
| OCR | Gemini / EasyOCR / PaddleOCR | Textbook text extraction |
| Vector DB | ChromaDB (local DuckDB+Parquet) | RAG retrieval for question generation |

## Architecture

```
┌─────────────────┐     ┌──────────────────┐
│   Flutter App    │     │   React Web App   │
│   (vens_app/)    │     │   (vens_web/)     │
└────────┬────────┘     └────────┬─────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │   Cloudflare Worker   │
         │   API (workers/api/)  │
         │                       │
         │  ┌─────┐  ┌─────┐   │
         │  │ D1  │  │ R2  │   │
         │  │(SQL)│  │(S3) │   │
         │  └─────┘  └─────┘   │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │     Firebase Auth     │
         │  (Google + Email)     │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │    Google Gemini API   │
         │  (gemma-4-31b-it)     │
         └───────────────────────┘
```

## Repository Structure

```
vens-hub/
├── vens_app/              # Flutter mobile app (Android)
│   ├── lib/               # Dart source (168 files)
│   │   ├── core/          # Config, services, theme, router (73 files)
│   │   ├── data/          # Models, repositories, data sources (18 files)
│   │   ├── domain/        # Use cases, repository interfaces (17 files)
│   │   ├── presentation/  # Screens, widgets, BLoCs (57 files)
│   │   └── adaptive/      # Adaptive learning client (4 files)
│   ├── android/           # Android platform config
│   ├── test/              # Unit + widget tests (3 files)
│   ├── assets/            # Fonts, SVGs, Lottie animations
│   └── pubspec.yaml       # Flutter dependencies
│
├── vens_web/              # React web frontend
│   ├── src/
│   │   ├── App.tsx         # All app components (~4541 lines)
│   │   ├── index.css       # Design system (6233 lines)
│   │   ├── profile.css     # Profile page styles (899 lines)
│   │   ├── adaptive.ts     # Adaptive learning API client
│   │   ├── flashcards.ts   # Flashcard scheduler (Ebbinghaus)
│   │   ├── firebase.ts     # Firebase auth wrappers
│   │   └── LatexText.tsx   # KaTeX LaTeX renderer
│   ├── public/brand/       # Logo, fonts (Geist)
│   ├── scripts/smoke.cjs   # Playwright E2E smoke test
│   ├── package.json
│   ├── vite.config.ts
│   ├── wrangler.toml       # Cloudflare Pages deployment
│   └── tsconfig.json
│
├── workers/
│   └── api/               # Cloudflare Worker API
│       ├── src/
│       │   ├── index.js    # All endpoints (1405 lines)
│       │   └── bkt.js      # BKT adaptive engine (92 lines)
│       ├── schema-v2.sql   # D1 database schema (8 tables)
│       ├── wrangler.toml   # Worker config (D1 + R2 bindings)
│       └── migrate-to-v2.mjs  # Migration script
│
├── coursegen/              # Python content generation pipeline
│   ├── services/
│   │   ├── RAG/            # PDF → OCR → chunk → embed → Chroma
│   │   ├── QuestionRag/    # Question generation from RAG context
│   │   ├── Gemini/         # Google Gemini API client + key rotation
│   │   ├── Cloudflare/     # R2 upload + BGE-M3 embeddings
│   │   ├── Email/          # SMTP notification service
│   │   └── Ollama/         # Local embedding fallback
│   ├── data_models/        # Pydantic models (10 files)
│   ├── tests/              # Integration + unit tests (10 files)
│   ├── Dockerfile          # Full build (OCR + embeddings)
│   ├── Dockerfile.minimal  # CPU-only build
│   ├── build.sh            # ECR deploy script (659 lines)
│   ├── run.sh              # Container runner (337 lines)
│   └── config.py           # Centralized configuration
│
├── docs/                   # Project documentation
│   ├── api-reference.md    # Full API reference
│   ├── adaptive-learning-engine.md  # BKT spec (691 lines)
│   ├── DEPLOYMENT.md       # Deployment guide
│   └── plans/              # Implementation plans
│
├── pitch-deck/             # Investor pitch deck
│   ├── deck.html           # 11-slide HTML deck
│   ├── slides/             # Rendered slide images
│   └── build_pptx.py       # PowerPoint generator
│
├── courses.json            # Course catalog (426 courses, 66K lines)
├── deploy.sh               # Worker deployment script
└── .firebaserc             # Firebase project config
```

---

## Quick Start

### Web App (vens_web/)

```bash
cd vens_web
npm install
cp env.example .env          # Configure API_BASE_URL
npm run dev                   # Dev server on :5173
npm run build                 # Production build
npm run lint                  # Oxlint
npm run smoke                 # Playwright smoke test
```

### Flutter App (vens_app/)

```bash
cd vens_app
flutter pub get
flutter run                    # Run on connected device/emulator
flutter test                   # Run all tests
flutter analyze                # Lint
flutter build apk              # Build Android APK
```

### API Worker (workers/api/)

```bash
cd workers/api
npm install
npx wrangler dev               # Local dev server
npx wrangler deploy            # Deploy to Cloudflare
```

**Required secrets:**
```bash
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put UPLOAD_SIGNING_SECRET
```

### CourseGen Pipeline (coursegen/)

```bash
cd coursegen
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Generate questions
python -m services.QuestionRag.pipelines.question_generator --course-code "EEE 315"

# Generate course outlines
python -m services.QuestionRag.pipelines.course_outline_generator --all-courses

# Build Docker image
./build.sh
```

### Deployment

```bash
# Deploy Cloudflare Worker API
./deploy.sh

# Deploy web app to Cloudflare Pages
cd vens_web && npx wrangler pages deploy dist/
```

---

## API Reference

**Base URL:** `https://vens-hub-api.nasurf25.workers.dev`

### Content Endpoints (Public)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/departments` | List all 9 departments |
| GET | `/departments/:code/courses` | Courses in a department (paginated) |
| GET | `/courses` | Search/filter courses |
| GET | `/courses/:code` | Single course detail |
| GET | `/courses/:code/questions` | Questions for a course |

### AI Assistant

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/assistant` | Gemini-powered Q&A (single-turn or multi-turn chat) |

**Request body:**
```json
{
  "question": "What is Ohm's law?",
  "context": "Course: EEE 211, Topic: Circuit Analysis",
  "messages": [
    {"role": "user", "text": "What is Ohm's law?"}
  ]
}
```

### Adaptive Learning (requires `X-User-Id` header)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/adaptive/submit-batch` | Submit batch quiz results for BKT update |
| POST | `/adaptive/submit-answer` | Submit single answer with dedup |
| POST | `/adaptive/state` | Aggregate KC states into course summaries |

### User Performance (requires `X-User-Id` header)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/user/profile` | Get user profile |
| POST | `/user/profile` | Create/update user profile |
| GET | `/user/stats` | Cross-course rollup stats |
| GET | `/user/mastery` | All topic mastery records |
| GET | `/user/mastery/:courseCode` | Per-topic mastery for a course |
| GET | `/user/attempts` | Cursor-paginated attempt history |
| POST | `/user/seed-mastery` | Migrate local KC states from Flutter |
| GET | `/user/flashcards` | Get flashcard attempts + states |
| POST | `/user/flashcards/sync` | Sync flashcards from web localStorage |
| GET | `/user/quiz-attempts` | Get quiz attempt summaries |
| POST | `/user/quiz-attempts/sync` | Sync quiz attempts from web localStorage |

### Study Material Uploads (requires HMAC signature)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/uploads/presign` | Generate signed upload URL |
| PUT | `/uploads/direct` | Direct R2 upload with signature verification |
| POST | `/uploads/finalize` | Confirm upload, return metadata |

---

## D1 Database Schema

8 tables across content and user performance data.

### Content Tables

**`courses`** (426 rows)
| Column | Type | Description |
|--------|------|-------------|
| code | TEXT PK | e.g. "EEE 315" |
| title | TEXT | Course name |
| type | TEXT | CORE, ELECTIVE |
| units | INTEGER | Credit units |
| levels | TEXT (JSON) | ["300", "400"] |
| semesters | TEXT (JSON) | ["1", "2"] |
| description | TEXT | Course description |
| outline | TEXT (JSON) | Topics with subtopics |
| department | TEXT | Department name |
| department_code | TEXT | e.g. "EEE" |
| question_count | INTEGER | Number of questions |

**`departments`** (9 rows)
| Column | Type | Description |
|--------|------|-------------|
| code | TEXT PK | e.g. "EEE", "AER" |
| name | TEXT | Department name |
| course_count | INTEGER | Number of courses |
| courses | TEXT (JSON) | Array of course codes |
| question_count | INTEGER | Total questions |

**`questions`** (~142K rows)
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| course_code | TEXT | FK to courses |
| topic_name | TEXT | Indexed |
| subtopic_name | TEXT | |
| question_type | TEXT | theory, calculation |
| difficulty | TEXT | easy, medium, hard |
| difficulty_ranking | INTEGER | Numeric rank |
| question | TEXT | Question body |
| options | TEXT (JSON) | Array of 4 options |
| correct_answer_index | INTEGER | 0-3 |
| explanation | TEXT | Answer explanation |
| solution_steps | TEXT (JSON) | Step-by-step solution |

### User Performance Tables

**`user_profiles`**
| Column | Type | Description |
|--------|------|-------------|
| user_id | TEXT PK | Firebase UID |
| first_name | TEXT | |
| last_name | TEXT | |
| email | TEXT | |
| department_code | TEXT | |
| selected_courses | TEXT (JSON) | Array of course codes |

**`user_attempts`** (per-question results)
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT PK | UUID |
| user_id | TEXT | Firebase UID |
| question_id | INTEGER | FK to questions |
| course_code | TEXT | |
| is_correct | INTEGER | Boolean |
| mastery_before | REAL | BKT prior P(L) |
| mastery_after | REAL | BKT posterior P(L) |
| elapsed_seconds | INTEGER | Time spent |

**`user_mastery`** (per-topic knowledge state)
| Column | Type | Description |
|--------|------|-------------|
| user_id + course_code + topic_name | Composite PK | |
| mastery_prob | REAL | Current P(L) |
| s_parameter | REAL | Spaced repetition stability |
| status | TEXT | "learning" or "reviewing" |
| total_attempts | INTEGER | |
| correct_attempts | INTEGER | |
| next_review_due | TEXT | Next spaced repetition date |

**`user_flashcard_attempts`** + **`user_flashcard_states`** — Ebbinghaus-based spaced repetition for flashcard review.

---

## Adaptive Learning Engine (BKT)

### Bayesian Knowledge Tracing

The engine uses a 4-parameter BKT model to estimate mastery per knowledge component:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| P(L₀) | 0.15 | Initial mastery probability |
| P(T) | 0.12 | Learning transition rate (per attempt) |
| P(S) | 0.10 | Slip probability (know it, get it wrong) |
| P(G) | 0.25 | Guess probability (don't know, get it right) |

### Update Rules

**Correct answer:**
```
P(L|correct) = P(L) × (1 - P(S)) / P(correct)
P(correct) = P(L) × (1 - P(S)) + (1 - P(L)) × P(G)
P(Lₙ₊₁) = P(L|correct) + (1 - P(L|correct)) × P(T)
```

**Incorrect answer:**
```
P(L|incorrect) = P(L) × P(S) / P(wrong)
P(wrong) = 1 - P(correct)
P(Lₙ₊₁) = P(L|incorrect) + (1 - P(L|incorrect)) × P(T)
```

### Spaced Repetition

When mastery exceeds the review threshold (0.75), the student enters "reviewing" status with spaced repetition scheduling:

| Factor | Effect |
|--------|--------|
| Correct in review | Stability × 2.0 |
| Incorrect in review | Stability × 0.5 |
| Minimum spacing | 0.25 days (~6 hours) |
| Status regression | Drops back to "learning" if mastery falls below threshold |

---

## CourseGen Pipeline

### Content Generation Flow

```
PDF Textbooks (data/textbooks/)
    │
    ▼
┌─────────────────────┐
│  RAG Ingestion       │
│  (convert_to_        │
│   embeddings.py)     │
│                      │
│  1. PyMuPDF extract  │
│  2. OCR fallback     │
│     (Gemini/EasyOCR) │
│  3. Chunk (200-1600  │
│     chars, 80 overlap)│
│  4. Dedup (SHA1)     │
│  5. Embed (BGE-M3)   │
│  6. Store (ChromaDB)  │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Question Generation │
│  (question_          │
│   generator.py)      │
│                      │
│  1. RAG retrieval    │
│     (temperature     │
│      sampling)       │
│  2. Prompt building  │
│  3. Gemini API call  │
│  4. JSON repair      │
│  5. Validation       │
│  6. Cache to disk    │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  D1 Upload           │
│  (build.sh --deploy) │
└─────────────────────┘
```

### Question Types

- **Calculation** — Numerical problem with step-by-step solution
- **Theory** — Conceptual question with explanation
- **Gap Fill** — Missing term identification

### Embedding Strategy

- **Model:** `@cf/baai/bge-m3` (Cloudflare Workers AI)
- **Batching:** Adaptive (8-100 per request), token-capped at 7500
- **Search:** K=50 pool → final_k=8-12 via temperature sampling
- **Prefix:** `"passage: "` prepended to each text chunk

### Chunking Strategy

- Paragraph grouping: 2 paragraphs per chunk
- Sentence overlap: 2 sentences from previous chunk
- Dedup: SHA1-based across all chunks
- Streaming: Embeddings written to JSONL, not held in memory

### Docker

```bash
# Full build (with OCR support)
docker build -t coursegen .

# Minimal build (CPU-only)
docker build -t coursegen-minimal -f Dockerfile.minimal .

# Run with Docker Compose
docker compose up coursegen-questions  # Generate questions
docker compose up coursegen-outlines   # Generate outlines
```

**Requirements:** 8GB RAM, 2 CPUs, Docker BuildKit

---

## Web App Components

### Pages

| Page | Component | Description |
|------|-----------|-------------|
| Landing | `LandingPage` | Hero with CTA, feature list, device mockup |
| Login | `LoginPage` | Email/password + Google sign-in |
| Register | `RegisterPage` | 4-step registration (Name → Dept → Courses → Account) |
| Dashboard | `DashboardPage` | Welcome, streak card, course workspace grid |
| Courses | `CoursesPage` | Catalog with search, department/level filters, pagination |
| Course Detail | `CourseDetailPage` | Outline, expandable topics/subtopics |
| Quiz Setup | `QuizSetupPage` | Type selector (calculation/theory), question count slider |
| Multiple Choice | `MultipleChoiceQuizMode` | Answer selection, check, explanation, AI assistant |
| Theory Quiz | `TheoryQuizMode` | Textarea answer, token-based scoring, feedback |
| Gap Fill | `GapFillQuizMode` | Pick correct missing term |
| Quiz Completion | `QuizCompletion` | Score, percentage, topic breakdown, adaptive sync |
| Flashcards | `FlashcardsPage` | Scroll-snap feed, stats, sync status |
| Flashcard Card | `FlashcardCardUI` | Flip card, explanation popup, AI explain, rate buttons |
| Schedule | `SchedulePage` | Week/day view, event CRUD, calendar picker |
| Hub | `HubPage` | Metrics, adaptive mastery overview, course performance |
| Streaks | `StreaksPage` | Calendar grid, personal/friends tabs |
| Course Analytics | `CourseAnalyticsPage` | Per-course mastery chart, strengths/weaknesses |
| Profile | `ProfilePage` | Avatar, stats, theme/scheme picker, courses editor, account |
| AI Assistant | `AIAssistantPanel` | Floating overlay chat panel |

### Design System

- **CSS Custom Properties** — Tokens for colors, typography, spacing, radius
- **7 Color Schemes** — Teal, Blue, Purple, Pink, Orange, Green, Slate
- **Dark Mode** — `[data-theme="dark"]` selector overrides all tokens
- **Responsive** — Breakpoints at 1180px, 860px, 760px, 480px, 360px
- **Reduced Motion** — `prefers-reduced-motion` support throughout
- **Fonts** — Geist (web), Nunito Sans (mobile)

### Key Features

- **Adaptive Learning** — Server-authoritative BKT with real-time mastery tracking
- **Flashcards** — Ebbinghaus spaced repetition with SM-2-derived ease factors
- **Quiz Modes** — Multiple choice, theory (text-based scoring), gap fill
- **AI Assistant** — Gemini-powered Q&A overlay on every quiz
- **Schedule** — Week/day views with CRUD, calendar picker
- **Streaks** — Daily engagement tracking with calendar visualization
- **Theme System** — 7 color schemes × light/dark mode
- **Offline-First** — localStorage hydration → remote sync on connect

---

## Flutter App Architecture

### State Management

| Pattern | Used For |
|---------|----------|
| BLoC | Auth, Course, Quiz |
| GetX Controller | Home, Schedule, Theme |
| Cubit | Course (alternative) |

### Key Services

| Service | Responsibility |
|---------|----------------|
| `FirebaseAuthService` | Email/password + Google sign-in |
| `FireStoreServices` | User CRUD, courses, timetable, quiz analytics |
| `GeminiService` | AI question generation (gemma-4-31b-it) |
| `QuestionGenerationService` | Unified MCQ/gap-fill/theory generation |
| `ThemeService` | 7 color schemes × 2 brightness modes |
| `StreakService` | Local SharedPreferences + Firestore sync |
| `NotificationService` | FCM + local notifications, department topics |
| `R2StorageService` | Cloudflare R2 signed uploads |
| `AnalyticsService` | 18 Firebase Analytics event types |

### Platform Support

| Platform | Status |
|----------|--------|
| Android | ✅ Configured |
| iOS | ❌ Not configured |
| Web | ⚠️ Code has `kIsWeb` checks but no web config |

---

## Environment Variables

### Web App (vens_web/.env)

| Variable | Description |
|----------|-------------|
| `VITE_API_BASE_URL` | API Worker URL (default: `https://vens-hub-api.nasurf25.workers.dev`) |
| `VITE_ASSISTANT_API_BASE` | AI assistant endpoint (defaults to API_BASE) |

### API Worker (workers/api/wrangler.toml)

| Variable | Description |
|----------|-------------|
| `GEMINI_API_KEY` | Google Gemini API key (secret) |
| `UPLOAD_SIGNING_SECRET` | HMAC secret for upload signatures (secret) |
| `R2_PUBLIC_DOMAIN` | Public URL for R2 assets |
| `GEMINI_MODEL` | Model name (default: `gemma-4-31b-it`) |

### Flutter App (vens_app/assets/.env.example)

| Variable | Description |
|----------|-------------|
| `GEMINI_API_KEY` | Google Gemini API key |
| `OPENAI_API_KEY` | OpenAI API key (alternative) |

### CourseGen (coursegen/.env)

| Variable | Description |
|----------|-------------|
| `GOOGLE_API_KEY` | Google Gemini API key |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `TESSDATA_PREFIX` | Tesseract data path |
| `CF_EMBED_MAX_BATCH` | Cloudflare embedding batch size |
| `BILLING_ENABLED` | Enable token cost tracking |

---

## Deployment

### Cloudflare Worker API

```bash
cd workers/api
npx wrangler deploy
```

### Cloudflare Pages (Web)

```bash
cd vens_web
npm run build
npx wrangler pages deploy dist/
```

### Flutter Android

```bash
cd vens_app
flutter build apk --release
```

### CourseGen (ECR)

```bash
cd coursegen
./build.sh --deploy          # Build + push to ECR
./run.sh                     # Pull + run from ECR
```

**ECR Repository:** `888429341445.dkr.ecr.us-east-1.amazonaws.com/rag:latest`

---

## D1 Migration

```bash
cd workers/api
npx wrangler d1 execute vens-hub-questions-v2 --remote --file=schema-v2.sql
```

**Migration script:** `migrate-to-v2.mjs` — migrates from old schema to v2 with indexed tables.

---

## Testing

### Web App

```bash
cd vens_web
npm run smoke                 # Playwright E2E (auth → AI → flashcards → quizzes)
npm run lint                  # Oxlint
```

### Flutter App

```bash
cd vens_app
flutter test                   # All tests
flutter test test/auth_bloc_test.dart  # Auth BLoC
```

### CourseGen

```bash
cd coursegen
pytest -q                     # All tests
pytest tests/test_batch_utils.py  # Batch utils
pytest tests/test_json_sanitizer.py  # JSON repair
```

### API Worker

```bash
cd workers/api
npx wrangler dev               # Local testing
curl localhost:8787/health     # Health check
```

---

## Team

**Nasurf** — [GitHub](https://github.com/Nasurf)

## License

MIT
