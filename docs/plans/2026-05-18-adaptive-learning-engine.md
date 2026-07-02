<!-- /autoplan restore point: /home/nasbombz/.gstack/projects/vens-hub/main-autoplan-restore-20260702-014623.md -->
# Adaptive Learning Engine Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Replace the current static-difficulty quiz system with a personalized adaptive engine that models each student's memory decay via Ebbinghaus+EWMA and tracks discrete memory/proficiency states via a 5-state Hidden Markov Model, driving optimal review scheduling and difficulty selection per subtopic.

**Architecture:** Two-layer adaptive engine. Layer 1: Ebbinghaus forgetting curve corrected by EWMA (continuous retention signal, O(1) per question). Layer 2: 5-state HMM unified for memory + proficiency tracking (discrete state tracker). A separate policy layer reads HMM state probabilities and selects the next question's difficulty and timing. All computation on-device in pure Dart. State persisted to Firestore per student per subtopic, with per-course aggregate priors for cold start and sparse data.

**Tech Stack:** Dart (pure math, no ML framework), Firestore (Cloud Firestore), existing BLoC pattern, existing Question/CourseInfo models.

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      QUIZ SESSION                           │
│  Student answers question → correct/incorrect + latency     │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: Ebbinghaus + EWMA                                │
│  • R(t) = e^(-t/S)  — predicted retention at time t        │
│  • S_new = α·S_obs + (1-α)·S_old  — EWMA update            │
│  • Output: continuous retention estimate for this subtopic  │
│  • O(1) per answer. Pure Dart math.                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2: 5-State HMM (Unified Memory + Proficiency)       │
│                                                             │
│  States:                                                    │
│    MASTERED  — Strong memory, mastering proficiency        │
│    SECURE    — Strong memory, competent proficiency         │
│    LEARNING  — Weak memory, building proficiency            │
│    FRAGILE   — Fading memory, building proficiency          │
│    LOST      — Forgotten, struggling                        │
│                                                             │
│  Transitions: time-driven decay + review-driven reset       │
│  Observations: quiz results (correct/wrong, difficulty)     │
│  Inference: forward algorithm per subtopic per session      │
│  O(5² × T) per subtopic. Trivial on device.                │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  POLICY LAYER: Question Selection                          │
│  • Reads HMM state vector for all subtopics                 │
│  • Priority: lowest P(Mastered/Secure) = most urgent        │
│  • Selects difficulty tier matching current state           │
│  • Schedules next review interval from S parameter          │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundation

### 2.1 Ebbinghaus Forgetting Curve

The base retention model:

```
R(t) = e^(-t/S)
```

Where:
- `t` = time elapsed since last review (days)
- `S` = stability parameter (individualized)
- `R(t)` = predicted probability of correct recall

### 2.2 EWMA Update Rule

After a quiz result at time `t` with score `q ∈ [0, 1]`:

```
1. Compute observed stability:
   S_obs = -t / ln(max(q, 0.01))
   (Clamp q to avoid ln(0))

2. Update via EWMA:
   S_new = α · S_obs + (1-α) · S_old

3. α = 0.3 (default). Self-adjusts:
   - After N reviews: α_effective = 0.3 / (1 + 0.1·N)
   - Converges stability as data accumulates
```

**Seeding S₀:** Global default = 1.0 day. The EWMA corrects within 3-5 quiz sessions regardless of starting point. No calibration probe or cohort bucket needed.

### 2.3 5-State Hidden Markov Model

**State definitions:**

| # | State | Memory | Proficiency | P(correct|Easy) | P(correct|Medium) | P(correct|Hard) |
|---|-------|--------|-------------|-------------------|---------------------|------------------|
| 0 | MASTERED | Strong | Mastering | 0.98 | 0.92 | 0.82 |
| 1 | SECURE | Strong | Competent | 0.94 | 0.84 | 0.68 |
| 2 | LEARNING | Weak | Building | 0.78 | 0.58 | 0.35 |
| 3 | FRAGILE | Fading | Building | 0.55 | 0.32 | 0.15 |
| 4 | LOST | Forgotten | Struggling | 0.28 | 0.12 | 0.05 |

These emission probabilities are **starting defaults**. They personalize per student as the transition matrix trains.

**Transition matrix** `A[5×5]`:

Two transition modes, composed multiplicatively:

#### A. Time-Driven Decay (Δt days since last review)

```
P(decay from state i to j) = f(Δt, i, j)

Decay is a Poisson process: the longer the gap, the more likely the slide.

Base decay rates λ per state:
  MASTERED:  λ = 1/14   (slides after ~14 days unattended)
  SECURE:    λ = 1/7    (slides after ~7 days)
  LEARNING:  λ = 1/3    (slides after ~3 days)
  FRAGILE:   λ = 1/1.5  (slides after ~1.5 days)
  LOST:      λ = 1/∞    (already at floor, can't decay further)

For Δt days, probability of remaining in state i:
  P(stay | i) = e^(-λ_i · Δt)

Slides go one state at a time. Probability cascades down multiplicatively.
```

#### B. Review-Driven Reset

```
After a correct answer:
  Any state → MASTERED with probability: q · P(observation was correct)
  Any state → next state up with probability: (1-q) · recovery_factor

After an incorrect answer:
  Any state → next state down with probability: (1-q) · penalty_factor

q = score on this question (0 or 1 for MCQ, 0-1 for partial credit)
```

**Combined transition for one review event** (Δt days + quiz result):

```
A_combined = A_decay(Δt) × A_review(q, difficulty)
```

**Inference (Forward Algorithm):**

```
Input: state_prior[5], observations[(Δt₁, q₁, d₁), ..., (Δt_T, q_T, d_T)]
Output: state_posterior[5]

For each observation (Δt, q, d):
  1. Compute A_decay from Δt
  2. Predict: state_pred[i] = Σ_j state_prior[j] · A_decay[j][i]
  3. Compute emission: P(q | state i, difficulty d) from emission matrix
  4. Update: state_posterior[i] ∝ state_pred[i] · P(q | state i, d)
  5. Compute A_review from q
  6. Apply A_review to state_posterior
  5. state_prior = state_posterior

Return state_posterior
```

**Computational cost:** 5² × T operations per subtopic. For T ≤ 20 (a typical session), that's 500 fp operations. Negligible.

### 2.4 Hierarchical State Blending (Sparse Data Fallback)

When a subtopic has < 5 quiz events, blend with the course-level prior:

```
state_blended[i] = w · state_subtopic[i] + (1-w) · state_course[i]

w = min(1.0, total_reviews_subtopic / 5.0)
```

At 0 reviews: pure course prior (prevents wild swings).
At 5+ reviews: pure subtopic signal (full personalization).

---

## 3. Data Model & Firestore Schema

### 3.1 Per-Student Per-Subtopic State (`adaptive_states` collection)

```
/adaptive_states/{studentId}_{subtopicId}
```

```dart
{
  "studentId": "abc123",
  "subtopicId": "course_code:topic_name",  // e.g., "EEE301:Kirchhoff's Laws"
  "courseId": "EEE301",
  "sParameter": 3.42,           // Ebbinghaus stability (days)
  "stateMastered": 0.15,        // P(MASTERED)
  "stateSecure": 0.42,          // P(SECURE)
  "stateLearning": 0.28,        // P(LEARNING)
  "stateFragile": 0.10,         // P(FRAGILE)
  "stateLost": 0.05,            // P(LOST)
  "totalReviews": 12,           // review count for shrinkage weight
  "lastReviewAt": Timestamp,    // when last quiz was taken on this subtopic
  "ewmaAlpha": 0.3,             // current EWMA α (may adapt)
  "transitionMatrix": [         // personalized 5×5 transition matrix (flattened)
    0.85, 0.10, 0.03, 0.01, 0.01,
    0.05, 0.80, 0.10, 0.03, 0.02,
    // ... 25 values
  ],
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
}
```

### 3.2 Per-Course Aggregate Priors (`adaptive_course_priors` collection)

```
/adaptive_course_priors/{courseId}
```

```dart
{
  "courseId": "EEE301",
  "stateMastered": 0.10,        // aggregate prior across all students
  "stateSecure": 0.25,
  "stateLearning": 0.35,
  "stateFragile": 0.20,
  "stateLost": 0.10,
  "globalSParameter": 1.0,      // default S for new students
  "transitionMatrix": [...],    // global default transition matrix
  "emissionMatrix": [...],      // global default emission matrix (3×5)
  "updatedAt": Timestamp,
}
```

### 3.3 Quiz Result Log (`quiz_results` subcollection)

```
/adaptive_states/{studentId}_{subtopicId}/quiz_results/{autoId}
```

```dart
{
  "questionId": "q_789",
  "difficulty": "medium",       // easy/medium/hard
  "correct": true,
  "score01": 1.0,               // normalized score (1.0 for MCQ correct, 0-1 for partial)
  "timeDeltaDays": 2.5,         // days since last review of this subtopic
  "reviewedAt": Timestamp,
  "sParameterBefore": 3.1,      // snapshot for debugging
  "sParameterAfter": 3.42,
  "stateVectorBefore": [0.12, 0.38, 0.30, 0.12, 0.08],
  "stateVectorAfter": [0.15, 0.42, 0.28, 0.10, 0.05],
}
```

### 3.4 Local Cache (Optional, for Offline)

Use `shared_preferences` or `hive` to cache the latest state vector for recently-accessed subtopics. Firestore remains source of truth. On reconnect, push local quiz results and recalculate.

---

## 4. Integration Points with Existing Code

### 4.1 Models to Create

| File | Purpose |
|------|---------|
| `lib/data/models/adaptive_state.dart` | Dart model for per-subtopic adaptive state |
| `lib/data/models/quiz_result_log.dart` | Dart model for quiz result log entry |
| `lib/data/models/course_prior.dart` | Dart model for course-level aggregate priors |

### 4.2 Engine Classes to Create

| File | Purpose |
|------|---------|
| `lib/core/adaptive/ebbinghaus_ewma.dart` | Pure functions: predict retention, update S, EWMA |
| `lib/core/adaptive/hmm_engine.dart` | 5-state HMM: transition matrices, forward inference |
| `lib/core/adaptive/policy_engine.dart` | Reads states, selects next question difficulty and timing |
| `lib/core/adaptive/adaptive_engine.dart` | Orchestrator: wires EWMA + HMM + Policy together |

### 4.3 Repository to Create

| File | Purpose |
|------|---------|
| `lib/domain/adaptive/repositories/adaptive_repository.dart` | Abstract interface |
| `lib/data/adaptive/repositories/adaptive_repository_impl.dart` | Firestore implementation |

### 4.4 BLoC to Modify/Create

**Modify: `lib/presentation/blocs/quiz/quiz_bloc.dart`**
- After `SubmitAnswer`: call `AdaptiveEngine.processAnswer()` with (studentId, subtopicId, questionId, difficulty, correct, timeDelta)
- After quiz completion: call `AdaptiveEngine.completeSession()`

**Create: `lib/presentation/blocs/adaptive/adaptive_bloc.dart`**
- Manages loading/saving adaptive state
- Emits recommended next-subtopic and difficulty
- Used by the study/quiz entry screens

### 4.5 Existing Files Touched

| File | Change |
|------|--------|
| `lib/data/models/question_model.dart` | Add `difficultyScore` field (numeric 1-10, if not already present in the `difficulty` string) |
| `lib/core/constants/constants.dart` | Add `enum MemoryState { mastered, secure, learning, fragile, lost }` |
| `lib/presentation/blocs/quiz/quiz_state.dart` | Add `adaptiveStateBefore`, `adaptiveStateAfter` fields |
| `lib/presentation/blocs/quiz/quiz_event.dart` | Add `AdaptiveQuizCompleted` event |
| `lib/core/di/injection_container.dart` | Register new adaptive services and repositories |

---

## 5. Core Algorithm Pseudocode

### 5.1 Ebbinghaus + EWMA Engine

```dart
class EbbinghausEWMA {
  /// Predict retention probability at time t given stability S
  static double predictRetention(double tDays, double sParam) {
    if (tDays <= 0) return 1.0;
    return exp(-tDays / sParam);
  }

  /// Back-compute observed stability from quiz result
  static double observedStability(double tDays, double score) {
    final clampedScore = max(score, 0.01);
    return -tDays / log(clampedScore);
  }

  /// EWMA update: blend observed stability into current estimate
  static double updateStability({
    required double sOld,
    required double tDays,
    required double score,
    double alpha = 0.3,
    int totalReviews = 0,
  }) {
    final sObs = observedStability(tDays, score);
    // Adaptive alpha: decrease as more data accumulates
    final effectiveAlpha = alpha / (1.0 + 0.1 * totalReviews);
    return effectiveAlpha * sObs + (1 - effectiveAlpha) * sOld;
  }

  /// Recommend next review interval based on target retention
  static double nextInterval({
    required double sParam,
    double targetRetention = 0.85,
  }) {
    // Solve R(t) = target for t
    return -sParam * log(targetRetention);
  }
}
```

### 5.2 HMM Engine

```dart
class HMMEngine {
  // 5-state definitions
  static const int MASTERED = 0;
  static const int SECURE = 1;
  static const int LEARNING = 2;
  static const int FRAGILE = 3;
  static const int LOST = 4;

  /// Base decay rates (λ) per state
  static const List<double> decayRates = [1/14, 1/7, 1/3, 1/1.5, double.infinity];

  /// Default emission matrix: P(correct | state, difficulty)
  /// Rows: difficulty (easy=0, medium=1, hard=2)
  /// Cols: state (MASTERED...LOST)
  static const List<List<double>> defaultEmissions = [
    [0.98, 0.94, 0.78, 0.55, 0.28],  // easy
    [0.92, 0.84, 0.58, 0.32, 0.12],  // medium
    [0.82, 0.68, 0.35, 0.15, 0.05],  // hard
  ];

  /// Build time-decay transition matrix for Δt days
  static List<List<double>> decayMatrix(double deltaTDays) {
    final A = List.generate(5, (_) => List.filled(5, 0.0));
    for (int i = 0; i < 5; i++) {
      final stayProb = exp(-decayRates[i] * max(deltaTDays, 0));
      A[i][i] = stayProb;
      if (i < 4) {
        A[i][i + 1] = 1.0 - stayProb; // slide one state down
      } else {
        A[i][i] = 1.0; // LOST stays LOST
      }
    }
    return A;
  }

  /// Forward algorithm: update state vector given observation
  static List<double> forward({
    required List<double> prior,        // [5] state probabilities
    required double deltaTDays,         // days since last review
    required double score,              // 0-1 quiz score
    required int difficulty,            // 0=easy, 1=medium, 2=hard
  }) {
    // Step 1: Apply time decay
    final A_decay = decayMatrix(deltaTDays);
    final predicted = List<double>.generate(5, (i) {
      double sum = 0;
      for (int j = 0; j < 5; j++) {
        sum += prior[j] * A_decay[j][i];
      }
      return sum;
    });

    // Step 2: Bayes update with emission probabilities
    final emission = List<double>.generate(5, (i) {
      final pCorrect = defaultEmissions[difficulty][i];
      return score > 0.5 ? pCorrect : (1.0 - pCorrect);
    });

    double total = 0;
    final posterior = List<double>.generate(5, (i) {
      final val = predicted[i] * emission[i];
      total += val;
      return val;
    });

    // Normalize
    for (int i = 0; i < 5; i++) {
      posterior[i] /= total;
    }

    // Step 3: Apply review reset (correct → boost, incorrect → penalize)
    if (score > 0.5) {
      _applyBoost(posterior);
    } else {
      _applyPenalty(posterior);
    }

    return posterior;
  }

  static void _applyBoost(List<double> state) {
    // Shift probability mass upward
    // Correct answer: all states shift toward MASTERED
    final boost = 0.3; // how much mass shifts up per correct
    for (int i = 1; i < 5; i++) {
      final transfer = state[i] * boost;
      state[i] -= transfer;
      state[i - 1] += transfer;
    }
  }

  static void _applyPenalty(List<double> state) {
    // Shift probability mass downward
    // Wrong answer: all states shift toward LOST
    final penalty = 0.3;
    for (int i = 3; i >= 0; i--) {
      final transfer = state[i] * penalty;
      state[i] -= transfer;
      state[i + 1] += transfer;
    }
  }
}
```

### 5.3 Policy Engine

```dart
class PolicyEngine {
  /// Select which subtopic to review next
  /// Returns subtopic ID with lowest "strong memory" probability
  static String selectNextSubtopic({
    required Map<String, List<double>> allSubtopicStates,
    required Map<String, double> allSubtopicS,
  }) {
    // Score each subtopic: urgency = P(LOST) + P(FRAGILE) * 0.7
    // Lower "strong" states need review more urgently
    String? worst;
    double worstScore = double.infinity;

    allSubtopicStates.forEach((subtopicId, stateVec) {
      final strongProb = stateVec[HMMEngine.MASTERED] + stateVec[HMMEngine.SECURE];
      final s = allSubtopicS[subtopicId] ?? 1.0;
      final daysSinceReview = /* from Firestore */ 0.0;
      final predictedRetention = EbbinghausEWMA.predictRetention(daysSinceReview, s);
      final urgency = strongProb * predictedRetention; // combined signal

      if (urgency < worstScore) {
        worstScore = urgency;
        worst = subtopicId;
      }
    });

    return worst!;
  }

  /// Select difficulty for next question based on current state
  static int selectDifficulty(List<double> stateVec) {
    final strongProb = stateVec[HMMEngine.MASTERED] + stateVec[HMMEngine.SECURE];
    final fadingProb = stateVec[HMMEngine.FRAGILE];
    final lostProb = stateVec[HMMEngine.LOST];

    if (lostProb > 0.4) return 0;        // easy
    if (fadingProb > 0.3) return 0;      // easy
    if (strongProb > 0.6) return 2;      // hard
    return 1;                             // medium
  }
}
```

---

## 6. Implementation Tasks

### Phase 1: Data Models & Constants

**Task 1.1: Add MemoryState enum to constants**
- File: `lib/core/constants/constants.dart`
- Add: `enum MemoryState { mastered, secure, learning, fragile, lost }`
- Add: extensions for index mapping, display names

**Task 1.2: Create AdaptiveState model**
- File: `lib/data/models/adaptive_state.dart`
- Fields: studentId, subtopicId, courseId, sParameter, stateVector[5], totalReviews, lastReviewAt, ewmaAlpha, transitionMatrix[25]
- Methods: fromJson, toJson, fromFirestore, copyWith, default factory

**Task 1.3: Create QuizResultLog model**
- File: `lib/data/models/quiz_result_log.dart`
- Fields: questionId, difficulty, correct, score01, timeDeltaDays, reviewedAt, sBefore, sAfter, stateBefore[5], stateAfter[5]
- Methods: fromJson, toJson, fromFirestore

**Task 1.4: Create CoursePrior model**
- File: `lib/data/models/course_prior.dart`
- Fields: courseId, stateVector[5], globalSParameter, transitionMatrix[25], emissionMatrix[15], updatedAt
- Methods: fromJson, toJson, fromFirestore, factory defaults

### Phase 2: Core Engines (Pure Dart, No Firebase)

**Task 2.1: Implement EbbinghausEWMA class**
- File: `lib/core/adaptive/ebbinghaus_ewma.dart`
- Static methods: predictRetention, observedStability, updateStability, nextInterval
- Write unit tests verifying:
  - Retention drops as t increases
  - S increases after correct answers, decreases after wrong
  - EWMA alpha self-adjusts with review count

**Task 2.2: Implement HMMEngine class**
- File: `lib/core/adaptive/hmm_engine.dart`
- Constants: state definitions, decay rates, default emission matrix
- Static methods: decayMatrix, forward
- Write unit tests verifying:
  - Without review, probability shifts toward LOST over time
  - Correct answer shifts toward MASTERED
  - Wrong answer shifts toward LOST
  - State vector always sums to 1.0

**Task 2.3: Implement PolicyEngine class**
- File: `lib/core/adaptive/policy_engine.dart`
- Static methods: selectNextSubtopic, selectDifficulty
- Write unit tests verifying:
  - Highest P(LOST) subtopic selected first
  - Low strongProb yields easy difficulty
  - High strongProb yields hard difficulty

**Task 2.4: Implement AdaptiveEngine orchestrator**
- File: `lib/core/adaptive/adaptive_engine.dart`
- Orchestrates EWMA + HMM + Policy in one `processAnswer()` call
- Manages hierarchical blending (subtopic vs course-level)
- Handles state initialization for new student/subtopic
- Write integration tests

### Phase 3: Data Layer (Firestore Integration)

**Task 3.1: Create AdaptiveRepository interface**
- File: `lib/domain/adaptive/repositories/adaptive_repository.dart`
- Methods: getState(studentId, subtopicId), saveState(AdaptiveState), getCoursePrior(courseId), logResult(QuizResultLog), getAllStatesForStudent(studentId)

**Task 3.2: Implement AdaptiveRepositoryImpl**
- File: `lib/data/adaptive/repositories/adaptive_repository_impl.dart`
- Firestore read/write for `adaptive_states`, `adaptive_course_priors`, `quiz_results`
- Hierarchical fallback: load course prior when subtopic state absent
- Write unit tests with Firestore emulator

**Task 3.3: Wire into DI container**
- File: `lib/core/di/injection_container.dart`
- Register AdaptiveRepository, AdaptiveEngine as lazy singletons

### Phase 4: BLoC Integration

**Task 4.1: Create AdaptiveBloc**
- File: `lib/presentation/blocs/adaptive/adaptive_bloc.dart`
- Events: LoadAdaptiveState, ProcessAnswer, GetNextRecommendation
- States: AdaptiveLoading, AdaptiveLoaded (with state vectors, recommended subtopic+ difficulty)
- On ProcessAnswer: calls AdaptiveEngine, saves to Firestore

**Task 4.2: Modify QuizBloc for adaptive tracking**
- File: `lib/presentation/blocs/quiz/quiz_bloc.dart`
- After SubmitAnswer: capture question difficulty, correctness, time since last review
- After quiz completes: emit all results to AdaptiveEngine
- Add `startedAt` tracking per-subtopic (already partially in QuizState)

**Task 4.3: Update QuizState for adaptive data**
- File: `lib/presentation/blocs/quiz/quiz_state.dart`
- Add: adaptiveStateBefore, adaptiveStateAfter, subtopicId

### Phase 5: Policy-Driven Question Selection

**Task 5.1: Modify quiz customization flow**
- File: `lib/presentation/screens/quiz/quiz_customization_page.dart`
- Instead of user picking difficulty, show recommendation from PolicyEngine
- Let user override if desired (retain manual mode)

**Task 5.2: Implement study suggestion screen**
- File: `lib/presentation/blocs/study/study_bloc.dart`
- On load: query AdaptiveEngine for weakest subtopics
- Display "Recommended Review: Topic X (Difficulty Y)" cards

### Phase 6: Course-Level Prior Seeding

**Task 6.1: Create initial course priors in Firestore**
- Write a one-off admin script or manual console upload
- For each course, create `/adaptive_course_priors/{courseId}` with default stateVector and transition/emission matrices
- Defaults: uniform state distribution [0.20, 0.20, 0.20, 0.20, 0.20], S=1.0

**Task 6.2: Periodic prior recalculation (optional, can be deferred)**
- Cloud Function or cron: every N days, aggregate all student states per course into updated course prior
- This improves the hierarchical prior for new students

---

## 7. Testing Strategy

### Unit Tests
- `EbbinghausEWMA`: predictRetention boundary cases (t=0, t=∞), EWMA convergence with repeated correct answers, negative S protection
- `HMMEngine`: decay matrix properties (rows sum to 1, diagonal ≤ 1), forward algorithm sum-to-1 invariant, state ordering (correct→up, wrong→down)
- `PolicyEngine`: edge cases (all zeros, all ones, uniform distribution), difficulty boundaries

### Widget/Integration Tests (Optional)
- Verify quiz flow captures and persists adaptive state
- Verify study suggestion screen loads and sorts correctly

### Performance Benchmarks
- `processAnswer()` must complete in < 5ms on a mid-range device (Dart's `Stopwatch`)
- Full-session update (20 questions × 10 subtopics) in < 50ms

---

## 8. Edge Cases & Error Handling

| Scenario | Handling |
|----------|----------|
| New student (no adaptive state) | Load course prior, initialize with uniform state, S₀=1.0 |
| New subtopic (no data) | Blend 100% from course prior, transition to subtopic data as reviews accumulate |
| Network offline | Cache latest state locally. Queue quiz results. Replay on reconnect. |
| S parameter goes negative | Clamp to 0.01 minimum |
| State vector doesn't sum to 1.0 | Renormalize after every forward pass |
| Very long gap (>365 days) | Cap Δt at 365 days to prevent floating-point underflow |
| Student spams same subtopic | Detect rapid-fire reviews (Δt < 1 hour) — weight these at 0.5× in EWMA to prevent gaming |
| Difficulty field missing from question | Default to medium difficulty for emission lookup |
| Firestore write fails | Retry with exponential backoff. Keep in-memory state valid. |

---

## 9. Migration Path

1. **Deploy models and engines first** (Phases 1-2). They compile but don't affect UX yet.
2. **Deploy Firestore schema and repositories** (Phase 3). Backend begins accepting state.
3. **Turn on adaptive tracking in QuizBloc** (Phase 4). Every quiz starts feeding the engine. No UX change yet.
4. **Seed course priors** (Phase 6). New students get reasonable defaults.
5. **Enable policy-driven difficulty** (Phase 5). The user-visible change: difficulty auto-selected, review suggestions appear.
6. **Monitor for 2 weeks.** Compare engagement metrics (sessions/week, quiz completion rate) against baseline.
7. **Iterate on α, decay rates, emission probabilities** based on observed data.

---

## 10. Key Design Decisions and Rationale

| Decision | Rationale |
|----------|-----------|
| All on-device computation | No server cost, works offline, < 5ms latency. Math is trivial. |
| EWMA over simple average | Exponential weighting matches the exponential nature of forgetting. Recency-weighted observations. |
| 5 states over 3 or 7 | 3 states too coarse (can't distinguish "fading but still there" from "gone"). 7 states adds complexity with diminishing returns. 5 is the sweet spot. |
| Unified HMM over two separate ones | Memory state and proficiency state are correlated — a student who remembers well is probably more proficient. Separate HMMs can't capture this interaction. 5 combined states cover the space efficiently. |
| Hierarchical blending over pure subtopic | Pure subtopic gives zero data for new topics. But pure course-level is too coarse for personalization. Shrinkage toward the course prior gracefully handles sparse data. |
| Global S₀ = 1.0 without calibration | Calibration probes add UX friction (24h delay). EWMA converges fast enough that the seed barely matters after 3-5 sessions. |
| Firestore over local-only | Enables cross-device sync, teacher dashboards later, aggregate analytics. Local cache handles offline. |
| Policy layer decoupled from HMM | The HMM estimates state. The policy chooses actions. Separating them means you can experiment with bandit algorithms, teacher-specified schedules, or AI-driven selection without retouching the model. |

---

*Plan ready for implementation review.*
