// ─── Flashcard Types ──────────────────────────────────────────────────────────

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

export type ReviewRating = 'again' | 'hard' | 'good' | 'easy'

// ─── Storage Keys ─────────────────────────────────────────────────────────────

export const FLASHCARD_ATTEMPTS_KEY = 'vens-hub-web-flashcard-attempts'
export const FLASHCARD_STATES_KEY = 'vens-hub-web-flashcard-states'
export const FLASHCARD_SYNC_META_KEY = 'vens-hub-web-flashcard-sync-meta'

export type FlashcardSyncMeta = {
  dirty: boolean
  pendingSince?: string
  lastDirtyAt?: string
  lastSyncedAt?: string
  lastError?: string
  lastAttemptCount?: number
  lastStateCount?: number
}

// ─── Deterministic Key ────────────────────────────────────────────────────────

export function normalizeTextForKey(value: string): string {
  return value
    .toLowerCase()
    .replace(/\\[a-z]+/g, ' ')
    .replace(/[^a-z0-9.+-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function makeQuestionKey(
  courseCode: string,
  mode: FlashcardQuestionMode,
  question: { id?: number | string; question?: string },
): string {
  const qid = question.id
  if (qid !== undefined && qid !== null && String(qid).trim().length > 0) {
    return `${courseCode}:${mode}:${String(qid)}`
  }
  const text = normalizeTextForKey(question.question ?? '').slice(0, 80)
  return `${courseCode}:${mode}:${text}`
}

// ─── Builder ──────────────────────────────────────────────────────────────────

export function buildFlashcardAttempt(args: {
  courseCode: string
  courseTitle: string
  topicName: string
  mode: FlashcardQuestionMode
  questionId: string | number
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
}): FlashcardAttempt {
  const questionKey = makeQuestionKey(args.courseCode, args.mode, {
    id: args.questionId,
    question: args.questionText,
  })
  return {
    id: crypto.randomUUID(),
    questionKey,
    questionId: String(args.questionId),
    courseCode: args.courseCode,
    courseTitle: args.courseTitle,
    topicName: args.topicName,
    mode: args.mode,
    questionText: args.questionText,
    options: args.options,
    selectedAnswerText: args.selectedAnswerText,
    selectedAnswerIndex: args.selectedAnswerIndex,
    correctAnswerText: args.correctAnswerText,
    correctAnswerIndex: args.correctAnswerIndex,
    isCorrect: args.isCorrect,
    score: args.score,
    explanation: args.explanation,
    solutionSteps: args.solutionSteps,
    ragSources: args.ragSources,
    answeredAt: new Date().toISOString(),
  }
}

// ─── Ebbinghaus Scheduler (Pure Functions) ────────────────────────────────────

const MIN_EASE = 1.3
const DEFAULT_EASE = 2.3
const TEN_MINUTES_DAYS = 10 / (60 * 24) // ~0.0069

/**
 * Estimate retention using the Ebbinghaus forgetting curve:
 *   R = exp(-elapsed / stability)
 */
export function estimateRetention(
  state: FlashcardReviewState,
  nowIso: string,
): number {
  const now = new Date(nowIso).getTime()
  const lastReview = new Date(state.lastReviewedAt ?? state.lastAnsweredAt).getTime()
  const elapsedMs = Math.max(0, now - lastReview)
  const elapsedDays = elapsedMs / (1000 * 60 * 60 * 24)
  if (state.stabilityDays <= 0) return 0
  return Math.exp(-elapsedDays / state.stabilityDays)
}

/**
 * Create or update review state when a quiz answer is recorded.
 */
export function upsertReviewStateForQuizAnswer(
  existing: FlashcardReviewState | undefined,
  attempt: FlashcardAttempt,
): FlashcardReviewState {
  const now = attempt.answeredAt

  if (!existing) {
    // Brand-new card
    if (attempt.isCorrect) {
      const nextReview = new Date(new Date(now).getTime() + 24 * 60 * 60 * 1000).toISOString()
      return {
        questionKey: attempt.questionKey,
        firstSeenAt: now,
        lastAnsweredAt: now,
        lastReviewedAt: undefined,
        nextReviewAt: nextReview,
        stabilityDays: 1,
        easeFactor: DEFAULT_EASE,
        repetitions: 1,
        lapses: 0,
        lastResult: 'correct',
      }
    } else {
      // Incorrect first time — due in 10 minutes
      const nextReview = new Date(new Date(now).getTime() + 10 * 60 * 1000).toISOString()
      return {
        questionKey: attempt.questionKey,
        firstSeenAt: now,
        lastAnsweredAt: now,
        lastReviewedAt: undefined,
        nextReviewAt: nextReview,
        stabilityDays: 0.25,
        easeFactor: Math.max(MIN_EASE, DEFAULT_EASE - 0.2),
        repetitions: 0,
        lapses: 1,
        lastResult: 'incorrect',
      }
    }
  }

  // Existing card — update
  if (attempt.isCorrect) {
    const newReps = existing.repetitions + 1
    const newStability = existing.stabilityDays * existing.easeFactor
    const intervalMs = newStability * 24 * 60 * 60 * 1000
    const nextReview = new Date(new Date(now).getTime() + intervalMs).toISOString()
    return {
      ...existing,
      lastAnsweredAt: now,
      nextReviewAt: nextReview,
      stabilityDays: newStability,
      repetitions: newReps,
      lastResult: 'correct',
    }
  } else {
    const nextReview = new Date(new Date(now).getTime() + 10 * 60 * 1000).toISOString()
    return {
      ...existing,
      lastAnsweredAt: now,
      nextReviewAt: nextReview,
      stabilityDays: 0.25,
      easeFactor: Math.max(MIN_EASE, existing.easeFactor - 0.2),
      lapses: existing.lapses + 1,
      repetitions: 0,
      lastResult: 'incorrect',
    }
  }
}

/**
 * Apply a manual review rating (Again / Hard / Good / Easy).
 */
export function applyReviewRating(
  state: FlashcardReviewState,
  rating: ReviewRating,
  reviewedAtIso: string,
): FlashcardReviewState {
  const reviewedAt = new Date(reviewedAtIso).getTime()
  let newStability: number
  let newEase = state.easeFactor
  let newReps = state.repetitions
  let newLapses = state.lapses
  let newResult = state.lastResult

  switch (rating) {
    case 'again':
      newStability = TEN_MINUTES_DAYS
      newEase = Math.max(MIN_EASE, state.easeFactor - 0.2)
      newLapses = state.lapses + 1
      newReps = 0
      newResult = 'incorrect'
      break
    case 'hard':
      newStability = Math.max(TEN_MINUTES_DAYS, state.stabilityDays * 1.2)
      newEase = Math.max(MIN_EASE, state.easeFactor - 0.15)
      newReps = state.repetitions + 1
      newResult = 'correct'
      break
    case 'good':
      newStability = Math.max(0.5, state.stabilityDays * state.easeFactor)
      newReps = state.repetitions + 1
      newResult = 'correct'
      break
    case 'easy':
      newStability = Math.max(1, state.stabilityDays * state.easeFactor * 1.3)
      newEase = state.easeFactor + 0.15
      newReps = state.repetitions + 1
      newResult = 'correct'
      break
  }

  const intervalMs = newStability * 24 * 60 * 60 * 1000
  const nextReview = new Date(reviewedAt + intervalMs).toISOString()

  return {
    ...state,
    lastReviewedAt: reviewedAtIso,
    nextReviewAt: nextReview,
    stabilityDays: newStability,
    easeFactor: newEase,
    repetitions: newReps,
    lapses: newLapses,
    lastResult: newResult,
    lastQuality: rating,
  }
}

// ─── Due-Status Helpers ───────────────────────────────────────────────────────

export function getDueLabel(state: FlashcardReviewState, nowIso: string): string {
  const now = new Date(nowIso).getTime()
  const due = new Date(state.nextReviewAt).getTime()
  if (now >= due) return 'Due now'
  const diffMs = due - now
  const diffMins = Math.floor(diffMs / (1000 * 60))
  if (diffMins < 60) return `Review in ${diffMins}m`
  const diffHours = Math.floor(diffMins / 60)
  if (diffHours < 24) return `Review in ${diffHours}h`
  const diffDays = Math.floor(diffHours / 24)
  return `Review in ${diffDays}d`
}

export function getStrengthLabel(retention: number, state: FlashcardReviewState): string {
  if (state.lapses >= 3 || retention < 0.3) return 'Weak'
  if (retention < 0.6) return 'Learning'
  if (state.repetitions >= 5 && retention >= 0.85) return 'Mastered'
  return 'Strong'
}

// ─── Deck Builder (Sort by due priority) ──────────────────────────────────────

export function buildReviewDeck(
  attempts: FlashcardAttempt[],
  states: FlashcardReviewState[],
  nowIso: string,
): FlashcardCard[] {
  const stateMap = new Map<string, FlashcardReviewState>()
  for (const s of states) {
    stateMap.set(s.questionKey, s)
  }

  // Get latest attempt per question key
  const latestMap = new Map<string, FlashcardAttempt>()
  for (const a of attempts) {
    const existing = latestMap.get(a.questionKey)
    if (!existing || new Date(a.answeredAt) > new Date(existing.answeredAt)) {
      latestMap.set(a.questionKey, a)
    }
  }

  const now = new Date(nowIso).getTime()
  const cards: FlashcardCard[] = []

  for (const [key, attempt] of latestMap) {
    const state = stateMap.get(key)
    if (!state) continue

    const retention = estimateRetention(state, nowIso)
    const dueTime = new Date(state.nextReviewAt).getTime()
    const isDue = now >= dueTime

    // dueScore: lower = higher priority
    // Overdue cards get negative scores (highest priority)
    // Cards with low retention but not yet due get moderate priority
    // Strong cards with future due dates get high scores (low priority)
    const overdueDays = (now - dueTime) / (1000 * 60 * 60 * 24)
    const lapsePenalty = state.lapses * 0.5
    const dueScore = isDue
      ? -overdueDays - lapsePenalty // more overdue = more negative = higher priority
      : (dueTime - now) / (1000 * 60 * 60 * 24) - lapsePenalty * 0.1 // days until due

    cards.push({
      latestAttempt: attempt,
      state,
      retention,
      dueScore,
      isDue,
    })
  }

  // Sort: lowest dueScore first (most overdue / weakest first)
  cards.sort((a, b) => a.dueScore - b.dueScore)
  return cards
}

// ─── Stats Helpers ────────────────────────────────────────────────────────────

export function getDeckStats(cards: FlashcardCard[]) {
  let dueNow = 0

  // Aggregate by course
  const courseMap = new Map<string, { retentions: number[]; dueCount: number }>()
  for (const card of cards) {
    const code = card.latestAttempt.courseCode
    if (!courseMap.has(code)) courseMap.set(code, { retentions: [], dueCount: 0 })
    const entry = courseMap.get(code)!
    entry.retentions.push(card.retention)
    if (card.isDue) {
      entry.dueCount++
      dueNow++
    }
  }

  let weak = 0
  let strong = 0
  let mastered = 0

  for (const [, entry] of courseMap) {
    const avgRetention = entry.retentions.reduce((a, b) => a + b, 0) / entry.retentions.length
    const totalCards = entry.retentions.length
    if (avgRetention < 0.4 || entry.dueCount > totalCards * 0.5) {
      weak++
    } else if (avgRetention >= 0.8 && totalCards >= 3) {
      mastered++
    } else {
      strong++
    }
  }

  return { dueNow, weak, strong, mastered, total: cards.length, totalCourses: courseMap.size }
}

// ─── localStorage Read/Write + Sync Metadata ──────────────────────────────────

function readJson<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

function writeJson<T>(key: string, value: T) {
  localStorage.setItem(key, JSON.stringify(value))
  window.dispatchEvent(new Event('vens-hub-storage'))
}

type FlashcardWriteOptions = {
  markDirty?: boolean
}

export function readFlashcardSyncMeta(): FlashcardSyncMeta {
  return readJson<FlashcardSyncMeta>(FLASHCARD_SYNC_META_KEY, { dirty: false })
}

function writeFlashcardSyncMeta(meta: FlashcardSyncMeta) {
  writeJson<FlashcardSyncMeta>(FLASHCARD_SYNC_META_KEY, meta)
}

export function markFlashcardsDirty(nowIso = new Date().toISOString()) {
  const current = readFlashcardSyncMeta()
  writeFlashcardSyncMeta({
    ...current,
    dirty: true,
    pendingSince: current.pendingSince ?? nowIso,
    lastDirtyAt: nowIso,
    lastError: undefined,
  })
}

export function markFlashcardsSynced(args: { attemptCount: number; stateCount: number; syncedAt?: string }) {
  writeFlashcardSyncMeta({
    dirty: false,
    lastSyncedAt: args.syncedAt ?? new Date().toISOString(),
    lastAttemptCount: args.attemptCount,
    lastStateCount: args.stateCount,
  })
}

export function markFlashcardsSyncFailed(message: string) {
  const current = readFlashcardSyncMeta()
  writeFlashcardSyncMeta({
    ...current,
    dirty: true,
    pendingSince: current.pendingSince ?? new Date().toISOString(),
    lastDirtyAt: current.lastDirtyAt ?? new Date().toISOString(),
    lastError: message,
  })
}

export function readFlashcardAttempts(): FlashcardAttempt[] {
  return readJson<FlashcardAttempt[]>(FLASHCARD_ATTEMPTS_KEY, [])
}

export function writeFlashcardAttempts(attempts: FlashcardAttempt[], options: FlashcardWriteOptions = {}) {
  writeJson<FlashcardAttempt[]>(FLASHCARD_ATTEMPTS_KEY, attempts)
  if (options.markDirty ?? true) markFlashcardsDirty()
}

export function readFlashcardStates(): FlashcardReviewState[] {
  return readJson<FlashcardReviewState[]>(FLASHCARD_STATES_KEY, [])
}

export function writeFlashcardStates(states: FlashcardReviewState[], options: FlashcardWriteOptions = {}) {
  writeJson<FlashcardReviewState[]>(FLASHCARD_STATES_KEY, states)
  if (options.markDirty ?? true) markFlashcardsDirty()
}

export function mergeFlashcardAttempts(
  localAttempts: FlashcardAttempt[],
  remoteAttempts: FlashcardAttempt[],
): FlashcardAttempt[] {
  const byId = new Map<string, FlashcardAttempt>()
  for (const attempt of [...remoteAttempts, ...localAttempts]) {
    if (!attempt.id) continue
    const existing = byId.get(attempt.id)
    if (!existing || new Date(attempt.answeredAt) >= new Date(existing.answeredAt)) {
      byId.set(attempt.id, attempt)
    }
  }
  return [...byId.values()].sort((a, b) => new Date(b.answeredAt).getTime() - new Date(a.answeredAt).getTime())
}

function stateFreshness(state: FlashcardReviewState): number {
  return new Date(state.lastReviewedAt ?? state.lastAnsweredAt ?? state.firstSeenAt).getTime()
}

export function mergeFlashcardStates(
  localStates: FlashcardReviewState[],
  remoteStates: FlashcardReviewState[],
): FlashcardReviewState[] {
  const byKey = new Map<string, FlashcardReviewState>()
  for (const state of [...remoteStates, ...localStates]) {
    if (!state.questionKey) continue
    const existing = byKey.get(state.questionKey)
    if (!existing || stateFreshness(state) >= stateFreshness(existing)) {
      byKey.set(state.questionKey, state)
    }
  }
  return [...byKey.values()].sort((a, b) => a.questionKey.localeCompare(b.questionKey))
}

/**
 * Record a new flashcard attempt and update its review state.
 * Prevents duplicates within a 2-second window.
 */
export function recordFlashcardAttempt(attempt: FlashcardAttempt) {
  const attempts = readFlashcardAttempts()

  // Duplicate guard: skip if same questionKey was recorded within 2 seconds
  const recentDupe = attempts.find(
    (a) =>
      a.questionKey === attempt.questionKey &&
      Math.abs(new Date(a.answeredAt).getTime() - new Date(attempt.answeredAt).getTime()) < 2000,
  )
  if (recentDupe) return

  writeFlashcardAttempts([attempt, ...attempts])

  // Update review state
  const states = readFlashcardStates()
  const existingIdx = states.findIndex((s) => s.questionKey === attempt.questionKey)
  const existing = existingIdx >= 0 ? states[existingIdx] : undefined
  const updated = upsertReviewStateForQuizAnswer(existing, attempt)

  if (existingIdx >= 0) {
    states[existingIdx] = updated
  } else {
    states.push(updated)
  }
  writeFlashcardStates(states)
}

/**
 * Update a flashcard's review state when the student rates it.
 */
export function updateFlashcardReview(questionKey: string, rating: ReviewRating) {
  const states = readFlashcardStates()
  const idx = states.findIndex((s) => s.questionKey === questionKey)
  if (idx < 0) return

  const now = new Date().toISOString()
  states[idx] = applyReviewRating(states[idx], rating, now)
  writeFlashcardStates(states)
}
