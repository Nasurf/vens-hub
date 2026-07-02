const API_BASE = import.meta.env.VITE_API_BASE_URL

if (!API_BASE) {
  throw new Error('VITE_API_BASE_URL is required — copy env.example to .env.local and set it')
}

type BatchResult = {
  topicName: string
  courseCode: string
  isCorrect: boolean
}

export type CourseStats = {
  totalKcs: number
  masteredKcs: number
  avgMastery: number
  totalAttempts: number
  correctAttempts: number
  lastActivityAt: string
}

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

export type AdaptiveAttempt = {
  id: string
  user_id: string
  question_id?: number | string | null
  course_code: string
  topic_name: string
  is_correct: number | boolean
  selected_answer_index?: number | null
  elapsed_seconds?: number | null
  mastery_before: number
  mastery_after: number
  created_at: string
}

type RequestOptions = RequestInit & { userId?: string }

async function adaptiveFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { userId, headers, ...init } = options
  const response = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(userId ? { 'X-User-Id': userId } : {}),
      ...headers,
    },
  })

  if (!response.ok) {
    throw new Error(`Adaptive request failed (${response.status})`)
  }

  return response.json() as Promise<T>
}

export function submitBatchResults(userId: string, results: BatchResult[]) {
  return adaptiveFetch<{ status: string; count: number }>('/adaptive/submit-batch', {
    method: 'POST',
    userId,
    body: JSON.stringify({ results }),
  })
}

export function getUserStats(userId: string) {
  return adaptiveFetch<{ courses: Record<string, CourseStats> }>('/user/stats', { userId })
}

export function getUserMastery(userId: string) {
  return adaptiveFetch<{ topics: MasteryRecord[] }>('/user/mastery', { userId })
}

export function getCourseMastery(userId: string, courseCode: string) {
  return adaptiveFetch<{
    courseCode: string
    topics: MasteryRecord[]
    avgMastery: number
    masteredKcs: number
    totalKcs: number
  }>(`/user/mastery/${encodeURIComponent(courseCode)}`, { userId })
}

export function getUserAttempts(userId: string, courseCode?: string, limit = 100) {
  const params = new URLSearchParams({ limit: String(limit) })
  if (courseCode) params.set('course', courseCode)
  return adaptiveFetch<{ attempts: AdaptiveAttempt[]; nextCursor: string | null; limit: number }>(
    `/user/attempts?${params.toString()}`,
    { userId },
  )
}
