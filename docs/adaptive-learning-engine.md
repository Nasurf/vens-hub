# Adaptive Learning Engine — Engineering Hub

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [BKT Engine — Core Mathematics](#bkt-engine--core-mathematics)
3. [Spaced Repetition — Stability & Intervals](#spaced-repetition--stability--intervals)
4. [Firestore Data Model](#firestore-data-model)
5. [Transaction Flow](#transaction-flow)
6. [API Reference](#api-reference)
7. [Cross-Implementation Strategy (TypeScript ↔ Dart)](#cross-implementation-strategy-typescript--dart)
8. [Test Coverage](#test-coverage)
9. [Parameter Versioning & Migration](#parameter-versioning--migration)
10. [Cost Model](#cost-model)
11. [Deployment](#deployment)
12. [Key Design Decisions](#key-design-decisions)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│                    Flutter Client                      │
│  ┌──────────────┐    ┌──────────────────────────┐    │
│  │ QuizScreen   │───▶│ AdaptiveService (Dart)   │    │
│  │ (BLoC)       │    │  - submitAnswer()        │    │
│  │              │    │  - getAdaptiveState()    │    │
│  │              │    │  - getPendingReviews()   │    │
│  └──────────────┘    └───────────┬──────────────┘    │
│                                  │                    │
│  "Checking…" UI lock             │                    │
│  No local BKT computation        │                    │
└──────────────────────────────────┼───────────────────┘
                                   │ HTTPS callable
                                   ▼
┌──────────────────────────────────────────────────────┐
│              Firebase Cloud Functions                  │
│              (Node.js 22, TypeScript)                  │
│  ┌──────────────────────────────────────────────────┐ │
│  │  submitAnswer (callable)                         │ │
│  │    ├─ Input validation + auth guard              │ │
│  │    ├─ executeSubmitAnswer() in Firestore tx      │ │
│  │    │  ├─ Dedup check → cached if duplicate       │ │
│  │    │  ├─ Load answer key → compute correctness   │ │
│  │    │  ├─ Load adaptive state                     │ │
│  │    │  ├─ Resolve parameter version               │ │
│  │    │  ├─ applyBktUpdate()                        │ │
│  │    │  ├─ scheduleNextReview()                    │ │
│  │    │  └─ Write state + log + attempt record      │ │
│  │    └─ Return {masteryProb, sParameter, …}        │ │
│  │                                                  │ │
│  │  getAdaptiveState (callable)                     │ │
│  │    └─ Read adaptive_states/{uid}                 │ │
│  │                                                  │ │
│  │  getPendingReviews (callable)                    │ │
│  │    └─ Filter states where nextReviewDue ≤ now    │ │
│  └──────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

**Key principles:**

- **Server-authoritative BKT** — client has no answer keys, cannot compute correctness locally. All BKT computation happens on the server inside a Firestore transaction.
- **No optimistic UI** — client locks the submission button and shows "Checking…" until the server responds. This eliminates client/server state divergence.
- **Deterministic dedup** — each attempt is identified by `uid + attemptId`. Duplicate submissions return the cached result without mutating state a second time.
- **Massed-practice guard** — stability (S) updates only on qualified reviews where `timeDeltaDays >= minimumSpacingDays`, preventing S-inflation from rapid-fire correct answers.

---

## BKT Engine — Core Mathematics

### Bayes Knowledge Tracing (BKT) Formulation

The adaptive engine uses a two-parameter-per-KC BKT model with an additional stability parameter for spaced repetition.

### Parameters

| Symbol | Field | Default | Description |
|--------|-------|---------|-------------|
| P(L₀) | `pLearning0` | 0.15 | Initial mastery probability before any attempt |
| P(T) | `pTransition` | 0.12 | Probability of transitioning from unknown → known per opportunity |
| P(S) | `pSlip` | 0.10 | Probability of careless error on a known item |
| P(G) | `pGuess` | 0.25 | Probability of correct guess on an unknown item |
| S₀ | `sBase` | 1.0 | Base stability in days |
| S₊ | `sFactor` | 2.0 | Stability multiplier on a correct answer |
| S₋ | `sDecay` | 0.5 | Stability multiplier on an incorrect answer |
| Δ_min | `minimumSpacingDays` | 0.25 | Minimum days between qualifying reviews (≈6 hours) |
| θ | `reviewThreshold` | 0.75 | Mastery threshold for "learned" status |

### Inference Functions

#### Forward Pass: P(correct)

$$P(\text{correct}) = P(L) \cdot (1 - P(S)) + (1 - P(L)) \cdot P(G)$$

```typescript
function probabilityCorrect(masteryProb, params) {
  return masteryProb * (1 - params.pSlip)
       + (1 - masteryProb) * params.pGuess;
}
```

#### E-Step: Posterior Given Observation

**Correct answer:**

$$P(L|\text{correct}) = \frac{P(L) \cdot (1 - P(S))}{P(\text{correct})}$$

**Wrong answer:**

$$P(L|\text{wrong}) = \frac{P(L) \cdot P(S)}{P(\text{wrong})}$$

where:

$$P(\text{wrong}) = P(L) \cdot P(S) + (1 - P(L)) \cdot (1 - P(G))$$

#### M-Step: Learning Transition

$$P(L_{n+1}) = P(L_n|\text{obs}) + (1 - P(L_n|\text{obs})) \cdot P(T)$$

#### Complete Update

```typescript
function updateMastery(priorMastery, isCorrect, params) {
  // E-step
  let posterior;
  if (isCorrect) {
    const pCorr = probabilityCorrect(priorMastery, params);
    posterior = (priorMastery * (1 - params.pSlip)) / pCorr;
  } else {
    const pWrong = priorMastery * params.pSlip
                 + (1 - priorMastery) * (1 - params.pGuess);
    posterior = (priorMastery * params.pSlip) / pWrong;
  }
  // M-step
  return posterior + (1 - posterior) * params.pTransition;
}
```

### Stability Update (S-Parameter)

S updates ONLY when both conditions are met:
1. The KC is in `reviewing` status
2. Time since last qualified review ≥ `minimumSpacingDays`

$$S_{n+1} = \begin{cases} S_n \times S_+ & \text{if correct (qualified review)} \\ S_n \times S_- & \text{if incorrect (qualified review)} \\ S_n & \text{otherwise (massed practice)} \end{cases}$$

### Status Transitions

| Condition | Status |
|-----------|--------|
| P(L) < θ | `learning` |
| P(L) ≥ θ | `reviewing` |
| P(L) drops below θ after being reviewing | falls back to `learning` |

---

## Spaced Repetition — Stability & Intervals

### Next Review Interval

$$I = \max(\Delta_{\min},\; S \cdot \ln(\frac{P(L)}{\theta}))$$

```typescript
function computeIntervalDays(masteryProb, sParameter, params) {
  if (masteryProb <= params.reviewThreshold) {
    return params.minimumSpacingDays;
  }
  const raw = sParameter * Math.log(masteryProb / params.reviewThreshold);
  return Math.max(params.minimumSpacingDays, raw);
}
```

The interval grows with stability (S) and shrinks as P(L) approaches the threshold. The `minimumSpacingDays` clamp prevents review-scheduling before the minimum spacing.

### Readiness Score (Priority Ordering Within Sessions)

$$R = P(L) \cdot \exp(-\frac{\Delta t}{S})$$

Lower readiness → higher priority for review. Used to sort questions within a review session so the most-at-risk KCs are reviewed first.

### Recall Probability at Future Time

$$P(\text{recall}) = P(L) \cdot \exp(-\frac{t}{S})$$

### Key Functions

| Function | Purpose |
|----------|---------|
| `computeIntervalDays()` | Days until next review |
| `computeNextReviewDue()` | ISO timestamp of next review due |
| `computeReadiness()` | Priority score for review ordering |
| `daysBetween()` | Time delta between two ISO dates |
| `isReviewDue()` | Whether a KC is overdue for review |
| `recallProbabilityAt()` | Predicted recall at future offset |

---

## Firestore Data Model

### `adaptive_states/{uid}` — Per-User State Document

```typescript
interface AdaptiveStateDoc {
  userId: string;                            // Firebase Auth UID
  states: Record<string, KcState>;           // Key = "{courseId}__{kcSlug}"
  revision: number;                          // Monotonically increasing
  schemaVersion: number;                     // Currently 2
  updatedAt: string;                         // ISO 8601
}
```

### `KcState` — Per-Knowledge-Component State

```typescript
interface KcState {
  masteryProb: number;          // P(Lₙ)
  sParameter: number;           // Stability in days
  status: 'learning' | 'reviewing';
  lastAttemptAt: string;        // ISO timestamp of last attempt
  lastQualifiedReviewAt: string;// Last review that updated S
  nextReviewDue: string;        // When to review next
  parameterVersion: string;     // Pinned version ID
  schemaVersion: number;        // For forward compatibility
  totalAttempts: number;
  correctAttempts: number;
}
```

### `adaptive_attempts/{uid}_{attemptId}` — Dedup Record

```typescript
interface AttemptRecord {
  status: 'applied' | 'duplicate';
  createdAt: string;
  response: SubmitAnswerResult;  // Full cached response
  stateRevision: number;
}
```

### `adaptive_logs/{autoId}` — Telemetry Log

One entry per non-duplicate submission. Indexed on `(courseId ASC, kcId ASC, userId ASC, answeredAt ASC)`.

### `course_priors/{courseId}/versions/{parameterVersion}` — Parameter Version

Immutable snapshot of `BKTParams`. States pin to a version at creation time. The mutable parent document points to `currentVersion` for new states.

### `questions/{questionId}` — Question Document

Fields: `courseId`, `kcId` (or `kcSlug`), `questionType`, `numOptions`.

### `answerKeys/{questionId}` — Backend-Only Answer Key

Only accessible server-side. Contains `correctAnswerId`. Not readable by client.

### Index Exemptions

All `states` map fields are exempt from index requirements (never server-queried, only accessed by UID lookup). The only explicit index needed:

| Collection | Fields |
|------------|--------|
| `adaptive_logs` | `courseId ASC, kcId ASC, userId ASC, answeredAt ASC` |

---

## Transaction Flow

### `executeSubmitAnswer()` — Full Sequence

```
Client → submitAnswer({ questionId, selectedAnswerId, attemptId, sessionId, clientElapsedSeconds })

┌──────────────────────────────────────────────────────────┐
│ 1. Dedup Check                                           │
│    Read adaptive_attempts/{uid}_{attemptId}              │
│    └─ EXISTS → return cached SubmitAnswerResult          │
│       (no writes, no BKT)                                │
│                                                          │
│ 2. Load Answer Key                                       │
│    Read questions/{questionId}                           │
│    Read answerKeys/{questionId}                          │
│    └─ Compare selectedAnswerId vs correctAnswerId        │
│                                                          │
│ 3. Load Adaptive State                                   │
│    Read adaptive_states/{uid}                            │
│    └─ Extract KcState for {courseId}__{kcId}            │
│       (null if first attempt for this KC)                │
│                                                          │
│ 4. Resolve Parameters                                    │
│    Read course_priors/{courseId}/versions/{versionId}    │
│    └─ Use state's pinned version, or "latest", or        │
│       fallback to hardcoded defaults                     │
│                                                          │
│ 5. Determine Mode                                        │
│    isReviewMode = (current status === "reviewing")        │
│    timeDeltaDays = daysBetween(now, lastAttemptAt)       │
│                                                          │
│ 6. Apply BKT Update  (pure function)                     │
│    forwardMastery() → P(L) before                        │
│    updateMastery() → P(L) after                          │
│    applyBktUpdate() → state + S-update gate              │
│                                                          │
│ 7. Schedule Next Review  (pure function)                 │
│    computeIntervalDays() → interval                      │
│    computeNextReviewDue() → timestamp                    │
│                                                          │
│ 8. Write in Transaction                                  │
│    └─ adaptive_attempts/{uid}_{attemptId}  (SET)         │
│    └─ adaptive_states/{uid}               (SET merge)    │
│    └─ adaptive_logs/{autoId}              (SET)          │
│                                                          │
│ 9. Return SubmitAnswerResult                             │
└──────────────────────────────────────────────────────────┘
```

All steps 1–9 run inside a single `Firestore.runTransaction()` for atomicity.

---

## API Reference

### `submitAnswer` — Callable Function

**Input:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `questionId` | string | yes | ID of the question |
| `selectedAnswerId` | string | yes | ID of the answer the user selected |
| `attemptId` | string | yes | Client-generated unique attempt ID |
| `sessionId` | string | yes | Current quiz session ID |
| `clientElapsedSeconds` | number | no | Time spent on this question (default 0) |

**Response:**

```json
{
  "status": "applied" | "duplicate",
  "masteryProb": 0.4618705035971223,
  "sParameter": 1.0,
  "kcStatus": "learning",
  "nextReviewDue": "2026-06-25T10:00:00.000Z",
  "isCorrect": true,
  "stateRevision": 1
}
```

**Auth:** Requires Firebase Auth. Server derives `uid` from `context.auth.uid`.

**Errors:**
- `unauthenticated` — No auth context
- `invalid-argument` — Missing required field
- `internal` — Server error (question not found, answer key missing, etc.)

### `getAdaptiveState` — Callable Function

**Input:** None (uid from auth)

**Response:**

```json
{
  "userId": "abc123",
  "states": {
    "course1__kc-slug-1": {
      "masteryProb": 0.92,
      "sParameter": 5.0,
      "status": "reviewing",
      ...
    }
  },
  "revision": 5,
  "schemaVersion": 2,
  "updatedAt": "2026-06-24T10:00:00.000Z"
}
```

### `getPendingReviews` — Callable Function

**Input:** None (uid from auth)

**Response:**

```json
{
  "pending": [
    {
      "kcKey": "course1__kc-slug-1",
      "masteryProb": 0.88,
      "nextReviewDue": "2026-06-23T10:00:00.000Z"
    }
  ]
}
```

---

## Cross-Implementation Strategy (TypeScript ↔ Dart)

### Architecture

```
Shared Fixtures (bkt-test-cases.json)
  ├── TypeScript Tests (48 tests)
  │   ├── bkt.test.ts         — 22 BKT inference tests
  │   ├── spaced-repetition.test.ts — 18 interval tests
  │   ├── transaction.test.ts — 7 Firestore integration tests
  │   └── index.test.ts      — 1 barrel export test
  │
  └── Dart Tests (7 tests)
      └── adaptive_test_standalone.dart — 7 type/fixture tests
```

### Fixture File

`fixtures/bkt-test-cases.json` contains 10 cross-implementation test cases with pre-computed float values (verified via Python bridge for cross-platform parity). Both TypeScript and Dart load this file to ensure identical expected values.

Key test cases:

| Case ID | Description |
|---------|-------------|
| `correct-first-attempt-v2` | First attempt correct → P(L): 0.15 → 0.4619 |
| `wrong-first-attempt` | First attempt wrong → P(L): 0.15 → 0.1402 |
| `correct-after-two-wrong` | Prior P(L)=0.32, correct → 0.6734 |
| `qualified-review-correct` | Review + overdue → S: 1.0 → 2.0 |
| `massed-practice-correct` | Practice + recent → S unchanged 1.0 |
| `all-wrong-series-pT-zero` | P(T)=0 → mastery converges to ~0 |
| `all-wrong-series-pT-positive` | P(T)=0.12 → floor ≈0.19 |
| `interval-computation` | P(L)=0.88, S=4.0 → interval=0.51 days |
| `readiness-computation` | P(L)=0.85, S=3.0, Δt=1.5 → R=0.526 |

### Dart Client Mirror

```
lib/adaptive/
├── lib/
│   ├── adaptive_engine.dart        — Barrel export
│   └── src/
│       ├── adaptive_types.dart     — Dart types (fromJson/toJson)
│       ├── adaptive_service.dart   — Callable wrapper (sealed union)
│       └── adaptive_fixtures.dart  — Shared fixture loader
└── test/
    └── adaptive_test_standalone.dart — 7 tests (no Flutter dep)
```

The Dart client:
- Ships no BKT computation — server-authoritative only
- Uses a sealed `SubmitResult` union (`SubmitApplied`, `SubmitDuplicate`, `SubmitError`)
- Injects the callable function caller for easy testing/mocking
- Has no dependency on `cloud_functions` in the standalone test package (production wiring needs `cloud_functions: ^5.0.0` in the app's `pubspec.yaml`)

---

## Test Coverage

### TypeScript Engine — 48/48 tests passing

| Test File | Count | Coverage |
|-----------|-------|----------|
| `tests/bkt.test.ts` | 22 | BKT forward pass, probability correct, update mastery, status transitions, S-update gate, massed-practice guard, all-wrong convergence (with and without P(T)), division-by-zero edge |
| `tests/spaced-repetition.test.ts` | 18 | computeIntervalDays, computeNextReviewDue, computeReadiness, recallProbabilityAt, daysBetween, scheduleNextReview, timeDeltaDaysSince, zero elapsed, exactly threshold, high mastery, interval grows with S |
| `tests/transaction.test.ts` | 7 | Correct answer updates mastery, repeated attemptId returns cached dedup, wrong answer reduces mastery, massed practice S unchanged, qualified review S doubled, all-wrong converges to zero (P(T)=0), reviewing→learning status transition |
| `tests/index.test.ts` | 1 | Barrel export sanity check |

### Dart Mirror — 7/7 tests passing

| Test | Scope |
|------|-------|
| SubmitAnswerInput round-trip | JSON serialization/deserialization |
| SubmitAnswerResult applied | Applied status parsing |
| SubmitAnswerResult duplicate | Duplicate status parsing |
| KcState parses | Full state parsing |
| AdaptiveStateDoc with nested states | Multi-KC document parsing |
| Parse minimal JSON | Fixture loader with inline string |
| Shared fixture file | Loads bkt-test-cases.json (skips if file not found from Dart cwd) |

---

## Parameter Versioning & Migration

### Immutable Snapshots

Parameters are stored as immutable version documents at:

```
course_priors/{courseId}/versions/{parameterVersion}
```

A mutable parent document at `course_priors/{courseId}` points to `currentVersion`:

```
course_priors/{courseId}
├── currentVersion: "v1.0"
└── versions/
    ├── v1.0 → { pLearning0: 0.15, pTransition: 0.12, ... }
    └── v2.0 → { pLearning0: 0.20, pTransition: 0.15, ... }
```

### State Resolution

1. Existing state → pinned `parameterVersion` → load that specific version
2. No pinned version → resolves to `latest` version
3. No version documents → falls back to hardcoded defaults

### Migration Strategy (Phase 2)

Two options for post-launch parameter tuning:

**Option A — Pin-and-continue:** States keep their original pinned version. New states use the new version. No replay needed but older KCs have stale parameters.

**Option B — Replay logs:** Read `adaptive_logs` for affected KCs, replay raw attempt history under new parameters, write updated states. More accurate but requires careful ordering.

Option A is the Phase 1 default. Option B is deferred to Phase 2.

---

## Cost Model

Per-answer Firestore ops breakdown (unsubscribed — all reads/writes are document operations):

### Unsubscribed (each call incurs all reads)

| Step | Operation | Count |
|------|-----------|-------|
| Dedup check | Read attempt record | 1 read |
| Load question | Read `questions/{questionId}` | 1 read |
| Load answer key | Read `answerKeys/{questionId}` | 1 read |
| Load adaptive state | Read `adaptive_states/{uid}` | 1 read |
| Resolve parameters | Read version doc | 1 read |
| Write attempt record | Write `adaptive_attempts/{uid}_{attemptId}` | 1 write |
| Write adaptive state | Write `adaptive_states/{uid}` | 1 write |
| Write telemetry log | Write `adaptive_logs/{autoId}` | 1 write |
| **Total** | | **6 reads + 3 writes** |

### Cached (duplicate attemptId — returns cached, all reads satisfied)

| Step | Operation | Count |
|------|-----------|-------|
| Dedup check | Read attempt record | 1 read |
| Return cached | (no further reads/writes) | 0 |
| **Total** | | **1 read + 0 writes** |

### Monthly Estimate

| Metric | Value |
|--------|-------|
| Users | 500 |
| Answers/user/month | 50 |
| Monthly answer volume | 25,000 |
| First attempts (unsubscribed) | 22,500 (90%) |
| Duplicates (cached) | 2,500 (10%) |
| Reads/month | 22,500 × 6 + 2,500 × 1 = 137,500 |
| Writes/month | 22,500 × 3 = 67,500 |
| Cost factor | Read: ~$0.06/100K, Write: ~$0.18/100K |
| **Monthly cost** | **~$1.87** |

---

## Deployment

### Prerequisites

- Firebase project: `engineering-hub-7e5e1`
- Firebase CLI installed (`npm install -g firebase-tools`)
- Node.js 22 runtime

### Build

```bash
cd functions-adaptive
npm run build    # TypeScript compilation
```

### Deploy

```bash
firebase deploy --only functions:adaptive-engine
```

The second codebase is already configured in `firebase.json`:

```json
{
  "functions": [
    {
      "source": "functions-adaptive",
      "codebase": "adaptive-engine",
      "ignore": ["node_modules", ".git", "*.test.ts", "tests/", "fixtures/"],
      "runtime": "nodejs22"
    }
  ]
}
```

The existing `functions/` (Python 3.13, R2 infrastructure) and `functions-adaptive/` (TypeScript, Node 22) coexist as independent codebases in the same Firebase project.

### Environment Variables

None required. Parameters are read from Firestore at `course_priors/{courseId}/versions/`.

### Firebase Emulator (Local Testing)

```bash
cd functions-adaptive
npm run serve   # Starts emulator with --only functions
```

Requires a running Firestore emulator. Point the Flutter app to the emulator host.

---

## Key Design Decisions

### 1. BKT over Ebbinghaus/HMM (V2 → original V1)
The first version used a heuristic Ebbinghaus curve + HMM. It was rejected as "crude" and "not good at all." BKT was chosen because:
- Pedagogically validated — used in Cognitive Tutors and adaptive learning research
- P(L) has a clear interpretation as mastery probability
- P(T), P(S), P(G) are domain-expert-configurable per knowledge component
- Produces the same behavior as spaced repetition (massed practice → flat mastery, spaced reviews → S grows)

### 2. No Local BKT (V2.5 decision)
Dart cannot run in Cloud Functions. The client has no access to answer keys. Computing correctness locally would require shipping answer keys to the client, which breaks the assessment integrity model. All BKT computation happens server-side.

### 3. No Optimistic UI
Because the client cannot compute the result locally, showing a provisional state change would be misleading. The UI shows "Checking…" and locks submission until the server responds. Offline clients queue raw submissions but do not mutate adaptive state locally.

### 4. Massed-Practice Guard (V2.5 addition)
Without this, rapid-fire correct answers would inflate S indefinitely, scheduling next reviews years into the future. The guard ensures S only updates on qualified reviews spaced by at least `minimumSpacingDays`.

### 5. Immutable Parameter Versions
Pinning states to a parameter version at creation time enables post-launch parameter tuning without retroactively changing historical mastery estimates. Optionally, logs can be replayed under new parameters for recalibration.

### 6. Dedup via `uid_{attemptId}` Document ID
Using the compound key `adaptive_attempts/{uid}_{attemptId}` enables a simple existence check without requiring a composite index. The transaction returns the cached `SubmitAnswerResult` verbatim on duplicate.

### 7. `feedbackEligible` (not `feedbackShown`)
The server knows the policy exposes feedback for a given answer, but cannot confirm the learner engaged with it. The field name was chosen to reflect server-side knowledge only.

### 8. Per-Question P(G)
`itemGuessProb` on the question document overrides the default P(G) per KC. For MCQ, default is `1/numOptions`. For gap-fill/theory, a configured value is used. The server loads this at submission time.

### 9. No Session Validation, App Check, or IAM (V2.5 stripped)
Per directive, the initial build strips access validation layers beyond basic auth. Core dedup + state update runs without quiz-session contracts, App Check enforcement, or IAM-based write controls. These can be added in Phase 2.

### 10. Shared JSON Fixtures
Float values in `bkt-test-cases.json` were computed via a Python bridge and verified against TypeScript `Math.*` output to eliminate cross-platform floating-point discrepancies. Both TypeScript Jest tests and Dart standalone tests load the same file.

---

## File Manifest

```
functions-adaptive/
├── .gitignore
├── package.json             — Node 22, firebase-admin, firebase-functions, jest
├── tsconfig.json            — ESNext modules, NodeNext moduleResolution
├── jest.config.ts           — ts-jest preset
├── fixtures/
│   └── bkt-test-cases.json  — 10 shared cross-implementation test cases
├── src/
│   ├── adaptive/
│   │   ├── types.ts         — 12 interfaces (BKTParams, KcState, etc.)
│   │   ├── bkt.ts           — 6 pure BKT functions
│   │   ├── spaced-repetition.ts — 6 interval/readiness functions
│   │   ├── scheduler.ts     — 2 functions (scheduleNextReview, timeDeltaDaysSince)
│   │   ├── transaction.ts   — executeSubmitAnswer (full Firestore transaction)
│   │   └── index.ts         — barrel export
│   └── index.ts             — 3 callable function entry points
└── tests/
    ├── bkt.test.ts           — 22 tests
    ├── spaced-repetition.test.ts — 18 tests
    ├── transaction.test.ts   — 7 tests
    └── index.test.ts         — 1 test

lib/adaptive/
├── pubspec.yaml             — Standalone Dart test package
├── lib/
│   ├── adaptive_engine.dart — barrel export
│   └── src/
│       ├── adaptive_types.dart     — 5 Dart types with JSON serialization
│       ├── adaptive_service.dart   — AdaptiveService (wraps callable)
│       └── adaptive_fixtures.dart  — BktTestFixtures loader
└── test/
    └── adaptive_test_standalone.dart — 7 tests
```

---

*Version: 2.5 — June 2026*
