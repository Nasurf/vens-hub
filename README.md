# Vens Hub

Adaptive study platform for engineering students. Uses Bayesian Knowledge Tracing and spaced repetition to help students learn smarter, not harder.

**Built for BuildVerse 2026 · The John Amhanesi Foundation**

## Live

- **Web app:** [venshub.nasurf25.workers.dev](https://venshub.nasurf25.workers.dev)
- **API:** [vens-hub-api.nasurf25.workers.dev](https://vens-hub-api.nasurf25.workers.dev)

## Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter |
| Web | React + Vite + TypeScript |
| API | Cloudflare Workers |
| Database | Cloudflare D1 (142K questions, 426 courses) |
| Storage | Cloudflare R2 (study materials) |
| Auth | Firebase Auth (email + Google) |
| AI | Google Gemini (assistant) |
| Content Generation | CourseGen (PDF → OCR → RAG → Questions) |

## Architecture

```
┌─────────────┐
│  Flutter App │
└──────┬──────┘
       │
┌──────┴──────┐     ┌──────────────────┐
│  React Web  │────▶│ Cloudflare Worker │
└─────────────┘     │   (API + BKT)    │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────┴────┐  ┌─────┴─────┐  ┌────┴────┐
         │   D1    │  │    R2     │  │ Firebase │
         │(courses,│  │ (uploads) │  │  (auth)  │
         │questions│  └───────────┘  └─────────┘
         │ user    │
         │ stats)  │
         └─────────┘
```

## What It Does

### For Students
- **Adaptive Quizzes** — Bayesian Knowledge Tracing tracks mastery per topic
- **Spaced Repetition** — schedules reviews when you're about to forget
- **3 Quiz Modes** — multiple choice, theory, gap-fill
- **AI Assistant** — ask questions, get explanations
- **Flashcards** — review system with sync across devices
- **Course Browser** — 426 courses across 9 engineering disciplines

### For the System
- 142,000 questions with topic, difficulty, options, and explanations
- 9 engineering departments: Aeronautical, Biomedical, Chemical, Civil, Computer, Electrical, Mechanical, Mechatronics, Petroleum
- Server-side adaptive engine — BKT computation on the Worker
- User performance tracking — per-answer logs and per-topic mastery states

## Project Structure

```
vens-hub/
├── vens-hub-web/          # React web app (Vite + TypeScript)
│   ├── src/
│   │   ├── App.tsx        # Main app (routing, pages, components)
│   │   ├── adaptive.ts    # Adaptive learning client
│   │   ├── flashcards.ts  # Spaced repetition engine
│   │   ├── firebase.ts    # Firebase auth config
│   │   └── LatexText.tsx  # LaTeX rendering
│   ├── wrangler.toml      # Cloudflare Pages deployment
│   └── package.json
├── workers/
│   └── api/
│       └── src/
│           ├── index.js   # Worker routes (courses, questions, adaptive, uploads)
│           └── bkt.js     # Bayesian Knowledge Tracing math
├── lib/                   # Flutter app (mobile)
│   ├── adaptive/          # Adaptive engine client (Dart)
│   ├── core/              # Services, config, DI
│   ├── data/              # Models, repositories
│   ├── domain/            # Business logic
│   └── presentation/      # UI screens, BLoC state
├── CourseGen/             # Content generation pipeline
│   ├── services/
│   │   ├── RAG/           # PDF → OCR → Embedding → ChromaDB
│   │   ├── QuestionRag/   # Question generation via Gemini
│   │   └── Gemini/        # API client with key load balancing
│   ├── data/              # Textbooks, course data
│   └── docs/              # Component documentation
├── bin/                   # D1 schemas, backfill scripts
├── docs/                  # Deployment docs
├── assets/                # Environment config
├── courses.json           # Course catalog (426 courses)
├── deploy.sh              # Worker deployment script
└── configure.sh           # Secret configuration
```

## Quick Start

### Web App

```bash
cd vens-hub-web
cp env.example .env.local
# Edit .env.local with your Firebase config
npm install
npm run dev
```

### API (Worker)

```bash
cd workers/api
npx wrangler deploy --env=""
```

### Flutter App

```bash
flutter pub get
flutter run
```

### CourseGen (Question Generation)

```bash
cd CourseGen
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with API keys

# Generate embeddings from textbooks
python -m services.RAG.convert_to_embeddings \
  -i data/textbooks/COMPILATION/EEE \
  --with-chroma \
  -c pdfs_bge_m3_cloudflare \
  --workers 4 --resume

# Generate questions
python -m services.QuestionRag.pipelines.question_generator \
  --theory-per-request 10 --calc-per-request 5
```

## Adaptive Learning Engine

Uses **Bayesian Knowledge Tracing (BKT)** — a machine learning algorithm that models student knowledge as a hidden state and updates it after every answer.

### How It Works

1. Student answers a question
2. Client sends `POST /adaptive/submit-answer` with `{ questionId, selectedAnswerIndex, attemptId, kcState }`
3. Worker looks up question in D1, computes correctness, runs BKT
4. Worker persists attempt log + upserts mastery state to D1
5. Returns `{ isCorrect, masteryBefore, masteryAfter, updatedKcState }`

### BKT Parameters

- **P(L0)** — prior probability of knowing the skill
- **P(T)** — transition probability (learning rate)
- **P(S)** — slip probability (know but get wrong)
- **P(G)** — guess probability (don't know but get right)

### Spaced Repetition

Flashcard system uses SM-2 algorithm variants:
- Tracks stability, ease factor, repetitions, and lapses
- Schedules next review based on performance history
- Syncs across devices via D1

## D1 Schema

### Static Data

```sql
courses     -- 426 engineering courses
departments -- 9 departments (AER, BIO, CHE, CIV, COM, ELE, MEC, MCT, PET)
questions   -- ~142K questions with topic, difficulty, options, explanations
```

### User Performance

```sql
user_attempts        -- Per-answer log (uuid, user, course, topic, correctness)
user_mastery         -- Per-topic mastery state (mastery_prob, s_parameter, status)
user_flashcard_attempts  -- Flashcard answer history
user_flashcard_states    -- Spaced repetition state per card
```

## CourseGen Pipeline

The question bank was generated using CourseGen — a pipeline that processes educational materials into questions:

```
PDF Textbooks → OCR → Chunking → Embedding (Cloudflare) → ChromaDB
                                                              │
                                                              ▼
                                    Course Outlines ← RAG Retrieval
                                          │
                                          ▼
                              Question Generation (Gemini)
                                          │
                                          ▼
                                    D1 Database
```

- Processes scanned and digital textbooks
- Uses RAG to retrieve relevant content for each subtopic
- Generates theory and calculation questions with explanations
- Supports resumable processing and cost tracking
- Deployed via Docker + AWS ECR

## Deployment

### Web App (Cloudflare Worker)

```bash
cd vens-hub-web
npx wrangler deploy
```

### API Worker

```bash
./deploy.sh
# Or manually:
cd workers/api
npx wrangler deploy --env=""
```

### D1 Migrations

```bash
npx wrangler d1 execute vens-hub-questions --remote --file=bin/d1_migration_performance.sql
```

## Environment Variables

### Worker API

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | Embedding provider |
| `API_KEY` | X-API-Key auth header |
| `APPWRITE_ENDPOINT` | Appwrite endpoint |
| `APPWRITE_PROJECT_ID` | Appwrite project |
| `APPWRITE_API_KEY` | Appwrite server key |
| `CLOUDFLARE_API_TOKEN` | Cloudflare Vectorize |
| `GEMINI_API_KEY` | AI assistant |
| `UPLOAD_SIGNING_SECRET` | R2 upload signing |
| `PAYSTACK_SECRET_KEY` | Payments |

### Web App (.env.local)

| Variable | Purpose |
|----------|---------|
| `VITE_API_BASE_URL` | Worker API URL |
| `VITE_FIREBASE_API_KEY` | Firebase web config |
| `VITE_FIREBASE_AUTH_DOMAIN` | Firebase auth domain |
| `VITE_FIREBASE_PROJECT_ID` | Firebase project |

## Team

Built by **Nasurf** — full-stack developer.

## License

MIT
