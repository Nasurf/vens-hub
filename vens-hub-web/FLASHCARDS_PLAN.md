# Flashcards Feature Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task after the user explicitly approves implementation.

**Goal:** Replace the current study-material upload area in `vens-hub-web` with a flashcards review feature that stores the specific quiz questions a student answered, shows their answer and the correct answer, and uses an Ebbinghaus-style spaced review schedule to reinforce weak items without abandoning strong ones.

**Architecture:** Keep the existing quiz and AI assistant flows, but add a per-question review layer on top of quiz completion. Quiz modes will write detailed question snapshots into browser storage, the new Flashcards page at `/app/study` will derive a due review feed from those records, and static plus AI explanations will reuse the current `askAssistant` wiring. Backend adaptive mastery stays in place for topic-level progress, while flashcards store question-level data locally for the web app MVP.

**Tech Stack:** React 19, TypeScript, Vite, React Router, localStorage through existing helpers, existing Worker API question endpoints, existing `/assistant` AI endpoint, existing `LatexText` rendering, existing CSS system in `src/index.css`.

---

## Current Repo Context

Relevant files inspected:

- `vens-hub-web/src/App.tsx`
  - `Question` includes `correct_answer_text`, `explanation`, `solution_steps`, and `rag_sources` at lines 112-127.
  - `StudyUpload`, `UPLOADS_KEY`, upload helpers, and current Study page are the old materials upload feature at lines 153-164, 198-201, 541-633, and 2680-2764.
  - `askAssistant` already posts to `ASSISTANT_API_BASE` and `/assistant` at lines 635-651.
  - `AIAssistantPanel` is the floating assistant UI at lines 1602-1691.
  - `MultipleChoiceQuizMode` tracks selected answers and explanations at lines 2203-2383.
  - `TheoryQuizMode` and `GapFillQuizMode` store only aggregate quiz attempts at lines 2385-2526.
  - The `/app/study` route points to `StudyPage` at lines 3568-3570.
- `vens-hub-web/src/adaptive.ts`
  - Existing adaptive backend stores topic-level mastery and attempts, not enough per-question review content for flashcards.
  - `submitBatchResults` is still useful and should remain for topic mastery.
- `vens-hub-web/src/index.css`
  - Existing upload styles use `.study-grid`, `.upload-drop`, `.file-list`, and upload badges.
  - Existing quiz/explanation and assistant styles can be reused and extended.
- `vens-hub-web/scripts/smoke.cjs`
  - Current smoke test still expects file upload behavior, so it must be updated when the feature is implemented.
- `vens-hub-web/env.example`
  - `VITE_UPLOAD_API_BASE_URL` exists only for the upload feature. It can be deprecated if no other upload paths remain.

Important existing behavior to preserve:

- Firebase auth gating through `RequireAuth`.
- Dashboard and profile aggregate metrics from `ATTEMPTS_KEY`.
- Topic-level adaptive sync through `submitBatchResults` for multiple choice quizzes.
- Static explanation display in MCQ result UI.
- The floating AI assistant and its existing backend wiring.

---

## Product Requirements Interpreted

1. Replace the old material upload page with flashcards.
2. Store the exact questions a student answered, not just aggregate quiz scores.
3. For each stored question, keep:
   - the question text,
   - course and topic,
   - question type,
   - answer options where available,
   - the answer the student gave,
   - the correct answer,
   - whether the student was correct,
   - explanation and solution steps if available,
   - enough review state to schedule the next card.
4. Use the Ebbinghaus forgetting curve principle:
   - incorrect and weak cards come back sooner,
   - correct and strong cards still return later so the student does not forget them,
   - the page should make it clear what is due now and why.
5. Flashcard UI should feel like a TikTok-style vertical feed:
   - one card per screen,
   - scroll snap to the next card,
   - visible scroll indicator or hint,
   - review actions before moving on.
6. Every card must show the correct answer.
7. Every card must offer a manual explanation toggle.
8. Every card, correct or incorrect, must offer AI explanation using the same assistant backend wiring as the floating AI assistant.
9. This is for `vens-hub-web`, not the mobile app.

---

## Proposed Data Model

Add a new storage key near the existing keys in `App.tsx`:

```ts
const FLASHCARD_ATTEMPTS_KEY = 'vens-hub-web-flashcard-attempts'
const FLASHCARD_STATES_KEY = 'vens-hub-web-flashcard-states'
```

Create reusable types, ideally in `vens-hub-web/src/flashcards.ts`:

```ts
export type FlashcardQuestionMode = 'multiple-choice' | 'theory' | 'gap-fill'

export type FlashcardAttempt = {
  id: string
  questionKey: string
  questionId: string
  courseCode: string
  courseTitle: string
  topicName: string
  mode: FlashcardQuestionMode
  questionText: string
  options: string[]
  selectedAnswerText: string
  selectedAnswerIndex?: number
  correctAnswerText: string
  correctAnswerIndex?: number
  isCorrect: boolean
  score?: number
  explanation?: string
  solutionSteps: string[]
  ragSources?: string
  answeredAt: string
}

export type FlashcardReviewState = {
  questionKey: string
  firstSeenAt: string
  lastAnsweredAt: string
  lastReviewedAt?: string
  nextReviewAt: string
  stabilityDays: number
  easeFactor: number
  repetitions: number
  lapses: number
  lastResult: 'correct' | 'incorrect'
  lastQuality?: 'again' | 'hard' | 'good' | 'easy'
}

export type FlashcardCard = {
  latestAttempt: FlashcardAttempt
  state: FlashcardReviewState
  retention: number
  dueScore: number
  isDue: boolean
}
```

`questionKey` should be deterministic:

```ts
`${courseCode}:${mode}:${question.id}`
```

Fallback if an API question has no stable id:

```ts
`${courseCode}:${mode}:${normalizeText(question.question).slice(0, 80)}`
```

Rationale:

- Store attempts as history so future analytics can show improvement.
- Store state separately so the scheduler can update without losing the original attempt details.
- Keep full question snapshots because `adaptive.ts` only has question ids and selected answer indexes, not enough content to render review cards independently.

---

## Ebbinghaus Scheduling Rules

Use a simple, transparent forgetting curve model:

```ts
retention = Math.exp(-elapsedDays / stabilityDays)
```

Initial state after a quiz answer:

- Correct answer:
  - `stabilityDays = 1`
  - `easeFactor = 2.3`
  - `repetitions = previous.repetitions + 1`
  - `nextReviewAt = answeredAt + 1 day` for first correct answer, then grow by ease.
- Incorrect answer:
  - `stabilityDays = 0.25`
  - `easeFactor = max(1.3, previous.easeFactor - 0.2)`
  - `lapses = previous.lapses + 1`
  - `nextReviewAt = answeredAt + 10 minutes` or immediate if same-session review is desired.

When a student reviews a card, show rating actions:

- `Again`: did not remember, due in 10 minutes, reduce stability sharply.
- `Hard`: remembered with effort, due soon, slight ease penalty.
- `Good`: remembered well, schedule normal interval.
- `Easy`: remembered easily, longer interval, slight ease boost.

Sorting the feed:

1. Overdue cards first.
2. Cards with low retention estimate next.
3. Cards with more lapses ahead of cards with fewer lapses.
4. Strong cards still appear when their due date arrives, just less often.

This satisfies the requirement that weak items get reinforced while strong items are still protected from being forgotten.

---

## Step-by-Step Implementation Plan

### Task 1: Add flashcard scheduler and storage helpers

**Objective:** Create pure functions for recording quiz answers and scheduling reviews.

**Files:**

- Create: `vens-hub-web/src/flashcards.ts`
- Modify: `vens-hub-web/src/App.tsx`

**Steps:**

1. Add the flashcard types listed above in `src/flashcards.ts`.
2. Add helper functions:
   - `makeQuestionKey(courseCode, mode, question)`
   - `buildFlashcardAttempt(args)`
   - `upsertReviewStateForQuizAnswer(state, attempt)`
   - `applyReviewRating(state, rating, reviewedAt)`
   - `estimateRetention(state, now)`
   - `buildReviewDeck(attempts, states, now)`
3. Use only pure functions in this file so the scheduler can be unit-tested later without React.
4. Import only the helper functions needed by `App.tsx`.

**Acceptance checks:**

- The file compiles under TypeScript.
- No browser APIs are used inside pure scheduler functions except values passed in.
- The sorting function returns weak or overdue cards first.

---

### Task 2: Add localStorage integration for per-question flashcards

**Objective:** Save question-level flashcard attempts alongside existing aggregate quiz attempts.

**Files:**

- Modify: `vens-hub-web/src/App.tsx`
- Create or modify: `vens-hub-web/src/flashcards.ts`

**Steps:**

1. Add `FLASHCARD_ATTEMPTS_KEY` and `FLASHCARD_STATES_KEY` near existing storage keys in `App.tsx`.
2. Add helper functions in `App.tsx` or `flashcards.ts`:
   - `readFlashcardAttempts()`
   - `writeFlashcardAttempts(attempts)`
   - `readFlashcardStates()`
   - `writeFlashcardStates(states)`
   - `recordFlashcardAttempt(attempt)`
   - `updateFlashcardReview(questionKey, rating)`
3. Use the existing `readJson`, `writeJson`, and `vens-hub-storage` event pattern so the Dashboard and Flashcards page stay reactive.
4. Do not attempt to backfill from `ATTEMPTS_KEY`, because aggregate attempts do not contain enough question content.

**Acceptance checks:**

- Answering a question creates one `FlashcardAttempt` record with a full question snapshot.
- Existing `saveQuizAttempt` aggregate behavior remains unchanged.
- Existing dashboard and profile metrics still use `ATTEMPTS_KEY` as before.

---

### Task 3: Record multiple-choice quiz questions in flashcard storage

**Objective:** Capture MCQ question, selected answer, correct answer, correctness, and explanation data when the student checks an answer.

**Files:**

- Modify: `vens-hub-web/src/App.tsx:2203-2383`

**Steps:**

1. Expand the `answers` state in `MultipleChoiceQuizMode` to include `questionKey` or full question metadata, not only selected and correct indexes.
2. In `submitAnswer`, build a `FlashcardAttempt` from `current`, `selected`, `answerIndex(current)`, `questionOptions(current)`, and `courseTitle`.
3. Call `recordFlashcardAttempt` exactly once per checked question.
4. Keep `answers` behavior compatible with score, topic breakdown, and `submitBatchResults`.
5. Avoid recording duplicate cards if the user clicks rapidly or if React rerenders.

**Acceptance checks:**

- After one MCQ answer, localStorage contains the exact question text, selected answer text, correct answer text, correctness, explanation, and solution steps.
- The existing MCQ result screen still works.
- Adaptive topic sync still fires after quiz completion.

---

### Task 4: Record theory and gap-fill quiz questions in flashcard storage

**Objective:** Make the flashcard feature work for all quiz modes currently present in the app.

**Files:**

- Modify: `vens-hub-web/src/App.tsx:2385-2526`

**Steps:**

1. In `TheoryQuizMode.submitTheoryAnswer`, create a flashcard attempt after `scoreTheoryAnswer` returns.
2. Store the student's typed answer as `selectedAnswerText`.
3. Store the expected answer as `correctAnswerText`.
4. In `GapFillQuizMode.submitGapAnswer`, create a flashcard attempt after correctness is computed.
5. Store the chosen gap option as `selectedAnswerText` and `gap.correct` as `correctAnswerText`.
6. Keep existing aggregate `saveQuizAttempt` behavior unchanged.

**Acceptance checks:**

- Theory attempts generate review cards with typed answer and expected answer.
- Gap-fill attempts generate review cards with selected answer and correct answer.
- Existing completion screens still work.

---

### Task 5: Replace `StudyPage` with the Flashcards page

**Objective:** Remove the upload UI and make `/app/study` show the spaced review deck.

**Files:**

- Modify: `vens-hub-web/src/App.tsx:2680-2764`
- Modify: `vens-hub-web/src/App.tsx:1535-1541`
- Modify: `vens-hub-web/src/App.tsx:3568-3570`

**Steps:**

1. Rename the visible nav label from `Study` to `Flashcards` while keeping `/app/study` initially to avoid breaking existing navigation.
2. Replace `StudyPage` body with a `FlashcardsPage` implementation.
3. Add optional route alias `/app/flashcards` if desired, but keep `/app/study` working.
4. Page empty state:
   - title: `No flashcards yet`
   - body: explain that flashcards appear after taking quizzes.
   - CTA: link to `/app/courses`.
5. Page summary state:
   - due now count,
   - weak cards count,
   - mastered or strong cards count,
   - total saved questions.
6. Page deck state:
   - vertical snap container,
   - one card per viewport section,
   - scroll hint at top or bottom,
   - progress indicator like `3 of 18`,
   - indicator that the feed is scrollable.

**Acceptance checks:**

- `/app/study` no longer shows file upload controls.
- There is no file input on the page.
- The page clearly presents flashcards and spaced review state.

---

### Task 6: Build the TikTok-style flashcard card UI

**Objective:** Create the actual card experience for reviewing one question at a time.

**Files:**

- Modify: `vens-hub-web/src/App.tsx`
- Modify: `vens-hub-web/src/index.css`

**Card content:**

Each card should show:

- Course code and topic.
- Correct or incorrect badge from the original attempt.
- Question text with `LatexText` where appropriate.
- Student answer.
- Correct answer.
- Last answered date.
- Estimated retention or due status, for example `Due now`, `Weak`, or `Review in 3 days`.
- `Show explanation` toggle.
- `Ask AI to explain` button.
- Review action buttons: `Again`, `Hard`, `Good`, `Easy`.

**UI behavior:**

1. Use a scroll container with CSS similar to:

```css
.flashcard-feed {
  max-height: calc(100vh - 9rem);
  overflow-y: auto;
  scroll-snap-type: y mandatory;
}

.flashcard-card {
  min-height: calc(100vh - 10rem);
  scroll-snap-align: start;
}
```

2. Keep review action buttons sticky near the bottom of each card on mobile.
3. Disable or visually de-emphasize scroll-to-next until a review action has been chosen, if needed.
4. Add a scroll hint, for example `Review this card, then scroll for the next one`, with a down chevron animation.
5. Respect reduced-motion users by disabling animated bouncing hints under `prefers-reduced-motion`.

**Acceptance checks:**

- Mobile viewport shows one main card at a time.
- Trackpad or touch scrolling snaps to the next card.
- There is a visible indicator that more cards are below.
- The UI is usable with keyboard tab navigation.

---

### Task 7: Add static explanation and AI explanation to every card

**Objective:** Show explanations for correct and incorrect cards, and reuse the same assistant backend wiring.

**Files:**

- Modify: `vens-hub-web/src/App.tsx:635-651`
- Modify: `vens-hub-web/src/App.tsx:1602-1691` if shared rendering is extracted
- Modify: `vens-hub-web/src/App.tsx` Flashcards page area

**Steps:**

1. Leave `askAssistant(question, context)` as the single AI transport.
2. In the flashcard card component, add local state for:
   - `showExplanation`,
   - `aiExplanation`,
   - `aiLoading`,
   - `aiError`.
3. Static explanation panel should render:
   - `attempt.explanation`,
   - `attempt.solutionSteps`,
   - fallback text if no explanation exists.
4. AI prompt should include context:

```txt
You are helping a Vens Hub student review a flashcard.
Course: {courseCode} - {courseTitle}
Topic: {topicName}
Question: {questionText}
Student answer: {selectedAnswerText}
Correct answer: {correctAnswerText}
The student originally got this {correct/incorrect}.
Explain the concept clearly and briefly, then point out the key reasoning step.
```

5. Render AI response inside the card, not as the floating assistant panel.
6. Allow AI explanation for correct and incorrect answers.

**Acceptance checks:**

- Correct cards still show explanation and AI explanation.
- Incorrect cards show explanation and AI explanation.
- If AI fails, the card shows a friendly fallback and does not break the feed.
- Floating AI assistant still works.

---

### Task 8: Remove upload-only code and environment references

**Objective:** Cleanly replace study uploads without leaving dead upload behavior in the web app.

**Files:**

- Modify: `vens-hub-web/src/App.tsx`
- Modify: `vens-hub-web/src/index.css`
- Modify: `vens-hub-web/env.example`

**Steps:**

1. Remove `StudyUpload` type if no longer used.
2. Remove `UPLOADS_KEY` if no longer used.
3. Remove `UPLOAD_API_BASE` if no upload code remains.
4. Remove `safePathPart`, `safeFilename`, `makeObjectKey`, `uploadStudyFile`, and `formatBytes` if no longer used.
5. Remove unused icon imports such as `UploadCloud` and possibly `FileText` if they are only used by uploads.
6. Remove or repurpose CSS for:
   - `.upload-drop`,
   - `.file-list`,
   - `.upload-status`,
   - `.upload-badge`.
7. Remove `VITE_UPLOAD_API_BASE_URL` from `env.example` if the Worker upload endpoint is no longer used anywhere in `vens-hub-web`.
8. Keep generic `.study-grid` only if repurposed for flashcards; otherwise replace with `.flashcards-page`, `.flashcard-feed`, and `.flashcard-card`.

**Acceptance checks:**

- TypeScript has no unused variables from upload code.
- `env.example` no longer implies that upload setup is needed for this feature.
- Searching `src` for `uploadStudyFile`, `StudyUpload`, and `UPLOADS_KEY` returns no results.

---

### Task 9: Update copy across landing, dashboard, and empty states

**Objective:** Ensure the product no longer advertises study-material uploads as a core feature.

**Files:**

- Modify: `vens-hub-web/src/App.tsx:927-930`
- Modify: `vens-hub-web/src/App.tsx:982-986`
- Modify other copy found by searching `upload`, `uploads`, `textbooks`, and `materials`.

**Steps:**

1. Replace landing carousel text like `Upload textbooks & study at your pace.` with flashcard copy.
2. Replace hero copy mentioning `study uploads` with flashcards and spaced review.
3. Ensure page title and nav label use `Flashcards` consistently.
4. Do not remove unrelated `Study block` copy in the schedule feature.

**Acceptance checks:**

- User-facing upload/materials copy is gone where it referred to the old page.
- Schedule copy that says `Study block` remains unchanged.

---

### Task 10: Update smoke test for flashcards

**Objective:** Replace upload smoke coverage with flashcard coverage.

**Files:**

- Modify: `vens-hub-web/scripts/smoke.cjs`

**Steps:**

1. Remove the file upload flow at lines 59-66.
2. Keep assistant smoke coverage at lines 49-57.
3. Add a quiz flow that answers at least one MCQ and then navigates to `/app/study`.
4. Assert the flashcards page renders:
   - `Flashcards` heading,
   - at least one card,
   - correct answer text,
   - explanation toggle,
   - AI explanation button.
5. If API data is unreliable in smoke, seed localStorage with one valid flashcard attempt and state directly before visiting `/app/study`, then separately smoke the quiz recording through a lighter assertion.
6. Update final log message to mention flashcards instead of R2 upload fallback.

**Acceptance checks:**

- `npm run smoke` no longer depends on file upload or R2.
- Smoke covers the new flashcards page.

---

## Validation Plan

Run these from `vens-hub-web` after implementation:

```bash
npm run build
npm run lint
```

For browser validation:

```bash
npm run dev -- --host 127.0.0.1
npm run smoke
```

Manual checks:

1. Register or sign in.
2. Take one multiple-choice quiz and intentionally get one question wrong.
3. Take one multiple-choice quiz and get one question correct.
4. Visit `/app/study`.
5. Confirm both correct and incorrect cards appear.
6. Confirm every card shows correct answer.
7. Confirm `Show explanation` works for both correct and incorrect cards.
8. Confirm `Ask AI to explain` returns text inside the card.
9. Click `Again`, `Hard`, `Good`, and `Easy` across cards and confirm due status changes.
10. Test mobile width in browser devtools and verify scroll snap plus scroll indicator.
11. Confirm the floating AI assistant still opens and responds.
12. Confirm Hub and Dashboard still show quiz aggregate metrics.

---

## Risks and Tradeoffs

1. **Local-only persistence:** The MVP stores flashcard attempts in browser localStorage because the current web app already stores quiz aggregates that way. This is fast and avoids backend changes, but it does not sync across devices. If cross-device flashcards are required, add backend or Firestore sync as a follow-up.
2. **Existing aggregate attempts cannot be migrated:** Old `ATTEMPTS_KEY` data lacks question text and answers, so the feature should start collecting cards from new quiz activity only.
3. **Monolithic `App.tsx`:** The app currently keeps most UI in one large file. Adding all flashcard UI there is simplest, but pure scheduler logic should go into `src/flashcards.ts` to keep the feature testable.
4. **AI latency inside feed:** AI explanations should load per card only when requested, not automatically for every card.
5. **Question id stability:** If API question ids change, deterministic fallback keys based on question text reduce duplicate cards but are not perfect.
6. **Smoke test API dependency:** If the external API has flaky question data, seed localStorage in smoke for page rendering and separately test quiz recording with a narrower path.

---

## Open Questions for User Review

1. Should the sidebar label become `Flashcards`, or should it stay `Study` while the page title says `Flashcards`?
2. Should the route remain `/app/study`, or should we add `/app/flashcards` as the primary route with `/app/study` kept as an alias?
3. Is local browser storage acceptable for the first version, or should flashcards sync across devices immediately?
4. Should reviewing a card require pressing `Again`, `Hard`, `Good`, or `Easy` before scrolling, or should scrolling alone count as reviewed?
5. Should AI explanations be cached after the first request per card to reduce repeated assistant calls?

---

## Recommended First Implementation Slice

Implement in this order after approval:

1. Add `src/flashcards.ts` scheduler and types.
2. Record MCQ flashcard attempts.
3. Replace `StudyPage` with a flashcards empty/deck page.
4. Add static explanation and review rating actions.
5. Add AI explanation per card.
6. Add theory and gap-fill recording.
7. Remove upload code and update copy.
8. Update smoke test and run full validation.

This order produces a visible working feature early while keeping upload removal and test cleanup controlled.

---

## Non-Implementation Note

This plan intentionally does not implement the feature yet. It is ready for user review first, then implementation can start after explicit approval.
