const API_BASE = import.meta.env.VITE_API_BASE_URL

// ─── Types ───────────────────────────────────────────────────────────────────

export type MasteryRecord = {
  topic_name: string
  course_code: string
  mastery_prob: number
  s_parameter: number
  status: 'learning' | 'reviewing'
  total_attempts: number
  correct_attempts: number
  last_attempt_at: string
  next_review_due: string
}

export type CourseStats = {
  totalKcs: number
  masteredKcs: number
  avgMastery: number
  totalAttempts: number
  correctAttempts: number
  lastActivityAt: string
}

export type AttemptRecord = {
  id: string
  question_id: number
  course_code: string
  topic_name: string
  is_correct: number
  selected_answer_index: number
  elapsed_seconds: number
  mastery_before: number
  mastery_after: number
  created_at: string
}

export type BatchResultItem = {
  topicName: string
  courseCode: string
  isCorrect: boolean
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function headers(userId?: string): Record<string, string> {
  const h: Record<string, string> = { 'Content-Type': 'application/json' }
  if (userId) h['X-User-Id'] = userId
  return h
}

async function apiGet<T>(path: string, userId?: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { headers: headers(userId) })
  if (!res.ok) throw new Error(`GET ${path} failed: ${res.status}`)
  return res.json() as Promise<T>
}

async function apiPost<T>(path: string, body: unknown, userId?: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: headers(userId),
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`POST ${path} failed: ${res.status}`)
  return res.json() as Promise<T>
}

// ─── Adaptive Endpoints ──────────────────────────────────────────────────────

export async function submitBatchResults(
  userId: string,
  results: BatchResultItem[],
): Promise<{ status: string; count: number }> {
  return apiPost('/adaptive/submit-batch', { results }, userId)
}

// ─── User Performance Endpoints ──────────────────────────────────────────────

export async function getUserStats(
  userId: string,
): Promise<{ courses: Record<string, CourseStats> }> {
  return apiGet('/user/stats', userId)
}

export async function getUserMastery(
  userId: string,
): Promise<{ topics: MasteryRecord[] }> {
  return apiGet('/user/mastery', userId)
}

export async function getUserMasteryForCourse(
  userId: string,
  courseCode: string,
): Promise<{
  courseCode: string
  topics: MasteryRecord[]
  avgMastery: number
  masteredKcs: number
  totalKcs: number
}> {
  return apiGet(`/user/mastery/${encodeURIComponent(courseCode)}`, userId)
}

export async function getUserAttempts(
  userId: string,
  params: { course?: string; limit?: number; cursor?: string } = {},
): Promise<{ attempts: AttemptRecord[]; nextCursor: string | null; limit: number }> {
  const searchParams = new URLSearchParams()
  if (params.course) searchParams.set('course', params.course)
  if (params.limit) searchParams.set('limit', String(params.limit))
  if (params.cursor) searchParams.set('cursor', params.cursor)
  const qs = searchParams.toString()
  return apiGet(`/user/attempts${qs ? `?${qs}` : ''}`, userId)
}

export async function seedMastery(
  userId: string,
  kcStates: Record<string, Record<string, unknown>>,
): Promise<{ seeded: number; message: string }> {
  return apiPost('/user/seed-mastery', { kcStates }, userId)
}
