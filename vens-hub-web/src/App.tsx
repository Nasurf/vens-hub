import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import type { Variants } from 'framer-motion'
import { DayPicker } from 'react-day-picker'
import { format, isSameDay, isToday } from 'date-fns'
import 'react-day-picker/style.css'
import {
  AlertCircle,
  ArrowLeft,
  BarChart3,
  Bot,
  BookOpen,
  BrainCircuit,
  Building2,
  Calculator,
  CalendarDays,
  Check,
  Clock3,
  CheckCircle2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  CircleUserRound,
  ClipboardList,
  Eye,
  EyeOff,
  Flame,
  GraduationCap,
  Home,
  Laptop,
  Layers3,
  LineChart,
  Lock,
  LogOut,
  Mail,
  Menu,
  MessageCircle,
  Moon,
  Palette,
  Pencil,
  PlayCircle,
  Plus,
  RefreshCw,
  RotateCcw,
  Search,
  Send,
  Sparkles,
  Sun,
  Target,
  TimerReset,
  Trash2,
  Trophy,
  MapPin,
  Users,
  User,
  X,
} from 'lucide-react'
import clsx from 'clsx'
import {
  BrowserRouter,
  Link,
  Navigate,
  NavLink,
  Outlet,
  Route,
  Routes,
  useLocation,
  useNavigate,
  useParams,
} from 'react-router-dom'
import {
  onAuthChange,
  loginWithEmail,
  registerWithEmail,
  loginWithGoogle,
  signOutUser,
  hasFirebaseConfig,
} from './firebase'
import { LatexText } from './LatexText'
import {
  submitBatchResults,
  getUserStats,
  getUserMastery,
  getUserMasteryForCourse,
  getUserAttempts,
  getUserFlashcards,
  syncUserFlashcards,
  type AttemptRecord,
  type CourseStats,
  type MasteryRecord,
} from './adaptive'
import {
  buildFlashcardAttempt,
  recordFlashcardAttempt,
  readFlashcardAttempts,
  readFlashcardStates,
  readFlashcardSyncMeta,
  writeFlashcardAttempts,
  writeFlashcardStates,
  mergeFlashcardAttempts,
  mergeFlashcardStates,
  markFlashcardsDirty,
  markFlashcardsSynced,
  markFlashcardsSyncFailed,
  buildReviewDeck,
  getDeckStats,
  getDueLabel,
  getStrengthLabel,
  updateFlashcardReview,
  type FlashcardCard,
  type FlashcardSyncMeta,
  type ReviewRating,
} from './flashcards'

type Department = {
  name: string
  code: string
  course_count: number
}

type Course = {
  code: string
  title: string
  type?: string
  units?: number
  levels?: string
  semesters?: string
  semester?: string[]
  description?: string
  outline?: string
  department?: string
  department_code?: string
  question_count?: number
}

type Question = {
  id: number | string
  topic_name?: string
  subtopic_name?: string
  question_type?: string
  difficulty?: string
  difficulty_ranking?: number
  question: string
  options?: string | string[]
  correct_answer_index?: number
  correct_answer?: string
  correct_answer_text?: string
  explanation?: string
  solution_steps?: string | string[]
  rag_sources?: string
}

type Profile = {
  firstName: string
  lastName: string
  email: string
  departmentCode: string
  departmentName: string
  selectedCourses: Array<{ code: string; title: string }>
}

type EventItem = {
  id: string
  title: string
  course?: string
  date: string
  start: string
  end: string
  venue?: string
  type?: string
  priority?: string
  notes?: string
  participants?: string
  reminder?: string
}



type QuizAttempt = {
  id: string
  courseCode: string
  courseTitle: string
  mode?: 'multiple-choice' | 'theory' | 'gap-fill'
  score: number
  total: number
  createdAt: string
}

type AssistantMessage = {
  id: string
  role: 'assistant' | 'user'
  text: string
  isError?: boolean
}

type AsyncState<T> = {
  data?: T
  error?: string
  loading: boolean
}

const API_BASE =
  import.meta.env.VITE_API_BASE_URL

const ASSISTANT_API_BASE = import.meta.env.VITE_ASSISTANT_API_BASE_URL

if (!API_BASE) {
  throw new Error('VITE_API_BASE_URL is required — copy env.example to .env.local and set it')
}

const PROFILE_KEY = 'vens-hub-web-profile'
const EVENTS_KEY = 'vens-hub-web-events'

const ATTEMPTS_KEY = 'vens-hub-web-quiz-attempts'
const STREAK_WINDOW_DAYS = 28
const THEME_KEY = 'vens-hub-web-theme'
const SCHEME_KEY = 'vens-hub-web-scheme'

const departments: Department[] = [
  { name: 'AERONAUTICAL ENGINEERING', code: 'AER', course_count: 93 },
  { name: 'BIOMEDICAL ENGINEERING', code: 'BIO', course_count: 107 },
  { name: 'CHEMICAL ENGINEERING', code: 'CHE', course_count: 95 },
  { name: 'CIVIL ENGINEERING', code: 'CIV', course_count: 86 },
  { name: 'COMPUTER ENGINEERING', code: 'COM', course_count: 78 },
  { name: 'ELECTRICAL AND ELECTRONICS ENGINEERING', code: 'ELE', course_count: 102 },
  { name: 'MECHANICAL ENGINEERING', code: 'MEC', course_count: 96 },
  { name: 'MECHATRONICS ENGINEERING', code: 'MCT', course_count: 80 },
  { name: 'PETROLEUM ENGINEERING', code: 'PET', course_count: 72 },
]



const featureHighlights = [
  'Practice with multiple choice, theory and gap-fill questions',
  'Plan lectures, study blocks and assignment deadlines in one place',
  'Explore a curated engineering course and question bank',
  'Track streaks, performance and subject focus as you learn',
]

function cx(...classes: Array<string | false | undefined>) {
  return classes.filter(Boolean).join(' ')
}

function readJson<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch (e) {
    console.warn(`[vens-hub] Failed to parse localStorage key "${key}":`, e)
    return fallback
  }
}

function writeJson<T>(key: string, value: T) {
  localStorage.setItem(key, JSON.stringify(value))
  window.dispatchEvent(new Event('vens-hub-storage'))
}

function getProfile() {
  return readJson<Profile | null>(PROFILE_KEY, null)
}

function saveProfile(profile: Profile | null) {
  if (profile) {
    writeJson(PROFILE_KEY, profile)
  } else {
    localStorage.removeItem(PROFILE_KEY)
    window.dispatchEvent(new Event('vens-hub-storage'))
  }
}

// ─── Theme & Color Scheme Persistence ────────────────────────────────────────

const colorSchemes = [
  { name: 'Teal', color: '#0f9b8e', dark: '#4DB6AC' },
  { name: 'Blue', color: '#1E88E5', dark: '#64B5F6' },
  { name: 'Purple', color: '#7E57C2', dark: '#9575CD' },
  { name: 'Pink', color: '#F42870', dark: '#F06292' },
  { name: 'Orange', color: '#FB8C00', dark: '#FFB74D' },
  { name: 'Green', color: '#43A047', dark: '#81C784' },
  { name: 'Slate', color: '#555555', dark: '#AAAAAA' },
]

function getTheme(): 'light' | 'dark' | 'system' {
  try {
    const raw = localStorage.getItem(THEME_KEY)
    if (raw === 'dark' || raw === 'system') return raw
    return 'light'
  } catch {
    return 'light'
  }
}

function saveTheme(mode: 'light' | 'dark' | 'system') {
  localStorage.setItem(THEME_KEY, mode)
  applyTheme(mode)
}

function getScheme(): string {
  try {
    return localStorage.getItem(SCHEME_KEY) || '#0f9b8e'
  } catch {
    return '#0f9b8e'
  }
}

function saveScheme(color: string) {
  localStorage.setItem(SCHEME_KEY, color)
  applyScheme(color)
}

function resolveTheme(mode: 'light' | 'dark' | 'system'): 'light' | 'dark' {
  if (mode !== 'system') return mode
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

function applyTheme(mode: 'light' | 'dark' | 'system') {
  const resolved = resolveTheme(mode)
  document.documentElement.setAttribute('data-theme', resolved)
  localStorage.setItem(THEME_KEY, mode)
}

function applyScheme(color: string) {
  const scheme = colorSchemes.find((s) => s.color === color)
  if (!scheme) return
  document.documentElement.setAttribute('data-scheme', scheme.name.toLowerCase())
  localStorage.setItem(SCHEME_KEY, color)
}

function useTheme() {
  const [theme, setTheme] = useState<'light' | 'dark' | 'system'>(() => getTheme())
  const [scheme, setScheme] = useState<string>(() => getScheme())
  const [resolved, setResolved] = useState<'light' | 'dark'>(() => resolveTheme(theme))

  useEffect(() => {
    const resolvedTheme = resolveTheme(theme)
    setResolved(resolvedTheme)
    applyTheme(theme)
    applyScheme(scheme)

    if (theme === 'system') {
      const mq = window.matchMedia('(prefers-color-scheme: dark)')
      const handler = () => {
        const r = resolveTheme('system')
        setResolved(r)
        document.documentElement.setAttribute('data-theme', r)
      }
      mq.addEventListener('change', handler)
      return () => mq.removeEventListener('change', handler)
    }
  }, [theme, scheme])

  return { theme, setTheme: (m: 'light' | 'dark' | 'system') => { saveTheme(m); setTheme(m) },
           scheme, setScheme: (c: string) => { saveScheme(c); setScheme(c) },
           resolved }
}

function useProfile() {
  const [profile, setProfile] = useState<Profile | null>(() => getProfile())
  useEffect(() => {
    const sync = () => setProfile(getProfile())
    window.addEventListener('storage', sync)
    window.addEventListener('vens-hub-storage', sync)
    return () => {
      window.removeEventListener('storage', sync)
      window.removeEventListener('vens-hub-storage', sync)
    }
  }, [])
  return profile
}

function useFirebaseUser() {
  const [user, setUser] = useState<import('firebase/auth').User | null | 'loading'>('loading')
  useEffect(() => {
    const unsub = onAuthChange((u: import('firebase/auth').User | null) => setUser(u))
    return unsub
  }, [])
  return user
}

function useStoredList<T>(key: string, fallback: T[]) {
  const [items, setItems] = useState<T[]>(() => readJson<T[]>(key, fallback))
  const save = (next: T[]) => {
    setItems(next)
    writeJson(key, next)
  }
  return [items, save] as const
}

function parseJsonList(value: unknown): string[] {
  const toText = (item: unknown) => {
    if (typeof item === 'string') return item
    if (typeof item === 'number' || typeof item === 'boolean') return String(item)
    if (item && typeof item === 'object') {
      const record = item as Record<string, unknown>
      if (typeof record.title === 'string') return record.title
      if (typeof record.name === 'string') return record.name
      if (typeof record.label === 'string') return record.label
      return JSON.stringify(record)
    }
    return String(item)
  }

  if (Array.isArray(value)) {
    return value.map(toText)
  }
  if (typeof value !== 'string' || value.trim().length === 0) {
    return []
  }
  const trimmed = value.trim()
  try {
    const parsed = JSON.parse(trimmed)
    if (Array.isArray(parsed)) {
      return parsed.map(toText)
    }
  } catch {
    return [trimmed]
  }
  return [trimmed]
}

function courseLevels(course: Course) {
  return parseJsonList(course.levels ?? course.semester)
}

function courseSemesters(course: Course) {
  return parseJsonList(course.semesters ?? course.semester)
}

function courseOutline(course: Course) {
  return parseJsonList(course.outline)
}

function questionOptions(question: Question) {
  return parseJsonList(question.options)
}

function answerIndex(question: Question) {
  if (typeof question.correct_answer_index === 'number') {
    return question.correct_answer_index
  }
  const answer = question.correct_answer?.trim().toUpperCase()
  if (!answer) return -1
  return ['A', 'B', 'C', 'D', 'E'].indexOf(answer)
}

async function fetchJson<T>(path: string): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: { Accept: 'application/json' },
  })
  if (!response.ok) {
    const detail = await response.text()
    throw new Error(detail || `Request failed with status ${response.status}`)
  }
  return (await response.json()) as T
}

async function fetchUserProfile(userId: string): Promise<Profile | null> {
  const response = await fetch(`${API_BASE}/user/profile`, {
    headers: { Accept: 'application/json', 'X-User-Id': userId },
  })
  if (!response.ok) {
    const detail = await response.text()
    throw new Error(detail || `Profile request failed with status ${response.status}`)
  }
  const data = (await response.json()) as { profile?: Profile | null }
  return data.profile ?? null
}

async function saveUserProfile(userId: string, profile: Profile) {
  const response = await fetch(`${API_BASE}/user/profile`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json', 'X-User-Id': userId },
    body: JSON.stringify(profile),
  })
  if (!response.ok) {
    const detail = await response.text()
    throw new Error(detail || `Profile save failed with status ${response.status}`)
  }
  return response.json() as Promise<{ ok: boolean; userId: string }>
}

function profileFromGoogleAccount(user: { displayName?: string | null; email?: string | null }): Profile {
  return {
    firstName: user.displayName?.split(' ')[0] || 'User',
    lastName: user.displayName?.split(' ').slice(1).join(' ') || '',
    email: user.email || '',
    departmentCode: '',
    departmentName: '',
    selectedCourses: [],
  }
}

async function postJson<T>(baseUrl: string, path: string, body: unknown): Promise<T> {
  const response = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!response.ok) {
    const detail = await response.text()
    throw new Error(detail || `Request failed with status ${response.status}`)
  }
  return (await response.json()) as T
}

const api = {
  departments: () => fetchJson<{ departments: Department[] }>('/departments'),
  courses: (params: { q?: string; limit?: number; cursor?: number; department?: string; level?: string } = {}) => {
    const searchParams = new URLSearchParams()
    if (params.q) searchParams.set('q', params.q)
    if (params.limit) searchParams.set('limit', String(params.limit))
    if (params.cursor) searchParams.set('cursor', String(params.cursor))
    if (params.department) searchParams.set('department', params.department)
    if (params.level) searchParams.set('level', params.level)
    const queryStr = searchParams.toString()
    return fetchJson<{ courses: Course[]; total: number; hasMore: boolean; nextCursor: number }>(
      `/courses${queryStr ? `?${queryStr}` : ''}`
    )
  },
  departmentCourses: (name: string, q?: string, limit?: number, cursor?: number) => {
    const params = new URLSearchParams({ limit: String(limit ?? 20), cursor: String(cursor ?? 0) })
    if (q) params.set('q', q)
    return fetchJson<{ courses: Course[]; total: number; hasMore: boolean; nextCursor: number }>(
      `/departments/${encodeURIComponent(name)}/courses?${params}`
    )
  },
  course: (code: string) => fetchJson<{ course: Course }>(`/courses/${encodeURIComponent(code)}`),
  questions: (code: string) =>
    fetchJson<{ questions: Question[]; count: number }>(`/questions/${encodeURIComponent(code)}`),
}


function normalizeText(value: string) {
  return value
    .toLowerCase()
    .replace(/\\[a-z]+/g, ' ')
    .replace(/[^a-z0-9.+-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function displayText(value: string) {
  return value
    .replace(/\$+/g, '')
    .replace(/\\,/g, ' ')
    .replace(/\\cdot/g, '·')
    .replace(/\\times/g, '×')
    .replace(/\\text\{([^}]*)\}/g, '$1')
    .replace(/\\left|\\right/g, '')
    .replace(/\\[a-zA-Z]+/g, '')
    .replace(/[{}]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function tokenSet(value: string) {
  return new Set(normalizeText(value).split(' ').filter((token) => token.length > 2))
}

function scoreTheoryAnswer(answer: string, question: Question) {
  const correctText = question.correct_answer_text || questionOptions(question)[answerIndex(question)] || question.correct_answer || ''
  const expected = `${correctText} ${question.explanation ?? ''} ${parseJsonList(question.solution_steps).join(' ')}`
  const answerTokens = tokenSet(answer)
  const expectedTokens = [...tokenSet(expected)].filter((token) => !['the', 'and', 'for', 'with', 'from'].includes(token))
  const overlap = expectedTokens.filter((token) => answerTokens.has(token)).length
  const normalizedCorrect = normalizeText(correctText)
  const directAnswerHit = normalizedCorrect.slice(0, 24).trim().length > 0 && normalizeText(answer).includes(normalizedCorrect.slice(0, 24).trim())
  const ratio = expectedTokens.length ? overlap / Math.min(expectedTokens.length, 12) : 0
  const score = directAnswerHit ? 1 : Math.min(1, ratio)
  return {
    score,
    isCorrect: score >= 0.35 || directAnswerHit,
    expected: correctText,
  }
}

function makeGapPrompt(question: Question) {
  const options = questionOptions(question)
  const correct = question.correct_answer_text || options[answerIndex(question)] || question.correct_answer || 'the correct answer'
  const explanation = question.explanation || parseJsonList(question.solution_steps)[0] || 'Use the worked solution to identify the missing term.'
  const choices = [correct, ...options.filter((option) => normalizeText(option) !== normalizeText(correct))].slice(0, 4)
  return {
    statement: `The missing answer is _____. ${explanation}`,
    correct,
    choices,
  }
}




async function askAssistant(messages: AssistantMessage[], context?: string, systemPrompt?: string) {
  const baseUrl = ASSISTANT_API_BASE || API_BASE
  try {
    const response = await postJson<{ answer?: string }>(baseUrl, '/assistant', {
      messages: messages.map(({ role, text }) => ({ role, text })),
      context,
      systemPrompt,
    })
    return response.answer?.trim() || 'No answer was returned.'
  } catch {
    return 'The AI assistant is not available right now. Try again later.'
  }
}

function saveQuizAttempt(attempt: Omit<QuizAttempt, 'id' | 'createdAt'>) {
  const attempts = readJson<QuizAttempt[]>(ATTEMPTS_KEY, [])
  writeJson<QuizAttempt[]>(ATTEMPTS_KEY, [
    { id: crypto.randomUUID(), createdAt: new Date().toISOString(), ...attempt },
    ...attempts,
  ])
}

function useAsync<T>(key: string, loader: () => Promise<T>) {
  const [state, setState] = useState<AsyncState<T>>({ loading: true })
  const loaderRef = useRef(loader)
  useEffect(() => {
    loaderRef.current = loader
  }, [loader])

  useEffect(() => {
    let active = true
    setState({ loading: true })
    loaderRef.current()
      .then((data) => {
        if (active) setState({ data, loading: false })
      })
      .catch((error: Error) => {
        if (active) setState({ error: error.message, loading: false })
      })
    return () => {
      active = false
    }
  }, [key])
  return state
}



function dateToIso(date: Date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function todayIso() {
  return dateToIso(new Date())
}

function dayKey(date: Date) {
  return dateToIso(date)
}

function getStreakStats(attempts: QuizAttempt[]) {
  const completedDays = new Set(attempts.map((attempt) => dayKey(new Date(attempt.createdAt))))
  const today = new Date()
  const todayKey = dayKey(today)
  const completedToday = completedDays.has(todayKey)
  const cursor = new Date(today)
  if (!completedToday) cursor.setDate(cursor.getDate() - 1)

  let currentStreak = 0
  while (completedDays.has(dayKey(cursor)) && currentStreak < STREAK_WINDOW_DAYS) {
    currentStreak += 1
    cursor.setDate(cursor.getDate() - 1)
  }

  const days = Array.from({ length: STREAK_WINDOW_DAYS }, (_, index) => {
    const date = new Date(today)
    date.setDate(today.getDate() - (STREAK_WINDOW_DAYS - 1 - index))
    const key = dayKey(date)
    return {
      key,
      date,
      completed: completedDays.has(key),
      isToday: key === todayKey,
    }
  })

  return {
    completedToday,
    currentStreak,
    completedInWindow: days.filter((day) => day.completed).length,
    days,
  }
}

function BrandMark({ className = '', label = 'Vens Hub' }: { className?: string; label?: string }) {
  return <span aria-label={label} className={cx('brand-logo-mask', className)} role="img" />
}

function Logo({ compact = false, className }: { compact?: boolean; className?: string }) {
  return (
    <Link to={getProfile() ? '/app' : '/'} className={cx('logo-lockup', compact && 'compact', className)}>
      <span className="logo-mark">
        <BrandMark />
      </span>
      {!compact && (
        <span>
          <strong>Vens Hub</strong>
        </span>
      )}
    </Link>
  )
}

function PageHeader({
  eyebrow,
  title,
  children,
}: {
  eyebrow?: string
  title: string
  children?: ReactNode
}) {
  void eyebrow
  return (
    <header className="page-header">
      <div>
        <h1>{title}</h1>
      </div>
      {children}
    </header>
  )
}

function LoadingState({ label = 'Loading Vens Hub data...' }: { label?: string }) {
  return (
    <div className="state-card">
      <span className="loader" />
      <p>{label}</p>
    </div>
  )
}

function ErrorState({ message }: { message: string }) {
  return (
    <div className="state-card error">
      <AlertCircle size={28} />
      <h3>Could not load this section</h3>
      <p>{message}</p>
    </div>
  )
}

function EmptyState({ icon, title, body }: { icon: ReactNode; title: string; body: string }) {
  return (
    <div className="state-card empty">
      {icon}
      <h3>{title}</h3>
      <p>{body}</p>
    </div>
  )
}

function MetricCard({
  icon,
  label,
  value,
  hint,
  to,
}: {
  icon: ReactNode
  label: string
  value: string | number
  hint: string
  to?: string
}) {
  const content = (
    <>
      <div className="metric-icon">{icon}</div>
      <p>{label}</p>
      <strong>{value}</strong>
      <span>{hint}</span>
    </>
  )

  if (to) {
    return <Link className="metric-card" to={to} aria-label={`${label}: ${value}`}>{content}</Link>
  }

  return (
    <article className="metric-card" aria-label={`${label}: ${value}`}>
      {content}
    </article>
  )
}

function CourseCard({ course }: { course: Course }) {
  const levels = courseLevels(course)
  const semesters = courseSemesters(course)
  return (
    <Link to={`/app/courses/${encodeURIComponent(course.code)}`} className="course-card">
      <div className="course-topline">
        <span>{course.code}</span>
        <small>{course.type ?? 'Course'}</small>
      </div>
      <h3>{course.title}</h3>
      <p>{course.description || 'Course details, outlines and quiz questions are available.'}</p>
      <div className="pill-row">
        {course.units ? <span>{course.units} units</span> : null}
        {levels.slice(0, 2).map((level, levelIndex) => (
          <span key={`${level}-${levelIndex}`}>{level} level</span>
        ))}
        {semesters.slice(0, 1).map((semester, semesterIndex) => (
          <span key={`${semester}-${semesterIndex}`}>{semester}</span>
        ))}
        <span>{course.question_count ?? 0} questions</span>
      </div>
    </Link>
  )
}


function courseSummaryTags(course: Partial<Course>) {
  const tags: string[] = []
  if (course.units) tags.push(`${course.units} units`)
  courseLevels(course as Course).slice(0, 1).forEach((level) => tags.push(`${level} level`))
  courseSemesters(course as Course).slice(0, 1).forEach((semester) => tags.push(semester))
  if (course.question_count) tags.push(`${course.question_count} questions`)
  return tags.slice(0, 3)
}

function CourseJourneyCard({ course, to }: { course: Pick<Course, 'code' | 'title'> & Partial<Pick<Course, 'units' | 'question_count'>>; to: string }) {
  const tags = courseSummaryTags(course)
  return (
    <Link className="course-journey-card" to={to}>
      <div className="course-journey-icon">
        <GraduationCap size={22} />
      </div>
      <div className="course-journey-copy">
        <span>{course.code}</span>
        <h3>{course.title}</h3>
        <div className="course-journey-tags">
          {tags.map((tag) => <small key={tag}>{tag}</small>)}
        </div>
      </div>
      <div className="course-journey-cta">
        Review <ChevronRight size={17} />
      </div>
    </Link>
  )
}

function CourseEmbarkCard({ course, questionCount }: { course: Course; questionCount: number }) {
  const tags = courseSummaryTags({ ...course, question_count: questionCount })
  return (
    <section className="course-embark-card">
      <div className="course-embark-icon">
        <GraduationCap size={30} />
      </div>
      <div>
        <p className="eyebrow">Next course</p>
        <h2>{course.title}</h2>
        <span>{course.code}</span>
      </div>
      <div className="course-embark-tags">
        {tags.map((tag) => <small key={tag}>{tag}</small>)}
      </div>
    </section>
  )
}

function PublicShell({ children }: { children: ReactNode }) {
  const firebaseUser = useFirebaseUser()
  if (firebaseUser === 'loading') {
    return <div className="page-stack narrow"><div className="loading-spinner" /></div>
  }
  if (firebaseUser) return <Navigate to="/app" replace />
  return <main className="public-shell">{children}</main>
}

function MobileLanding() {
  const [msgIdx, setMsgIdx] = useState(0)
  const messages = [
    "AI-powered quizzes that adapt to you.",
    "Flashcard review with spaced repetition.",
    "Track your streaks & daily progress.",
    "Master engineering concepts daily.",
  ]

  useEffect(() => {
    const timer = setInterval(() => {
      setMsgIdx((i) => (i + 1) % messages.length)
    }, 3500)
    return () => clearInterval(timer)
  }, [messages.length])

  return (
    <section className="mobile-landing">
      <div className="mobile-landing-orbs">
        <div className="orb orb-one" />
        <div className="orb orb-two" />
      </div>
      
      <div className="mobile-landing-top">
        <Logo />
        <div className="scrolling-message">
          <p key={msgIdx}>{messages[msgIdx]}</p>
        </div>
      </div>

      <div className="mobile-landing-middle">
         <img src="/brand/problem-solving.svg" alt="Engineering student illustration" className="mobile-hero-img" />
      </div>

      <div className="mobile-landing-bottom">
        <Link className="primary-button full" to="/register">
          Get Started
        </Link>
        <p className="mobile-auth-switch">
          Already have an account? <Link to="/login">Sign in</Link>
        </p>
      </div>
    </section>
  )
}

function LandingPage() {
  return (
    <PublicShell>
      <section className="landing-grid desktop-only">
        <div className="landing-copy">
          <Logo />
          <div className="hero-text">
            <span className="eyebrow">Built for engineering students</span>
            <h1>
              Engineer <span>smarter</span> on the web.
            </h1>
            <p>
              Courses, practice quizzes, schedules, flashcard review and progress analytics in one
              focused learning workspace.
            </p>
          </div>
          <div className="cta-row">
            <Link className="primary-button" to="/register">
              Get started free <ChevronRight size={18} />
            </Link>
            <Link className="ghost-button" to="/login">
              Sign in
            </Link>
          </div>
          <div className="feature-list">
            {featureHighlights.map((feature) => (
              <div key={feature}>
                <CheckCircle2 size={18} />
                <span>{feature}</span>
              </div>
            ))}
          </div>
        </div>
        <aside className="landing-visual">
          <div className="orb orb-one" />
          <div className="orb orb-two" />
          <div className="device-frame">
            <div className="device-header">
              <span />
              <span />
              <span />
            </div>
            <div className="hero-card live">
              <div>
                <Sparkles />
                <p>Live course bank</p>
              </div>
              <strong>426 courses</strong>
              <span>142K+ engineering questions</span>
            </div>
            <div className="hero-card floating top">
              <TimerReset />
              <span>Daily quiz streak</span>
            </div>
            <div className="hero-card floating bottom">
              <LineChart />
              <span>Performance hub</span>
            </div>
            <img src="/brand/problem-solving.svg" alt="Engineering student illustration" />
          </div>
        </aside>
      </section>
      <MobileLanding />
    </PublicShell>
  )
}

function LoginPage() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    setLoading(true)
    try {
      if (!hasFirebaseConfig) {
        setError('Authentication is not configured. Please contact support.')
        setLoading(false)
        return
      }
      const user = await loginWithEmail(email, password)
      const remoteProfile = await fetchUserProfile(user.uid).catch(() => null)
      if (remoteProfile) {
        saveProfile(remoteProfile)
      } else {
        const localProfile = getProfile()
        const fallbackProfile = localProfile?.departmentCode ? localProfile : {
          firstName: user.displayName?.split(' ')[0] || user.email?.split('@')[0] || 'User',
          lastName: user.displayName?.split(' ').slice(1).join(' ') || '',
          email: user.email || email,
          departmentCode: '',
          departmentName: '',
          selectedCourses: [],
        }
        if (fallbackProfile.departmentCode) {
          await saveUserProfile(user.uid, fallbackProfile).catch(() => {})
        }
        saveProfile(fallbackProfile)
      }
      navigate('/app')
    } catch (err: any) {
      const code = err?.code || ''
      if (code === 'auth/user-not-found' || code === 'auth/invalid-credential') {
        setError('No account found with these details. Check your email or sign up.')
      } else if (code === 'auth/wrong-password') {
        setError('Incorrect password. Try again or reset your password.')
      } else if (code === 'auth/invalid-email') {
        setError('Enter a valid email address.')
      } else if (code === 'auth/too-many-requests') {
        setError('Too many attempts. Try again later.')
      } else {
        setError(err?.message || 'Sign in failed. Try again.')
      }
    } finally {
      setLoading(false)
    }
  }

  async function handleGoogleSignIn() {
    setError('')
    setLoading(true)
    try {
      const user = await loginWithGoogle()
      const remoteProfile = await fetchUserProfile(user.uid).catch(() => null)
      const localProfile = getProfile()
      const fallbackProfile = localProfile?.departmentCode ? localProfile : profileFromGoogleAccount(user)
      if (!remoteProfile && fallbackProfile.departmentCode) {
        await saveUserProfile(user.uid, fallbackProfile).catch(() => {})
      }
      saveProfile(remoteProfile ?? fallbackProfile)
      navigate('/app')
    } catch (err: any) {
      if (err?.code !== 'auth/popup-closed-by-user') {
        setError(err?.message || 'Google sign in failed.')
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <PublicShell>
      <AuthCard
        title="Welcome back"
        subtitle="Sign in to continue to your engineering workspace."
      >
        <form onSubmit={submit} className="auth-form">
          <label>
            Email address
            <span>
              <Mail size={18} />
              <input value={email} onChange={(event) => setEmail(event.target.value)} placeholder="engineer@example.com" disabled={loading} aria-label="Email" />
            </span>
          </label>
          <label>
            Password
            <span>
              <Lock size={18} />
              <input
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder="Enter your password"
                type={showPassword ? 'text' : 'password'}
                disabled={loading}
              />
              <button
                type="button"
                className="password-toggle"
                onClick={() => setShowPassword((v) => !v)}
                tabIndex={-1}
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </span>
          </label>
          {error && <p className="form-error">{error}</p>}
          <button className="primary-button full" type="submit" disabled={loading}>
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
        <div className="auth-divider">
          <span>or</span>
        </div>
        <button className="google-button full" type="button" onClick={handleGoogleSignIn} disabled={loading}>
          <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
          Sign in with Google
        </button>
        <p className="auth-switch">
          New to Vens Hub? <Link to="/register">Create an account</Link>
        </p>
      </AuthCard>
    </PublicShell>
  )
}

function RegisterPage() {
  const navigate = useNavigate()
  const [step, setStep] = useState(0)
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [departmentCode, setDepartmentCode] = useState('')
  const [departmentName, setDepartmentName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  // Course search + pagination state
  const [courseList, setCourseList] = useState<Course[]>([])
  const [courseLoading, setCourseLoading] = useState(false)
  const [courseError, setCourseError] = useState('')
  const [courseTotal, setCourseTotal] = useState(0)
  const [courseHasMore, setCourseHasMore] = useState(false)
  const [courseNextCursor, setCourseNextCursor] = useState(0)
  const [courseSearch, setCourseSearch] = useState('')
  const [selectedCourses, setSelectedCourses] = useState<Array<{ code: string; title: string }>>([])

  const selectedDepartment = departments.find((department) => department.code === departmentCode)

  // 4 steps: Name → Department → Courses → Account
  const canContinue =
    (step === 0 && firstName.trim() && lastName.trim()) ||
    (step === 1 && departmentCode) ||
    (step === 2 && selectedCourses.length >= 3) ||
    (step === 3 && email.includes('@') && password.length >= 6 && password === confirmPassword)

  // Fetch courses with search + pagination
  const fetchCourses = useCallback(async (query: string, cursor: number, append: boolean) => {
    setCourseLoading(true)
    setCourseError('')
    try {
      const data = await api.departmentCourses(departmentName, query, 20, cursor)
      setCourseList((prev) => append ? [...prev, ...data.courses] : data.courses)
      setCourseTotal(data.total)
      setCourseHasMore(data.hasMore)
      setCourseNextCursor(data.nextCursor)
    } catch {
      setCourseError('Failed to load courses. Try again.')
    } finally {
      setCourseLoading(false)
    }
  }, [departmentName])

  // Debounced search
  useEffect(() => {
    if (step !== 2 || !departmentCode) return
    const timer = setTimeout(() => {
      fetchCourses(courseSearch, 0, false)
    }, 300)
    return () => clearTimeout(timer)
  }, [courseSearch, step, departmentCode, fetchCourses])

  // Initial load when entering step 2
  useEffect(() => {
    if (step === 2 && departmentName && courseList.length === 0) {
      fetchCourses('', 0, false)
    }
  }, [step, departmentName, courseList.length, fetchCourses])

  function handleDepartmentSelect(code: string, name: string) {
    setDepartmentCode(code)
    setDepartmentName(name)
    setSelectedCourses([])
    setCourseList([])
    setCourseSearch('')
    setStep(2)
  }

  function toggleCourse(course: Course) {
    setSelectedCourses((prev) => {
      const exists = prev.find((c) => c.code === course.code)
      if (exists) return prev.filter((c) => c.code !== course.code)
      if (prev.length >= 10) return prev
      return [...prev, { code: course.code, title: course.title }]
    })
  }

  async function next() {
    if (!canContinue) return
    if (step < 3) {
      setStep((value) => value + 1)
      return
    }
    // Step 3 — create Firebase account + save profile
    setError('')
    setLoading(true)
    try {
      if (!selectedDepartment) return
      if (!hasFirebaseConfig) {
        setError('Authentication is not configured. Please contact support.')
        setLoading(false)
        return
      }
      const profileData = {
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
        departmentCode: selectedDepartment.code,
        departmentName: selectedDepartment.name,
        selectedCourses,
      }

      const user = await registerWithEmail(email, password)

      await saveUserProfile(user.uid, profileData)

      // Save to localStorage (fast cache)
      saveProfile(profileData)
      navigate('/app')
    } catch (err: any) {
      const code = err?.code || ''
      if (code === 'auth/email-already-in-use') {
        setError('An account with this email already exists. Sign in instead.')
      } else if (code === 'auth/weak-password') {
        setError('Password is too weak. Use at least 6 characters.')
      } else if (code === 'auth/invalid-email') {
        setError('Enter a valid email address.')
      } else {
        setError(err?.message || 'Account creation failed. Try again.')
      }
    } finally {
      setLoading(false)
    }
  }

  async function handleGoogleSignUp() {
    setError('')
    setLoading(true)
    try {
      const user = await loginWithGoogle()
      if (!selectedDepartment) return
      const profileData = {
        firstName: user.displayName?.split(' ')[0] || firstName.trim() || 'User',
        lastName: user.displayName?.split(' ').slice(1).join(' ') || lastName.trim() || '',
        email: user.email || email.trim(),
        departmentCode: selectedDepartment.code,
        departmentName: selectedDepartment.name,
        selectedCourses,
      }
      await saveUserProfile(user.uid, profileData)
      saveProfile(profileData)
      navigate('/app')
    } catch (err: any) {
      if (err?.code !== 'auth/popup-closed-by-user') {
        setError(err?.message || 'Google sign up failed.')
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <PublicShell>
      <section className="signup-grid">
        <div className="mobile-progress-bar" role="progressbar" aria-valuenow={step + 1} aria-valuemax={4} aria-label={`Step ${step + 1} of 4`}>
          {step > 0 ? (
            <button className="back-btn" onClick={() => setStep((s) => Math.max(0, s - 1))} aria-label="Go back">
              <ArrowLeft size={20} />
            </button>
          ) : (
            <Link to="/login" className="back-btn" aria-label="Go to login">
              <ArrowLeft size={20} />
            </Link>
          )}
          <div className="progress-track">
            <div className="progress-fill" style={{ width: `${((step + 1) / 4) * 100}%` }} />
          </div>
        </div>
        <aside className="signup-progress">
          <Logo />
          <h1>Create Account</h1>
          <p>Follow the steps to set up your web workspace.</p>
          {['Your Name', 'Your Department', 'Courses', 'Account'].map((title, index) => (
            <div className={cx('step-row', step === index && 'active', step > index && 'done')} key={title} aria-current={step === index ? 'step' : undefined}>
              <span>{step > index ? <CheckCircle2 size={16} /> : index + 1}</span>
              <strong>{title}</strong>
            </div>
          ))}
          <Link to="/login" className="inline-link">
            Already have an account? Sign in
          </Link>
        </aside>
        <div className="signup-form-panel">
          {step === 0 && (
            <StepPanel icon={<User />} title="Hey! What should we call you?">
              <div className="two-col">
                <label>
                  First name
                  <input value={firstName} onChange={(event) => setFirstName(event.target.value)} aria-label="First name" />
                </label>
                <label>
                  Last name
                  <input value={lastName} onChange={(event) => setLastName(event.target.value)} aria-label="Last name" />
                </label>
              </div>
            </StepPanel>
          )}
          {step === 1 && (
            <StepPanel icon={<Building2 />} title="Which department are you in?">
              <div className="selection-grid departments">
                {departments.map((department) => (
                  <button
                    className={cx(departmentCode === department.code && 'selected')}
                    key={department.code}
                    onClick={() => handleDepartmentSelect(department.code, department.name)}
                    aria-pressed={departmentCode === department.code}
                    aria-label={department.name}
                  >
                    <Building2 size={18} /> {department.name}
                  </button>
                ))}
              </div>
            </StepPanel>
          )}
          {step === 2 && (
            <StepPanel icon={<BookOpen />} title="Pick at least 3 courses">
              <p className="step-hint">Select your courses for this semester. You can change them later.</p>
              <div className="course-search-row">
                <Search size={16} />
                <input
                  className="course-search-input"
                  value={courseSearch}
                  onChange={(event) => setCourseSearch(event.target.value)}
                  placeholder="Search courses by name..."
                />
              </div>
              {courseLoading && courseList.length === 0 ? (
                <div className="course-select-loading">
                  <span className="loader" />
                  <p>Loading courses...</p>
                </div>
              ) : courseError ? (
                <div className="course-select-loading">
                  <p className="form-error">{courseError}</p>
                  <button className="ghost-button" onClick={() => fetchCourses(courseSearch, 0, false)}>
                    Retry
                  </button>
                </div>
              ) : courseList.length === 0 ? (
                <EmptyState icon={<BookOpen />} title="No courses found" body="Try a different search or department." />
              ) : (
                <>
                  <p className="course-select-count">
                    Showing {courseList.length} of {courseTotal} courses
                  </p>
                  <div className="course-select-grid">
                    {courseList.map((course) => {
                      const isSelected = selectedCourses.some((c) => c.code === course.code)
                      return (
                        <button
                          className={cx('course-select-card', isSelected && 'selected')}
                          key={course.code}
                          onClick={() => toggleCourse(course)}
                          type="button"
                          aria-pressed={isSelected}
                          aria-label={`${course.title} (${course.code})`}
                        >
                          <div className="course-select-topline">
                            <span className="course-select-code">{course.code}</span>
                            {isSelected && <span className="course-select-check">✓</span>}
                          </div>
                          <h4>{course.title}</h4>
                          <div className="course-select-meta">
                            {course.units ? <span>{course.units} units</span> : null}
                            {courseLevels(course).slice(0, 1).map((lvl, i) => (
                              <span key={i}>{lvl} level</span>
                            ))}
                          </div>
                        </button>
                      )
                    })}
                  </div>
                  {courseHasMore && (
                    <button
                      className="course-load-more"
                      onClick={() => fetchCourses(courseSearch, courseNextCursor, true)}
                      disabled={courseLoading}
                    >
                      {courseLoading ? 'Loading...' : 'Show more courses'}
                    </button>
                  )}
                </>
              )}
              <p className={cx('course-select-count', selectedCourses.length > 0 && selectedCourses.length < 3 && 'course-count-warning')} style={{ marginTop: '0.75rem' }}>
                {selectedCourses.length} selected{selectedCourses.length < 3 ? ` (${3 - selectedCourses.length} more needed)` : selectedCourses.length >= 10 ? ' (max reached)' : ` of 10 max`}
              </p>
            </StepPanel>
          )}
          {step === 3 && (
            <StepPanel icon={<Lock />} title="Create your account">
              <label>
                Email address
                <input value={email} onChange={(event) => setEmail(event.target.value)} disabled={loading} aria-label="Email" />
              </label>
              <label>
                Create password
                <span className="password-field">
                  <input value={password} onChange={(event) => setPassword(event.target.value)} type={showPassword ? 'text' : 'password'} disabled={loading} aria-label="Create password" />
                  <button
                    type="button"
                    className="password-toggle"
                    onClick={() => setShowPassword((v) => !v)}
                    tabIndex={-1}
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </span>
              </label>
              <label>
                Confirm password
                <span className="password-field">
                  <input value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} type={showConfirmPassword ? 'text' : 'password'} disabled={loading} aria-label="Confirm password" />
                  <button
                    type="button"
                    className="password-toggle"
                    onClick={() => setShowConfirmPassword((v) => !v)}
                    tabIndex={-1}
                    aria-label={showConfirmPassword ? 'Hide password' : 'Show password'}
                  >
                    {showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </span>
              </label>
              {error && <p className="form-error">{error}</p>}
              <div className="auth-divider"><span>or</span></div>
              <button className="google-button full" type="button" onClick={handleGoogleSignUp} disabled={loading}>
                <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
                  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/>
                  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                </svg>
                Sign up with Google
              </button>
            </StepPanel>
          )}
          {error && <p className="form-error" style={{ marginTop: '0.75rem' }}>{error}</p>}
          <div className="signup-actions">
            <button className="ghost-button" disabled={step === 0 || loading} onClick={() => setStep((value) => Math.max(0, value - 1))}>
              Back
            </button>
            <button className="primary-button" disabled={!canContinue || loading} onClick={next}>
              {loading ? 'Creating account...' : step === 3 ? 'Create Account' : 'Continue'}
            </button>
          </div>
        </div>
      </section>
    </PublicShell>
  )
}

function StepPanel({ icon, title, children }: { icon: ReactNode; title: string; children: ReactNode }) {
  return (
    <div className="step-panel">
      <div className="speech-heading">
        <span>{icon}</span>
        <h2>{title}</h2>
      </div>
      <div className="step-fields">{children}</div>
    </div>
  )
}

function AuthCard({ title, subtitle, children }: { title: string; subtitle: string; children: ReactNode }) {
  return (
    <section className="auth-layout">
      <div className="auth-panel">
        <Link to="/" className="back-link">
          <ArrowLeft size={18} /> Back
        </Link>
        <Logo />
        <h1>{title}</h1>
        <p>{subtitle}</p>
        {children}
      </div>
      <aside className="auth-visual">
        <img src="/brand/mathematics.svg" alt="Mathematics illustration" />
        <div>
          <Sparkles />
          <strong>Everything in one workspace</strong>
          <span>Sign in, choose your courses, plan your week and keep your study momentum.</span>
        </div>
      </aside>
    </section>
  )
}

function demoProfile(email: string): Profile {
  return {
    firstName: 'Samuel',
    lastName: 'Engineer',
    email,
    departmentCode: 'ELE',
    departmentName: 'ELECTRICAL AND ELECTRONICS ENGINEERING',
    selectedCourses: [],
  }
}

function RequireAuth() {
  const firebaseUser = useFirebaseUser()
  const location = useLocation()

  if (firebaseUser === 'loading') {
    return <div className="page-stack narrow"><div className="loading-spinner" /></div>
  }
  // Firebase auth required — no local profile fallback
  if (!firebaseUser) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  return <Outlet />
}

const FLASHCARD_DB_SYNC_DELAY_MS = 30_000

function useFlashcardDatabaseSync(userId: string | null) {
  const [meta, setMeta] = useState<FlashcardSyncMeta>(() => readFlashcardSyncMeta())
  const [isSyncing, setIsSyncing] = useState(false)
  const hydratedUserRef = useRef<string | null>(null)

  useEffect(() => {
    const syncMeta = () => setMeta(readFlashcardSyncMeta())
    window.addEventListener('storage', syncMeta)
    window.addEventListener('vens-hub-storage', syncMeta)
    return () => {
      window.removeEventListener('storage', syncMeta)
      window.removeEventListener('vens-hub-storage', syncMeta)
    }
  }, [])

  useEffect(() => {
    if (!userId || hydratedUserRef.current === userId) return
    hydratedUserRef.current = userId
    let active = true

    getUserFlashcards(userId)
      .then((remote) => {
        if (!active) return
        const remoteAttempts = remote.attempts ?? []
        const remoteStates = remote.states ?? []
        const localAttempts = readFlashcardAttempts()
        const localStates = readFlashcardStates()

        if (remoteAttempts.length > 0 || remoteStates.length > 0) {
          writeFlashcardAttempts(mergeFlashcardAttempts(localAttempts, remoteAttempts), { markDirty: false })
          writeFlashcardStates(mergeFlashcardStates(localStates, remoteStates), { markDirty: false })
        }

        const remoteAttemptIds = new Set(remoteAttempts.map((attempt) => attempt.id))
        const remoteStateKeys = new Set(remoteStates.map((state) => state.questionKey))
        const hasLocalOnlyData =
          localAttempts.some((attempt) => !remoteAttemptIds.has(attempt.id)) ||
          localStates.some((state) => !remoteStateKeys.has(state.questionKey))

        if (hasLocalOnlyData && !readFlashcardSyncMeta().lastSyncedAt) {
          markFlashcardsDirty()
        } else if ((remoteAttempts.length > 0 || remoteStates.length > 0) && !hasLocalOnlyData) {
          markFlashcardsSynced({ attemptCount: remoteAttempts.length, stateCount: remoteStates.length })
        }
        setMeta(readFlashcardSyncMeta())
      })
      .catch(() => {
        if (active) setMeta(readFlashcardSyncMeta())
      })

    return () => {
      active = false
    }
  }, [userId])

  useEffect(() => {
    if (!userId || isSyncing || !navigator.onLine) return
    const attempts = readFlashcardAttempts()
    const states = readFlashcardStates()
    const hasLocalFlashcards = attempts.length > 0 || states.length > 0
    const needsInitialSync = hasLocalFlashcards && !meta.lastSyncedAt
    const needsSync = meta.dirty || needsInitialSync
    if (!hasLocalFlashcards || !needsSync) return

    const timer = window.setTimeout(() => {
      const latestMeta = readFlashcardSyncMeta()
      const latestAttempts = readFlashcardAttempts()
      const latestStates = readFlashcardStates()
      if (latestAttempts.length === 0 && latestStates.length === 0) return

      const syncDirtyAt = latestMeta.lastDirtyAt
      setIsSyncing(true)
      syncUserFlashcards(userId, {
        attempts: latestAttempts,
        states: latestStates,
        clientLastSyncedAt: latestMeta.lastSyncedAt,
      })
        .then((result) => {
          const currentMeta = readFlashcardSyncMeta()
          if (currentMeta.lastDirtyAt && currentMeta.lastDirtyAt !== syncDirtyAt) {
            markFlashcardsDirty(currentMeta.lastDirtyAt)
            return
          }
          markFlashcardsSynced({
            attemptCount: result.attempts,
            stateCount: result.states,
            syncedAt: result.syncedAt,
          })
        })
        .catch((error) => {
          markFlashcardsSyncFailed(error instanceof Error ? error.message : 'Flashcard database sync failed')
        })
        .finally(() => {
          setIsSyncing(false)
          setMeta(readFlashcardSyncMeta())
        })
    }, FLASHCARD_DB_SYNC_DELAY_MS)

    return () => window.clearTimeout(timer)
  }, [userId, meta.dirty, meta.pendingSince, meta.lastSyncedAt, isSyncing])

  return { meta, isSyncing }
}

function AppShell() {
  const profile = useProfile()
  const firebaseUser = useFirebaseUser()
  const userId = firebaseUser && firebaseUser !== 'loading' ? firebaseUser.uid : null
  const navigate = useNavigate()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  useFlashcardDatabaseSync(userId)

  useEffect(() => {
    if (!userId) return
    let active = true
    fetchUserProfile(userId)
      .then((remoteProfile) => {
        if (!active) return
        if (remoteProfile) {
          saveProfile(remoteProfile)
          return
        }
        const localProfile = getProfile()
        if (localProfile?.departmentCode) {
          saveUserProfile(userId, localProfile).catch(() => {})
        }
      })
      .catch(() => {})
    return () => {
      active = false
    }
  }, [userId])

  const navItems = [
    { to: '/app', label: 'Home', icon: <Home size={22} />, end: true },
    { to: '/app/schedule', label: 'Schedule', icon: <CalendarDays size={22} /> },
    { to: '/app/hub', label: 'Hub', icon: <Layers3 size={22} /> },
    { to: '/app/study', label: 'Flashcards', icon: <BookOpen size={22} /> },
    { to: '/app/courses', label: 'Courses', icon: <GraduationCap size={22} /> },
    { to: '/app/streaks', label: 'Streaks', icon: <Flame size={22} /> },
    { to: '/app/profile', label: 'Profile', icon: <CircleUserRound size={22} /> },
  ]

  function signOut() {
    signOutUser()
    saveProfile(null)
    navigate('/welcome')
  }

  return (
    <div className="app-shell">
      <button className="mobile-menu-button" onClick={() => setMobileMenuOpen(true)}>
        <Menu />
      </button>
      <aside className={cx('sidebar', mobileMenuOpen && 'open')}>
        <div className="sidebar-header">
          <button className="close-mobile" onClick={() => setMobileMenuOpen(false)}>
            <X size={20} />
          </button>
          <div className="sidebar-user">
            <div className="sidebar-avatar">
              {profile?.firstName || profile?.lastName
                ? `${(profile.firstName[0] ?? '').toUpperCase()}${(profile.lastName[0] ?? '').toUpperCase()}`
                : <User size={24} />}
            </div>
            <div className="sidebar-user-info">
              <strong>{profile?.firstName || 'Engineer'} {profile?.lastName || ''}</strong>
              {profile?.email && <span className="sidebar-email">{profile.email}</span>}
            </div>
          </div>
        </div>
        <Logo compact className="sidebar-logo-desktop" />
        <nav>
          {navItems.map((item) => (
            <NavLink
              className={({ isActive }) => cx('nav-item', isActive && 'active')}
              end={item.end}
              key={item.to}
              onClick={() => setMobileMenuOpen(false)}
              to={item.to}
            >
              {item.icon}
              <span>{item.label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          <button onClick={signOut}>
            <LogOut size={18} />
            <span>Sign out</span>
          </button>
        </div>
      </aside>
      {mobileMenuOpen && <button className="menu-backdrop" onClick={() => setMobileMenuOpen(false)} />}
      <section className="app-main">
        <Outlet />
      </section>
    </div>
  )
}

function AIAssistantPanel({ open, onClose, context, systemPrompt }: { open: boolean; onClose: () => void; context: string; systemPrompt?: string }) {
  const [messages, setMessages] = useState<AssistantMessage[]>([
    {
      id: 'welcome',
      role: 'assistant',
      text: "I'm your study guide. I can help you understand concepts, work through reasoning, and find hints — but I won't give you the answer directly. What do you need help with?",
    },
  ])
  const [draft, setDraft] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const scrollRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    if (open) scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight })
  }, [messages, open])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const question = draft.trim()
    if (!question || isLoading) return
    const userMessage: AssistantMessage = { id: crypto.randomUUID(), role: 'user', text: question }
    setMessages((items) => [...items, userMessage])
    setDraft('')
    setIsLoading(true)
    try {
      const updatedMessages = [...messages, userMessage]
      const answer = await askAssistant(updatedMessages, context, systemPrompt)
      setMessages((items) => [...items, { id: crypto.randomUUID(), role: 'assistant', text: answer }])
    } catch (error) {
      setMessages((items) => [
        ...items,
        {
          id: crypto.randomUUID(),
          role: 'assistant',
          text: error instanceof Error ? error.message : String(error),
          isError: true,
        },
      ])
    } finally {
      setIsLoading(false)
    }
  }

  if (!open) return null

  return (
    <div className="assistant-backdrop" role="dialog" aria-modal="true" aria-label="AI Assistant">
      <section className="assistant-panel">
        <header>
          <div>
            <span>
              <Bot size={22} />
            </span>
            <div>
              <p className="eyebrow">AI Assistant</p>
              <h2>Study Guide</h2>
            </div>
          </div>
          <div className="assistant-actions">
            <button onClick={() => setMessages([])} title="Clear chat" type="button"><RefreshCw size={18} /></button>
            <button onClick={onClose} title="Close" type="button"><X size={18} /></button>
          </div>
        </header>
        <div className="assistant-messages" ref={scrollRef}>
          {messages.map((message) => (
            <article className={cx('assistant-message', message.role, message.isError && 'error')} key={message.id}>
              <span>{message.role === 'assistant' ? <Bot size={16} /> : <User size={16} />}</span>
              <p><LatexText text={message.text} /></p>
            </article>
          ))}
          {isLoading && (
            <article className="assistant-message assistant">
              <span><Bot size={16} /></span>
              <p>Thinking...</p>
            </article>
          )}
        </div>
        <form className="assistant-input" onSubmit={submit}>
          <input
            aria-label="Ask the AI assistant"
            disabled={isLoading}
            onChange={(event) => setDraft(event.target.value)}
            placeholder="Ask for a hint or explanation..."
            value={draft}
          />
          <button className="primary-button" disabled={!draft.trim() || isLoading} type="submit"><Send size={18} /></button>
        </form>
      </section>
    </div>
  )
}

const EMPTY_COURSES: Array<{ code: string; title: string }> = []

function DashboardPage() {
  const profile = useProfile()
  const [attempts, setAttempts] = useState<QuizAttempt[]>(() => readJson<QuizAttempt[]>(ATTEMPTS_KEY, []))
  const selectedCourses = profile?.selectedCourses ?? EMPTY_COURSES
  const streakStats = useMemo(() => getStreakStats(attempts), [attempts])

  useEffect(() => {
    const sync = () => setAttempts(readJson<QuizAttempt[]>(ATTEMPTS_KEY, []))
    window.addEventListener('vens-hub-storage', sync)
    return () => window.removeEventListener('vens-hub-storage', sync)
  }, [])

  if (!profile) return <LoadingState />

  return (
    <div className="page-stack">

      {/* Welcome header */}
      <header className="page-header">
        <div>
          <p className="eyebrow">{profile.departmentName || 'Dashboard'}</p>
          <h1>Welcome, {profile.firstName ?? 'Engineer'}</h1>
        </div>
        <Link className="ghost-button" to="/app/courses">
          Browse
        </Link>
      </header>

      {/* Hero dashboard card — desktop only */}
      <section className="hero-dashboard">
        <div>
          <h2>Your learning workspace</h2>
          <p>
            {selectedCourses.length > 0
              ? `You're studying ${selectedCourses.length} course${selectedCourses.length > 1 ? 's' : ''}. Keep it up.`
              : 'Start by picking courses from the catalog.'}
          </p>
        </div>
        <BrandMark className="hub-hero-mark" />
      </section>

      {/* Analytics */}
      <div>
        <div className="metrics-grid dashboard-metrics">
          <MetricCard icon={<GraduationCap />} label="My courses" value={selectedCourses.length} hint="Selected during setup" />
          <MetricCard icon={<BookOpen />} label="Questions answered" value={attempts.reduce((sum, a) => sum + a.total, 0)} hint="Across all quizzes" />
          <MetricCard icon={<Flame />} label="Study streak" value={streakStats.currentStreak} hint={streakStats.completedToday ? 'Completed today' : 'Take a quiz today'} to="/app/streaks" />
          <MetricCard icon={<Trophy />} label="Quiz attempts" value={attempts.length} hint="Tracked in Hub" />
        </div>
      </div>

      <section className="streak-dashboard-card">
        <div>
          <p className="eyebrow">Daily streak</p>
          <h2>{streakStats.currentStreak} day{streakStats.currentStreak === 1 ? '' : 's'} strong</h2>
          <p>{streakStats.completedToday ? "You have already protected today's streak." : "Jump into a quick quiz to keep your streak alive."}</p>
        </div>
        <Link className="primary-button" to="/app/streaks">
          Open streaks <ChevronRight size={18} />
        </Link>
      </section>

      {/* Course workspace */}
      <section className="section-card">
        <div className="section-title">
          <div>
            <p className="eyebrow">Your courses</p>
            <h2>Course workspace</h2>
          </div>
          <Link to="/app/courses">View all</Link>
        </div>
        {selectedCourses.length === 0 ? (
          <EmptyState icon={<BookOpen />} title="No courses selected yet" body="Complete the registration flow to pick your courses, or browse the full catalog." />
        ) : (
          <div className="course-journey-grid">
            {selectedCourses.slice(0, 6).map((course) => (
              <CourseJourneyCard course={course} key={course.code} to={`/app/courses/${encodeURIComponent(course.code)}`} />
            ))}
          </div>
        )}
        {selectedCourses.length === 0 && (
          <Link className="primary-button" to="/app/courses" style={{ marginTop: '1rem', alignSelf: 'flex-start' }}>
            Browse courses <ChevronRight size={18} />
          </Link>
        )}
      </section>
    </div>
  )
}

function CoursesPage() {
  const [query, setQuery] = useState('')
  const [debouncedQuery, setDebouncedQuery] = useState('')
  const [department, setDepartment] = useState('')
  const [level, setLevel] = useState('')

  const [courses, setCourses] = useState<Course[]>([])
  const [total, setTotal] = useState(0)
  const [cursor, setCursor] = useState(0)
  const [hasMore, setHasMore] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  // Debounce search input
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedQuery(query)
    }, 300)
    return () => clearTimeout(handler)
  }, [query])

  // Reset and fetch page 1 on search or filter change
  useEffect(() => {
    let active = true
    setLoading(true)
    setError('')
    setCursor(0)

    api.courses({ q: debouncedQuery, department, level, limit: 20, cursor: 0 })
      .then((data) => {
        if (!active) return
        setCourses(data.courses ?? [])
        setTotal(data.total ?? 0)
        setHasMore(data.hasMore ?? false)
        setCursor(data.nextCursor ?? 0)
        setLoading(false)
      })
      .catch((err: Error) => {
        if (!active) return
        setError(err.message)
        setLoading(false)
      })

    return () => {
      active = false
    }
  }, [debouncedQuery, department, level])

  // Load more pages
  const loadMore = () => {
    if (loading || !hasMore) return
    setLoading(true)
    api.courses({ q: debouncedQuery, department, level, limit: 20, cursor })
      .then((data) => {
        setCourses((prev) => [...prev, ...(data.courses ?? [])])
        setTotal(data.total ?? 0)
        setHasMore(data.hasMore ?? false)
        setCursor(data.nextCursor ?? 0)
        setLoading(false)
      })
      .catch((err: Error) => {
        setError(err.message)
        setLoading(false)
      })
  }

  return (
    <div className="page-stack">
      <PageHeader title="Engineering courses" />
      <section className="filter-bar">
        <label className="search-box">
          <Search size={18} />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search by code, title or topic" />
        </label>
        <select value={department} onChange={(event) => setDepartment(event.target.value)}>
          <option value="">All departments</option>
          {departments.map((item) => (
            <option key={item.code} value={item.code}>
              {item.name}
            </option>
          ))}
        </select>
        <select value={level} onChange={(event) => setLevel(event.target.value)}>
          <option value="">All levels</option>
          {['100', '200', '300', '400', '500'].map((item) => (
            <option key={item} value={item}>
              {item} Level
            </option>
          ))}
        </select>
      </section>
      
      {error && <ErrorState message={error} />}

      {courses.length === 0 && !loading && !error && (
        <EmptyState icon={<GraduationCap />} title="No courses found" body="Try refining your search terms or filters." />
      )}

      {courses.length > 0 && (
        <>
          <p className="result-count">Showing {courses.length} of {total} courses</p>
          <div className="course-grid">
            {courses.map((course) => (
              <CourseCard course={course} key={course.code} />
            ))}
          </div>
        </>
      )}

      {loading && <LoadingState label="Loading courses..." />}

      {hasMore && !loading && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: '2rem' }}>
          <button className="primary-button" onClick={loadMore}>
            Load More
          </button>
        </div>
      )}
    </div>
  )
}

function CourseDetailPage() {
  const params = useParams()
  const code = decodeURIComponent(params.code ?? '')
  const courseState = useAsync(`course:${code}`, () => api.course(code))
  const questionState = useAsync(`questions:${code}`, () => api.questions(code))

  const [expandedTopics, setExpandedTopics] = useState<Record<string, boolean>>({})
  const questions = useMemo(() => questionState.data?.questions ?? [], [questionState.data?.questions])
  const topicsList = useMemo(() => {
    const map: Record<string, Set<string>> = {}
    questions.forEach((q) => {
      const topic = q.topic_name || 'General'
      const subtopic = q.subtopic_name || 'General'
      if (!map[topic]) {
        map[topic] = new Set()
      }
      map[topic].add(subtopic)
    })
    return Object.entries(map).map(([topicName, subtopicsSet]) => ({
      name: topicName,
      subtopics: Array.from(subtopicsSet).filter(Boolean).sort(),
    })).sort((a, b) => a.name.localeCompare(b.name))
  }, [questions])

  if (courseState.loading) return <LoadingState label="Loading course details..." />
  if (courseState.error) return <ErrorState message={courseState.error} />

  const course = courseState.data?.course
  if (!course) return <ErrorState message="Course was not returned by the API." />
  const outline = courseOutline(course)

  const toggleTopic = (topicName: string) => {
    setExpandedTopics((prev) => ({
      ...prev,
      [topicName]: !prev[topicName],
    }))
  }

  return (
    <div className="page-stack">
      <Link className="back-link" to="/app/courses">
        <ArrowLeft size={18} /> Back to courses
      </Link>
      <section className="course-detail-hero">
        <div>
          <p className="eyebrow">{course.department ?? course.department_code}</p>
          <h1>{course.code}: {course.title}</h1>
          <p>{course.description || 'Course information is available in Vens Hub.'}</p>
          <div className="pill-row">
            {course.units ? <span>{course.units} units</span> : null}
            {courseLevels(course).map((item, itemIndex) => <span key={`${item}-${itemIndex}`}>{item} Level</span>)}
            {courseSemesters(course).map((item, itemIndex) => <span key={`${item}-${itemIndex}`}>{item}</span>)}
            <span>{questionState.data?.count ?? 0} questions</span>
          </div>
        </div>
      </section>
      <section className="detail-grid">
        <article className="section-card">
          <div className="section-title">
            <h2>Course outline</h2>
          </div>
          {outline.length ? (
            <ul className="check-list">
              {outline.slice(0, 12).map((item, itemIndex) => <li key={`${item}-${itemIndex}`}>{item}</li>)}
            </ul>
          ) : (
            <EmptyState icon={<ClipboardList />} title="No outline listed" body="The course still has quiz questions and metadata available." />
          )}
        </article>
        <article className="section-card">
          <div className="section-title">
            <h2>Question topics</h2>
          </div>
          {questionState.loading && <LoadingState label="Loading questions..." />}
          {questionState.error && <ErrorState message={questionState.error} />}
          {!questionState.loading && !questionState.error && (
            <div className="topic-dropdown-list">
              {topicsList.length === 0 ? (
                <EmptyState icon={<BrainCircuit />} title="No topics available" body="This course does not have topics added yet." />
              ) : (
                topicsList.map((topic) => {
                  const isExpanded = !!expandedTopics[topic.name]
                  return (
                    <div key={topic.name} className="topic-dropdown-item">
                      <div className="topic-dropdown-header">
                        <button
                          type="button"
                          className="chevron-btn"
                          onClick={() => toggleTopic(topic.name)}
                          aria-label={isExpanded ? 'Collapse' : 'Expand'}
                        >
                          <span className={clsx("chevron-icon", isExpanded && "expanded")}>
                            {isExpanded ? <ChevronDown size={18} /> : <ChevronRight size={18} />}
                          </span>
                        </button>
                        <Link
                          to={`/app/courses/${encodeURIComponent(code)}/quiz?topic=${encodeURIComponent(topic.name)}`}
                          className="topic-link"
                        >
                          <strong>{topic.name}</strong>
                          <span className="subtopic-count-badge">
                            {topic.subtopics.length} subtopic{topic.subtopics.length !== 1 ? 's' : ''}
                          </span>
                        </Link>
                      </div>
                      {isExpanded && (
                        <ul className="subtopic-dropdown-content">
                          {topic.subtopics.map((subtopic) => (
                            <li key={subtopic}>{subtopic}</li>
                          ))}
                        </ul>
                      )}
                    </div>
                  )
                })
              )}
            </div>
          )}
        </article>
      </section>
    </div>
  )
}

function QuizSetupPage() {
  const params = useParams()
  const navigate = useNavigate()
  const location = useLocation()
  const code = decodeURIComponent(params.code ?? '')
  const topicParam = new URLSearchParams(location.search).get('topic')
  const courseState = useAsync(`setup-course:${code}`, () => api.course(code))
  const questionState = useAsync(`setup-questions:${code}`, () => api.questions(code))

  const [questionType, setQuestionType] = useState<'calculation' | 'theory'>('calculation')
  const [questionCount, setQuestionCount] = useState(5)

  const allQuestions = questionState.data?.questions ?? []
  const topicQuestions = topicParam
    ? allQuestions.filter((q) => q.topic_name === topicParam)
    : allQuestions
  const calculationCount = topicQuestions.filter((q) => q.question_type === 'calculation').length
  const theoryCount = topicQuestions.filter((q) => q.question_type === 'theory').length
  const maxAvailable = questionType === 'calculation' ? calculationCount : theoryCount
  const clampedCount = Math.min(questionCount, Math.max(maxAvailable, 2))

  function startQuiz() {
    const params = new URLSearchParams()
    params.set('type', questionType)
    params.set('count', String(clampedCount))
    if (topicParam) params.set('topic', topicParam)
    navigate(`/app/quiz/${encodeURIComponent(code)}?${params.toString()}`)
  }

  if (courseState.loading) return <LoadingState label="Loading course..." />
  if (courseState.error) return <ErrorState message={courseState.error} />

  const course = courseState.data?.course
  if (!course) return <ErrorState message="Course not found." />

  return (
    <div className="page-stack narrow quiz-setup">
      <Link className="back-link" to={topicParam ? `/app/courses/${encodeURIComponent(code)}` : '/app/courses'}>
        <ArrowLeft size={18} /> {topicParam ? 'Back to course' : 'Back to courses'}
      </Link>
      <CourseEmbarkCard course={course} questionCount={topicQuestions.length} />
      <section className="quiz-setup-card">
        <h3>Quiz setup</h3>
        <div className="quiz-type-selector">
          <button
            className={cx('quiz-type-btn', questionType === 'calculation' && 'selected')}
            onClick={() => setQuestionType('calculation')}
            type="button"
          >
            <Calculator size={32} />
            <strong>Calculation</strong>
            <span>{calculationCount} questions</span>
          </button>
          <button
            className={cx('quiz-type-btn', questionType === 'theory' && 'selected')}
            onClick={() => setQuestionType('theory')}
            type="button"
          >
            <BookOpen size={32} />
            <strong>Theory</strong>
            <span>{theoryCount} questions</span>
          </button>
        </div>
        <div className="quiz-count-section">
          <label>
            <p>Number of questions</p>
            <div className="quiz-count-slider">
              <input
                type="range"
                min={2}
                max={Math.min(maxAvailable || 2, 10)}
                value={clampedCount}
                onChange={(e) => setQuestionCount(Number(e.target.value))}
              />
              <span className="quiz-count-value">{clampedCount}</span>
            </div>
          </label>
        </div>
        <button
          className="quiz-start-btn"
          disabled={maxAvailable === 0}
          onClick={startQuiz}
        >
          Start quiz <PlayCircle size={20} />
        </button>
      </section>
    </div>
  )
}

function QuizPage() {
  const params = useParams()
  const location = useLocation()
  const code = decodeURIComponent(params.code ?? '')
  const searchParams = new URLSearchParams(location.search)
  const typeParam = searchParams.get('type')
  const countParam = searchParams.get('count')
  const topicParam = searchParams.get('topic')
  const questionState = useAsync(`quiz-questions:${code}`, () => api.questions(code))
  const courseState = useAsync(`quiz-course:${code}`, () => api.course(code))

  const questions = useMemo(() => {
    const all = questionState.data?.questions ?? []
    let filtered = all.filter((question) => question.question?.trim())
    if (topicParam) {
      filtered = filtered.filter((q) => q.topic_name === topicParam)
    }
    if (typeParam) {
      filtered = filtered.filter((q) => q.question_type === typeParam)
    }
    const limit = countParam ? Math.max(1, parseInt(countParam, 10) || 10) : 10
    return filtered.slice(0, limit)
  }, [questionState.data?.questions, typeParam, countParam, topicParam])

  if (questionState.loading) return <LoadingState label="Preparing quiz..." />
  if (questionState.error) return <ErrorState message={questionState.error} />
  if (questions.length === 0) {
    return <EmptyState icon={<BrainCircuit />} title="No questions found" body="This course does not have questions added yet." />
  }

  const courseTitle = courseState.data?.course.title ?? code

  return <MultipleChoiceQuizMode code={code} courseTitle={courseTitle} questions={questions} />
}

function QuizCompletion({
  score,
  total,
  mode,
  onRetake,
  topicBreakdown,
  adaptiveSynced,
}: {
  score: number
  total: number
  mode: string
  onRetake: () => void
  topicBreakdown?: Record<string, { correct: number; total: number }>
  adaptiveSynced?: boolean
}) {
  const percentage = total > 0 ? Math.round((score / total) * 100) : 0
  const topics = topicBreakdown ? Object.entries(topicBreakdown).sort(([, a], [, b]) => b.correct / b.total - a.correct / a.total) : []

  return (
    <div className="page-stack narrow">
      <section className="completion-card">
        <Trophy size={48} />
        <p className="eyebrow">{mode} complete</p>
        <h1>{score} / {total}</h1>
        <p className="completion-score-hint">{percentage}% correct</p>

        {adaptiveSynced && (
          <div className="completion-adaptive-status">
            <CheckCircle2 size={16} />
            <span>Progress saved to your mastery profile</span>
          </div>
        )}

        {topics.length > 0 && (
          <div className="completion-topic-breakdown">
            <h3>Topic breakdown</h3>
            {topics.map(([topic, data]) => {
              const topicPct = data.total > 0 ? Math.round((data.correct / data.total) * 100) : 0
              return (
                <div className="completion-topic-row" key={topic}>
                  <span className="completion-topic-name">{topic}</span>
                  <div className="completion-topic-bar">
                    <span className={cx('mastery-bar-fill', topicPct >= 75 ? 'mastery-high' : topicPct >= 50 ? 'mastery-mid' : 'mastery-low')} style={{ width: `${topicPct}%` }} />
                  </div>
                  <span className="completion-topic-score">{data.correct}/{data.total}</span>
                </div>
              )
            })}
          </div>
        )}

        <div className="cta-row center">
          <button className="ghost-button" onClick={onRetake}>Retake quiz</button>
          <Link className="primary-button" to="/app/hub">View Hub</Link>
        </div>
      </section>
    </div>
  )
}

function MultipleChoiceQuizMode({ code, courseTitle, questions }: { code: string; courseTitle: string; questions: Question[] }) {
  const firebaseUser = useFirebaseUser()
  const mcqQuestions = questions.filter((question) => questionOptions(question).length >= 2)
  const [index, setIndex] = useState(0)
  const [selected, setSelected] = useState<number | null>(null)
  const [answers, setAnswers] = useState<Array<{ selected: number; correct: number; topicName: string; courseCode: string }>>([])
  const [showResult, setShowResult] = useState(false)
  const [showExplanation, setShowExplanation] = useState(false)
  const [finished, setFinished] = useState(false)
  const [adaptiveSynced, setAdaptiveSynced] = useState(false)
  const [adaptiveResult, setAdaptiveResult] = useState<{ synced: boolean; count: number } | null>(null)
  const [assistantOpen, setAssistantOpen] = useState(false)
  const current = mcqQuestions[index]
  const score = answers.filter((answer) => answer.selected === answer.correct).length
  const lastAnswer = answers[answers.length - 1]

  const isCorrect = lastAnswer ? lastAnswer.selected === lastAnswer.correct : false

  function submitAnswer() {
    if (selected === null || !current) return
    const next = [...answers, {
      selected,
      correct: answerIndex(current),
      topicName: current.topic_name || 'General',
      courseCode: code,
    }]
    setAnswers(next)
    setShowResult(true)
    // Record flashcard attempt
    const opts = questionOptions(current)
    const correctIdx = answerIndex(current)
    const correctText = current.correct_answer_text || opts[correctIdx] || current.correct_answer || ''
    const selectedText = opts[selected] || ''
    const fc = buildFlashcardAttempt({
      courseCode: code,
      courseTitle,
      topicName: current.topic_name || 'General',
      mode: 'multiple-choice',
      questionId: current.id,
      questionText: current.question,
      options: opts,
      selectedAnswerText: selectedText,
      selectedAnswerIndex: selected,
      correctAnswerText: correctText,
      correctAnswerIndex: correctIdx,
      isCorrect: selected === correctIdx,
      explanation: current.explanation,
      solutionSteps: parseJsonList(current.solution_steps),
      ragSources: current.rag_sources,
    })
    recordFlashcardAttempt(fc)
  }

  function nextQuestion() {
    setSelected(null)
    setShowResult(false)
    setShowExplanation(false)
    if (answers.length >= mcqQuestions.length) {
      setFinished(true)
      saveQuizAttempt({
        courseCode: code,
        courseTitle,
        mode: 'multiple-choice',
        score: answers.filter((answer) => answer.selected === answer.correct).length,
        total: mcqQuestions.length,
      })
      // Submit batch to adaptive engine (fire-and-forget)
      const userId = (firebaseUser as import('firebase/auth').User | null)?.uid
      if (userId && !adaptiveSynced) {
        setAdaptiveSynced(true)
        const batchResults = answers.map((a) => ({
          topicName: a.topicName,
          courseCode: a.courseCode,
          isCorrect: a.selected === a.correct,
        }))
        submitBatchResults(userId, batchResults)
          .then((result) => setAdaptiveResult({ synced: true, count: result.count }))
          .catch(() => setAdaptiveResult({ synced: false, count: 0 }))
      } else {
        setAdaptiveResult({ synced: false, count: 0 })
      }
    } else {
      setIndex((value) => value + 1)
    }
  }

  if (mcqQuestions.length === 0) {
    return <EmptyState icon={<BrainCircuit />} title="No multiple choice questions found" body="This course has no loaded questions in the API yet." />
  }

  if (finished) {
    // Compute topic breakdown for display
    const topicBreakdown: Record<string, { correct: number; total: number }> = {}
    answers.forEach((a) => {
      if (!topicBreakdown[a.topicName]) topicBreakdown[a.topicName] = { correct: 0, total: 0 }
      topicBreakdown[a.topicName].total++
      if (a.selected === a.correct) topicBreakdown[a.topicName].correct++
    })
    return (
      <QuizCompletion
        mode="Multiple choice"
        onRetake={() => { setAnswers([]); setIndex(0); setShowResult(false); setShowExplanation(false); setFinished(false); setAdaptiveResult(null) }}
        score={score}
        total={mcqQuestions.length}
        topicBreakdown={topicBreakdown}
        adaptiveSynced={adaptiveResult?.synced ?? false}
      />
    )
  }

  const options = questionOptions(current)
  const progress = ((index) / mcqQuestions.length) * 100
  const solutionSteps = parseJsonList(current.solution_steps)
  
  const quizSystemPrompt = `You are a study guide for engineering students. Your role is to help students UNDERSTAND concepts — not to test them, not to quiz them, and never to reveal answers.

## Your Core Rule
You are explaining a concept. The student is trying to learn. That is the entire job.

## How to Explain
Structure every explanation in this order:
1. **Start with the intuition** — one sentence that captures the "why" in plain language
2. **Build the theory** — definitions, formulas, derivations as needed
3. **Use an example** — concrete, numerical if possible, tied to the question context
4. **Connect to the real world** — where this is used in engineering practice
5. **Wrap up** — one sentence summarizing the key takeaway

Adjust depth based on what the student asks. If they ask a narrow question, give a focused answer. If they ask "explain this topic," give the full treatment.

## Handling Student Questions

**Concept questions** ("What is Newton-Raphson?"): Explain the concept directly. Define it, give the formula, show how it works.

**Confusion** ("I don't understand"): Start from the basics. Assume they know nothing about this specific concept. Use an analogy or real-world example.

**Vague queries** ("help", "explain"): Explain the current question's core concept. Walk through why the correct approach works, without naming which option it is.

**"Is my answer right?"**: Never confirm or deny. Say something like: "Let me explain the concept so you can evaluate your reasoning." Then explain.

**Off-topic** ("What time is it?", "Tell me a joke"): One sentence redirect: "I can help with [subject] concepts — what would you like to understand?" Then move on.

**App/meta questions** ("How do I use this?"): Brief, helpful answer about the feature, then redirect to the subject.

## Formatting: LaTeX Notation
Use LaTeX notation for all mathematical expressions:
- Inline math: wrap in single dollar signs — \$V = IR\$, \$P = VI\cos\phi\$
- Display math (equations on their own line): wrap in double dollar signs — \$\$I = \frac{V}{R}\$\$
- Use standard LaTeX commands: \\frac{}{}, \\sqrt{}, \\sum, \\int, \\alpha, \\beta, \\theta, \\omega, \\Delta, \\nabla, \\partial, \\cdot, \\times, \\leq, \\geq, \\neq, \\approx, \\infty
- Do NOT use LaTeX for plain text, headings, or bullet points — only for math
- Do NOT wrap entire sentences in dollar signs — only wrap the mathematical expression itself

## The Rules

1. NEVER reveal, confirm, or hint at which answer option (A/B/C/D) is correct. Never say "the answer is X." Never say "the correct approach is..." followed by exactly one option's method. Never use emphasis, emoji, or formatting to highlight the correct option.

2. NEVER end with a quiz question ("Can you solve this?", "What do you think?"). You MAY end with a gentle guiding question that helps them think ("What happens to the current when impedance increases?") — but only when it serves understanding, not when it replaces an explanation.

3. NEVER confirm or deny the student's selected answer. If they say "I picked B," respond with: "Let me explain the concept so you can evaluate your reasoning."

4. NEVER analyze options one by one ("Option A says..., Option B says...") because this reveals structure that hints at the correct answer. Instead, explain the concept directly.

5. Stay within the subject area. If asked about unrelated topics, redirect once to the current subject. Do not engage with off-topic conversation beyond one redirect.

6. Be direct and engineering-focused. Use SI units. Reference relevant standards (IEEE, IEC) when appropriate. Avoid American cultural references. Be warm but not patronizing.`

  const quizContext = current ? [
    `Course: ${courseTitle} (${code})`,
    `Topic: ${current.topic_name ?? 'General'}`,
    `Difficulty: ${current.difficulty ?? 'Unknown'}`,
    `Question: ${current.question}`,
    `Options: ${questionOptions(current).map((opt, i) => `${String.fromCharCode(65 + i)}. ${opt}`).join(' | ')}`,
    current.explanation ? `Explanation: ${current.explanation}` : '',
    parseJsonList(current.solution_steps).length > 0 ? `Solution steps: ${parseJsonList(current.solution_steps).join(' → ')}` : '',
  ].filter(Boolean).join('\n') : `Course: ${courseTitle} (${code})`

  return (
    <div className="page-stack narrow">
      <PageHeader eyebrow={`${code} multiple choice`} title={`Question ${index + 1} of ${mcqQuestions.length}`}>
        <span className="score-chip">Score {score}</span>
      </PageHeader>
      <section className="quiz-card">
        <div className="quiz-progress-bar">
          <div className="quiz-progress-fill" style={{ width: `${progress}%` }} />
        </div>
        <div className="quiz-meta">
          <span>{current.topic_name ?? 'General'}</span>
          <span>{current.difficulty ?? 'Mixed difficulty'}</span>
        </div>
        <h2><LatexText text={current.question} /></h2>
        <div className="answers-list">
          {options.map((option, optionIndex) => {
            const isSelected = selected === optionIndex
            const isCorrectAnswer = optionIndex === answerIndex(current)
            let buttonClass = ''
            
            if (showResult) {
              if (isCorrectAnswer) buttonClass = 'correct'
              else if (isSelected && !isCorrectAnswer) buttonClass = 'wrong'
            } else if (isSelected) {
              buttonClass = 'selected'
            }
            
            return (
              <button
                className={buttonClass}
                key={`${option}-${optionIndex}`}
                onClick={() => !showResult && setSelected(optionIndex)}
                disabled={showResult}
              >
                <span>{String.fromCharCode(65 + optionIndex)}</span>
                <p><LatexText text={option} /></p>
                {showResult && isCorrectAnswer && <CheckCircle2 size={20} className="answer-icon correct-icon" />}
                {showResult && isSelected && !isCorrectAnswer && <AlertCircle size={20} className="answer-icon wrong-icon" />}
              </button>
            )
          })}
        </div>
        
        {!showResult ? (
          <button className="primary-button full" disabled={selected === null} onClick={submitAnswer}>
            Check answer
          </button>
        ) : (
          <div className="quiz-feedback-section">
            <div className={cx('quiz-result-badge', isCorrect ? 'correct' : 'wrong')}>
              {isCorrect ? <CheckCircle2 size={20} /> : <AlertCircle size={20} />}
              <span>{isCorrect ? 'Correct!' : 'Incorrect'}</span>
            </div>
            
            {!showExplanation ? (
              <button className="ghost-button full" onClick={() => setShowExplanation(true)}>
                {current.explanation || solutionSteps.length > 0 ? 'View explanation' : 'Continue'}
              </button>
            ) : (
              <div className="quiz-explanation-panel">
                <div className="explanation-answer">
                  <strong>Correct answer:</strong> {String.fromCharCode(65 + answerIndex(current))}. <LatexText text={current.correct_answer_text || options[answerIndex(current)]} />
                </div>
                {current.explanation && (
                  <div className="explanation-text">
                    <strong>Explanation:</strong>
                    <p><LatexText text={current.explanation} /></p>
                  </div>
                )}
                {solutionSteps.length > 0 && (
                  <div className="explanation-steps">
                    <strong>Solution steps:</strong>
                    <ol>
                      {solutionSteps.map((step, i) => (
                        <li key={i}><LatexText text={step} /></li>
                      ))}
                    </ol>
                  </div>
                )}
              </div>
            )}
            
            <button className="primary-button full" onClick={nextQuestion}>
              {answers.length >= mcqQuestions.length ? 'Finish quiz' : 'Next question'}
            </button>
          </div>
        )}
      </section>

      {/* Quiz AI Assistant — only visible on the quiz page */}
      <AIAssistantPanel
        context={quizContext}
        systemPrompt={quizSystemPrompt}
        onClose={() => setAssistantOpen(false)}
        open={assistantOpen}
      />
      <button className="ai-fab" onClick={() => setAssistantOpen(true)} type="button">
        <MessageCircle size={22} />
        <span>Study Guide</span>
      </button>
    </div>
  )
}

function TheoryQuizMode({ code, courseTitle, questions }: { code: string; courseTitle: string; questions: Question[] }) {
  const [index, setIndex] = useState(0)
  const [answer, setAnswer] = useState('')
  const [feedback, setFeedback] = useState<{ isCorrect: boolean; score: number; expected: string } | null>(null)
  const [results, setResults] = useState<boolean[]>([])
  const current = questions[index]
  const finished = index === questions.length
  const score = results.filter(Boolean).length

  function submitTheoryAnswer() {
    if (!answer.trim() || !current) return
    const result = scoreTheoryAnswer(answer, current)
    setFeedback(result)
    const next = [...results, result.isCorrect]
    setResults(next)
    // Record flashcard attempt for theory
    const correctText = result.expected || current.correct_answer_text || ''
    const fcTheory = buildFlashcardAttempt({
      courseCode: code,
      courseTitle,
      topicName: current.topic_name || 'General',
      mode: 'theory',
      questionId: current.id,
      questionText: current.question,
      options: [],
      selectedAnswerText: answer,
      correctAnswerText: correctText,
      isCorrect: result.isCorrect,
      score: result.score,
      explanation: current.explanation,
      solutionSteps: parseJsonList(current.solution_steps),
      ragSources: current.rag_sources,
    })
    recordFlashcardAttempt(fcTheory)
    if (next.length === questions.length) {
      saveQuizAttempt({ courseCode: code, courseTitle, mode: 'theory', score: next.filter(Boolean).length, total: questions.length })
    }
  }

  function nextQuestion() {
    setAnswer('')
    setFeedback(null)
    setIndex((value) => value + 1)
  }

  if (finished) {
    return <QuizCompletion mode="Theory" onRetake={() => { setResults([]); setIndex(0); setFeedback(null); setAnswer('') }} score={score} total={questions.length} />
  }

  return (
    <div className="page-stack narrow">
      <PageHeader eyebrow={`${code} theory`} title={`Theory question ${index + 1} of ${questions.length}`}>
        <span className="score-chip">Score {score}</span>
      </PageHeader>
      <section className="quiz-card theory-card">
        <div className="quiz-meta">
          <span>{current.topic_name ?? 'General'}</span>
          <span>{current.difficulty ?? 'Mixed difficulty'}</span>
        </div>
        <h2>{displayText(current.question)}</h2>
        <label>
          Your answer
          <textarea
            disabled={feedback !== null}
            onChange={(event) => setAnswer(event.target.value)}
            placeholder="Explain your reasoning, formulas and final answer..."
            value={answer}
          />
        </label>
        {feedback && (
          <div className={cx('feedback-card', feedback.isCorrect ? 'correct' : 'wrong')}>
            <strong>{feedback.isCorrect ? 'Good answer' : 'Needs review'}</strong>
            <p>Expected answer: {displayText(feedback.expected || 'See explanation below.')}</p>
            {current.explanation && <p>{displayText(current.explanation)}</p>}
          </div>
        )}
        {feedback ? (
          <button className="primary-button full" onClick={nextQuestion} disabled={index === questions.length - 1 && finished}>
            {index === questions.length - 1 ? 'Finish theory quiz' : 'Next question'}
          </button>
        ) : (
          <button className="primary-button full" disabled={!answer.trim()} onClick={submitTheoryAnswer}>
            Evaluate answer
          </button>
        )}
      </section>
    </div>
  )
}

function GapFillQuizMode({ code, courseTitle, questions }: { code: string; courseTitle: string; questions: Question[] }) {
  const [index, setIndex] = useState(0)
  const [selected, setSelected] = useState('')
  const [feedback, setFeedback] = useState<boolean | null>(null)
  const [results, setResults] = useState<boolean[]>([])
  const current = questions[index]
  const gap = makeGapPrompt(current)
  const finished = index === questions.length
  const score = results.filter(Boolean).length

  function submitGapAnswer() {
    if (!selected) return
    const isCorrect = normalizeText(selected) === normalizeText(gap.correct)
    setFeedback(isCorrect)
    const next = [...results, isCorrect]
    setResults(next)
    // Record flashcard attempt for gap-fill
    const fcGap = buildFlashcardAttempt({
      courseCode: code,
      courseTitle,
      topicName: current.topic_name || 'General',
      mode: 'gap-fill',
      questionId: current.id,
      questionText: current.question,
      options: gap.choices,
      selectedAnswerText: selected,
      correctAnswerText: gap.correct,
      isCorrect,
      explanation: current.explanation,
      solutionSteps: parseJsonList(current.solution_steps),
      ragSources: current.rag_sources,
    })
    recordFlashcardAttempt(fcGap)
    if (next.length === questions.length) {
      saveQuizAttempt({ courseCode: code, courseTitle, mode: 'gap-fill', score: next.filter(Boolean).length, total: questions.length })
    }
  }

  function nextQuestion() {
    setSelected('')
    setFeedback(null)
    setIndex((value) => value + 1)
  }

  if (finished) {
    return <QuizCompletion mode="Gap-fill" onRetake={() => { setResults([]); setIndex(0); setFeedback(null); setSelected('') }} score={score} total={questions.length} />
  }

  return (
    <div className="page-stack narrow">
      <PageHeader eyebrow={`${code} gap-fill`} title={`Gap ${index + 1} of ${questions.length}`}>
        <span className="score-chip">Score {score}</span>
      </PageHeader>
      <section className="quiz-card">
        <div className="quiz-meta">
          <span>{current.topic_name ?? 'General'}</span>
          <span>{current.difficulty ?? 'Mixed difficulty'}</span>
        </div>
        <h2>{displayText(gap.statement)}</h2>
        <div className="answers-list">
          {gap.choices.map((choice, choiceIndex) => (
            <button
              className={cx(selected === choice && 'selected')}
              disabled={feedback !== null}
              key={`${choice}-${choiceIndex}`}
              onClick={() => setSelected(choice)}
            >
              <span>{String.fromCharCode(65 + choiceIndex)}</span>
              <p>{displayText(choice)}</p>
            </button>
          ))}
        </div>
        {feedback !== null && (
          <div className={cx('feedback-card', feedback ? 'correct' : 'wrong')}>
            <strong>{feedback ? 'Correct' : 'Incorrect'}</strong>
            <p>Correct answer: {displayText(gap.correct)}</p>
            {current.explanation && <p>{displayText(current.explanation)}</p>}
          </div>
        )}
        {feedback === null ? (
          <button className="primary-button full" disabled={!selected} onClick={submitGapAnswer}>Check answer</button>
        ) : (
          <button className="primary-button full" onClick={nextQuestion}>{index === questions.length - 1 ? 'Finish gap-fill quiz' : 'Next gap'}</button>
        )}
      </section>
    </div>
  )
}


/* ─── Schedule helpers ────────────────────────────────────────────────────── */

const SLOT_PX = 96          // pixels per 2-hr slot
const SCHEDULE_START = 7     // 07:00
const SCHEDULE_END = 22     // 22:00

const TIME_SLOTS: string[] = []
for (let h = SCHEDULE_START; h < SCHEDULE_END; h += 2) {
  TIME_SLOTS.push(`${String(h).padStart(2, '0')}:00`)
}

function timeToMinutes(t: string) {
  const [h, m] = t.split(':').map(Number)
  return h * 60 + m
}

function eventTop(start: string) {
  return ((timeToMinutes(start) - SCHEDULE_START * 60) / 120) * SLOT_PX
}

function eventHeight(start: string, end: string) {
  return Math.max(((timeToMinutes(end) - timeToMinutes(start)) / 120) * SLOT_PX, SLOT_PX)
}

const TYPE_TONE: Record<string, number> = {
  'Study block': 0,
  'Lecture': 1,
  'Quiz': 2,
  'Deadline': 3,
  'Group meeting': 0,
}

function typeTone(type?: string) {
  return (TYPE_TONE[type ?? ''] ?? 0)
}

function SchedulePage() {
  const profile = useProfile()
  const defaultCourse = profile?.selectedCourses?.[0]?.code ?? ''
  const createEmptyForm = (date = todayIso()) => ({
    title: '',
    course: defaultCourse,
    date,
    start: '09:00',
    end: '10:00',
    venue: '',
    type: 'Study block',
    priority: 'Medium',
    notes: '',
    participants: '',
    reminder: '15 minutes before',
  })
  const [events, setEvents] = useStoredList<EventItem>(EVENTS_KEY, [])
  const [form, setForm] = useState(createEmptyForm)
  const [month, setMonth] = useState<Date>(new Date())
  const [editingEventId, setEditingEventId] = useState<string | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [viewMode, setViewMode] = useState<'day' | 'week' | 'month'>(() => window.matchMedia('(max-width: 760px)').matches ? 'day' : 'week')
  const selectedDate = new Date(`${form.date}T00:00:00`)
  const weekStart = new Date(selectedDate)
  weekStart.setDate(selectedDate.getDate() - selectedDate.getDay() + 1)
  const weekDays = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(weekStart)
    date.setDate(weekStart.getDate() + index)
    return date
  })
  const todaysEvents = events.filter((event) => event.date === form.date).sort((a, b) => a.start.localeCompare(b.start))
  const weekEvents = weekDays.flatMap((day) => events.filter((event) => event.date === dateToIso(day)))
  const eventsByDate = useMemo(() => events.reduce<Record<string, EventItem[]>>((dates, item) => {
    dates[item.date] = [...(dates[item.date] ?? []), item]
    return dates
  }, {}), [events])
  const selectedDateLabel = format(selectedDate, 'EEEE, MMMM d')
  const isEndBeforeStart = form.end <= form.start
  const canSaveEvent = form.title.trim().length > 0 && !isEndBeforeStart
  const firstName = profile?.firstName ?? 'Engineer'

  function selectDate(date: Date) {
    setForm((value) => ({ ...value, date: dateToIso(date) }))
  }

  function navigateWeek(direction: -1 | 1) {
    setForm((value) => {
      const date = new Date(`${value.date}T00:00:00`)
      date.setDate(date.getDate() + direction * 7)
      return { ...value, date: dateToIso(date) }
    })
  }

  function openAddModal(date = form.date) {
    setEditingEventId(null)
    setForm(createEmptyForm(date))
    setIsModalOpen(true)
  }

  function openEditModal(item: EventItem) {
    setEditingEventId(item.id)
    setForm({
      title: item.title,
      course: item.course ?? '',
      date: item.date,
      start: item.start,
      end: item.end,
      venue: item.venue ?? '',
      type: item.type ?? 'Study block',
      priority: item.priority ?? 'Medium',
      notes: item.notes ?? '',
      participants: item.participants ?? '',
      reminder: item.reminder ?? '15 minutes before',
    })
    setIsModalOpen(true)
  }

  function closeEventModal() {
    setIsModalOpen(false)
    setEditingEventId(null)
    setForm((value) => createEmptyForm(value.date))
  }

  function saveEvent(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!canSaveEvent) return

    const nextEvent = {
      ...form,
      id: editingEventId ?? crypto.randomUUID(),
      title: form.title.trim(),
      course: form.course.trim(),
      venue: form.venue.trim(),
      notes: form.notes.trim(),
      participants: form.participants.trim(),
    }

    setEvents(editingEventId ? events.map((item) => (item.id === editingEventId ? nextEvent : item)) : [nextEvent, ...events])
    closeEventModal()
  }

  function removeEvent(id: string) {
    setEvents(events.filter((event) => event.id !== id))
    if (editingEventId === id) closeEventModal()
  }

  const modifiers = {
    today: (date: Date) => isToday(date),
    selected: (date: Date) => isSameDay(date, selectedDate),
    'has-events': (date: Date) => (eventsByDate[dateToIso(date)]?.length ?? 0) > 0,
  }
  const eventVariants: Variants = {
    hidden: { opacity: 0, y: 12, scale: 0.97 },
    visible: (i: number) => ({ opacity: 1, y: 0, scale: 1, transition: { delay: i * 0.045, duration: 0.28, ease: 'easeOut' } }),
    exit: { opacity: 0, x: -20, transition: { duration: 0.18, ease: 'easeOut' } },
  }

  return (
    <div className="page-stack schedule-page">
      <PageHeader title={`Stay up to date, ${firstName}`}>
        <div className="schedule-header-actions">
          <button className="primary-button" onClick={() => openAddModal()} type="button"><Plus size={18} /> Add event</button>
          <button className="ghost-button icon-only" onClick={() => selectDate(new Date())} type="button" aria-label="Jump to today"><RefreshCw size={18} /></button>
        </div>
      </PageHeader>

      <section className="schedule-board section-card">
        <div className="schedule-toolbar">
          <div className="schedule-nav-row">
            <button className="ghost-button icon-only" onClick={() => navigateWeek(-1)} type="button" aria-label="Previous week"><ChevronLeft size={18} /></button>
            <button className="schedule-range" type="button" onClick={() => selectDate(new Date())}>{format(weekDays[0], 'MMM d')} - {format(weekDays[6], 'd, yyyy')}</button>
            <button className="ghost-button icon-only" onClick={() => navigateWeek(1)} type="button" aria-label="Next week"><ChevronRight size={18} /></button>
          </div>
          <div className="schedule-view-tabs" role="tablist" aria-label="Schedule view">
            {(['day', 'week'] as const).map((mode) => <button key={mode} className={cx(viewMode === mode && 'active')} onClick={() => setViewMode(mode)} type="button">{mode}</button>)}
          </div>
        </div>
        <div className="week-strip">
          {weekDays.map((day) => <button key={dateToIso(day)} className={cx('week-day-card', isSameDay(day, selectedDate) && 'selected', isToday(day) && 'today')} onClick={() => selectDate(day)} type="button"><span>{format(day, 'EEE')}</span><strong>{format(day, 'dd/MM')}</strong></button>)}
        </div>
        <div className="schedule-week-scroll">
          <div className={cx('schedule-week-grid', viewMode === 'day' && 'day-view')}>
            <div className="time-rail">{TIME_SLOTS.map((t) => <span key={t}>{t}</span>)}</div>
            {(viewMode === 'day' ? weekDays.filter((d) => isSameDay(d, selectedDate)) : weekDays).map((day) => {
              const iso = dateToIso(day)
              const dayEvents = (eventsByDate[iso] ?? []).sort((a, b) => a.start.localeCompare(b.start))
              return (
                <div className="schedule-day-column" key={iso}>
                  {dayEvents.length === 0 ? (
                    <div className="schedule-day-empty">
                      <CalendarDays size={20} />
                      <span>No events</span>
                    </div>
                  ) : (
                    <AnimatePresence mode="popLayout">
                      {dayEvents.map((item, i) => (
                        <motion.article
                          className={cx('schedule-event-card', `tone-${typeTone(item.type)}`)}
                          key={item.id}
                          style={{ position: 'absolute', top: eventTop(item.start), height: eventHeight(item.start, item.end) }}
                          custom={i}
                          variants={eventVariants}
                          initial="hidden"
                          animate="visible"
                          exit="exit"
                          layout
                        >
                          <div className="event-card-top">
                            <span className="event-icon"><CalendarDays size={14} /></span>
                            <button className="event-edit-icon" aria-label={`Edit ${item.title}`} onClick={() => openEditModal(item)} type="button"><Pencil size={14} /></button>
                          </div>
                          <strong>{item.title}</strong>
                          {item.venue && <small>{item.venue}</small>}
                          <div className="event-card-meta">
                            <span><Clock3 size={12} /> {item.start} - {item.end}</span>
                            <button aria-label={`Delete ${item.title}`} onClick={() => removeEvent(item.id)} type="button"><X size={13} /></button>
                          </div>
                        </motion.article>
                      ))}
                    </AnimatePresence>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      </section>

      <section className="schedule-lower-grid">
        <motion.div className="section-card calendar-card" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.35, ease: 'easeOut' }}><DayPicker mode="single" selected={selectedDate} onDayClick={(date: Date) => { if (date) selectDate(date) }} month={month} onMonthChange={setMonth} showOutsideDays modifiers={modifiers} classNames={{ root: 'rdp-root', months: 'rdp-months', month_caption: 'rdp-month-caption', nav: 'rdp-nav', button_previous: 'rdp-nav-btn', button_next: 'rdp-nav-btn', month_grid: 'rdp-month-grid', weekdays: 'rdp-weekdays', weekday: 'rdp-weekday', day: 'rdp-day', day_button: 'rdp-day-btn', selected: 'rdp-selected', today: 'rdp-today', outside: 'rdp-outside' }} modifiersClassNames={{ 'has-events': 'rdp-has-events' }} /></motion.div>
        <motion.section className="section-card agenda-card" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.35, delay: 0.08, ease: 'easeOut' }}><div className="section-title"><div><h2>{selectedDateLabel}</h2><p>{weekEvents.length} event{weekEvents.length === 1 ? '' : 's'} planned this week</p></div><span className="score-chip">{todaysEvents.length} today</span></div>{todaysEvents.length === 0 ? <EmptyState icon={<CalendarDays />} title="No saved events for this date" body="Use Add event to plan lectures, study blocks, reminders, venues and participants." /> : <div className="timeline-list"><AnimatePresence mode="popLayout">{todaysEvents.map((item, i) => <motion.article key={item.id} custom={i} variants={eventVariants} initial="hidden" animate="visible" exit="exit" layout><time>{item.start} - {item.end}</time><div><strong>{item.title}</strong><p>{item.course || item.type || 'Personal event'} {item.venue ? <><MapPin size={14} /> {item.venue}</> : ''}</p></div><div className="timeline-actions"><motion.button aria-label={`Edit ${item.title}`} onClick={() => openEditModal(item)} type="button" whileTap={{ scale: 0.9 }} transition={{ duration: 0.1 }}><Pencil size={16} /></motion.button><motion.button aria-label={`Delete ${item.title}`} onClick={() => removeEvent(item.id)} type="button" whileTap={{ scale: 0.9 }} transition={{ duration: 0.1 }}><X size={16} /></motion.button></div></motion.article>)}</AnimatePresence></div>}</motion.section>
      </section>

      <AnimatePresence>{isModalOpen && <motion.div className="schedule-modal-backdrop" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}><motion.form className="schedule-modal section-card" onSubmit={saveEvent} initial={{ opacity: 0, y: 24, scale: 0.96 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 20, scale: 0.96 }} transition={{ duration: 0.25, ease: 'easeOut' }}><div className="modal-head"><div><p className="eyebrow">{editingEventId ? 'Edit schedule item' : 'New schedule item'}</p><h2>{editingEventId ? 'Edit event' : 'Add event menu'}</h2></div><button className="ghost-button icon-only" type="button" onClick={closeEventModal} aria-label="Close event form"><X size={18} /></button></div><label>Event title<input value={form.title} onChange={(event) => setForm({ ...form, title: event.target.value })} placeholder="Power systems revision" required autoFocus /></label><div className="two-col"><label>Course or label<input value={form.course} onChange={(event) => setForm({ ...form, course: event.target.value })} placeholder="EEE 401" /></label><label>Venue<input value={form.venue} onChange={(event) => setForm({ ...form, venue: event.target.value })} placeholder="Engineering block, Room 312" /></label></div><div className="three-col schedule-time-fields"><label>Date<input value={form.date} onChange={(event) => setForm({ ...form, date: event.target.value })} type="date" /></label><label>Start<input value={form.start} onChange={(event) => setForm({ ...form, start: event.target.value })} type="time" /></label><label>End<input value={form.end} onChange={(event) => setForm({ ...form, end: event.target.value })} type="time" /></label></div><div className="three-col"><label>Type<select value={form.type} onChange={(event) => setForm({ ...form, type: event.target.value })}><option>Study block</option><option>Lecture</option><option>Quiz</option><option>Deadline</option><option>Group meeting</option></select></label><label>Priority<select value={form.priority} onChange={(event) => setForm({ ...form, priority: event.target.value })}><option>Low</option><option>Medium</option><option>High</option></select></label><label>Reminder<select value={form.reminder} onChange={(event) => setForm({ ...form, reminder: event.target.value })}><option>None</option><option>15 minutes before</option><option>1 hour before</option><option>1 day before</option></select></label></div><label>Participants<input value={form.participants} onChange={(event) => setForm({ ...form, participants: event.target.value })} placeholder="TY, AB, NR or teammates" /></label><label>Notes<textarea value={form.notes} onChange={(event) => setForm({ ...form, notes: event.target.value })} placeholder="Add agenda, preparation links or what to bring." rows={3} /></label>{isEndBeforeStart && <p className="form-error">End time must be later than the start time.</p>}<div className="modal-actions">{editingEventId && <button className="ghost-button danger-action" onClick={() => removeEvent(editingEventId)} type="button">Delete event</button>}<button className="primary-button" disabled={!canSaveEvent} type="submit"><Plus size={18} /> {editingEventId ? 'Save changes' : 'Save event'}</button></div></motion.form></motion.div>}</AnimatePresence>
    </div>
  )
}

function FlashcardCardUI({
  card,
  index,
  now,
  onRate,
}: {
  card: FlashcardCard
  index: number
  now: string
  onRate: (rating: ReviewRating) => void
}) {
  const [isFlipped, setIsFlipped] = useState(false)
  const [showExplanationPopup, setShowExplanationPopup] = useState(false)
  const [aiExplanation, setAiExplanation] = useState('')
  const [aiLoading, setAiLoading] = useState(false)
  const [aiError, setAiError] = useState('')
  const [rated, setRated] = useState(false)

  const { latestAttempt: a, state, retention } = card
  const dueLabel = getDueLabel(state, now)
  const strengthLabel = getStrengthLabel(retention, state)
  const retentionPct = Math.round(retention * 100)

  const hasExplanation = !!(a.explanation || a.solutionSteps.length > 0)

  async function handleAskAI() {
    if (aiLoading || aiExplanation) return
    setAiLoading(true)
    setAiError('')
    try {
      const prompt = `You are helping a Vens Hub student review a flashcard.
Course: ${a.courseCode} - ${a.courseTitle}
Topic: ${a.topicName}
Question: ${a.questionText}
Student answer: ${a.selectedAnswerText}
Correct answer: ${a.correctAnswerText}
The student originally got this ${a.isCorrect ? 'correct' : 'incorrect'}.
Explain the concept clearly and briefly, then point out the key reasoning step.`
      const answer = await askAssistant([{ id: crypto.randomUUID(), role: 'user', text: prompt }], `Flashcard review for ${a.courseCode}`)
      setAiExplanation(answer)
    } catch {
      setAiError('Could not get AI explanation. Try again later.')
    } finally {
      setAiLoading(false)
    }
  }

  function handleRate(rating: ReviewRating) {
    setRated(true)
    onRate(rating)
  }

  function handleFlip() {
    if (!rated) setIsFlipped((f) => !f)
  }

  return (
    <>
      <article
        className={`flashcard-card${isFlipped ? ' flipped' : ''}`}
        data-card-index={index}
        onClick={handleFlip}
      >
        <div className="flashcard-card-inner">
          {/* === FRONT === */}
          <div className="flashcard-face flashcard-face-front">
            {index === 0 && !rated && (
              <div className="flashcard-tap-hint">
                Tap to reveal answer
              </div>
            )}
            <div className="flashcard-card-header">
              <div className="flashcard-meta">
                <span className="flashcard-course">{a.courseCode}</span>
                <span className="flashcard-topic">{a.topicName}</span>
              </div>
              <div className="flashcard-badges">
                <span className={cx('flashcard-result-badge', a.isCorrect ? 'correct' : 'wrong')}>
                  {a.isCorrect ? <CheckCircle2 size={14} /> : <AlertCircle size={14} />}
                  {a.isCorrect ? 'Correct' : 'Incorrect'}
                </span>
                <span className={cx('flashcard-strength-badge', strengthLabel.toLowerCase())}>
                  {strengthLabel}
                </span>
              </div>
            </div>
            <div className="flashcard-question">
              <h3><LatexText text={a.questionText} /></h3>
            </div>
            {!rated && (
              <div className="flashcard-front-footer">
                <div className="flashcard-due-info">
                  <Clock3 size={14} />
                  <span>{dueLabel}</span>
                  <span className="flashcard-retention">Retention: {retentionPct}%</span>
                </div>
                <div className="flashcard-flip-indicator">
                  <RotateCcw size={16} />
                  <span>Tap to flip</span>
                </div>
              </div>
            )}
          </div>

          {/* === BACK === */}
          <div className="flashcard-face flashcard-face-back" onClick={(e) => e.stopPropagation()}>
            <div className="flashcard-card-header">
              <div className="flashcard-meta">
                <span className="flashcard-course">{a.courseCode}</span>
                <span className="flashcard-topic">{a.topicName}</span>
              </div>
              <div className="flashcard-badges">
                <span className={cx('flashcard-result-badge', a.isCorrect ? 'correct' : 'wrong')}>
                  {a.isCorrect ? <CheckCircle2 size={14} /> : <AlertCircle size={14} />}
                  {a.isCorrect ? 'Correct' : 'Incorrect'}
                </span>
              </div>
            </div>

            <div className="flashcard-answers">
              <div className="flashcard-answer-row student">
                <strong>Your answer:</strong>
                <span><LatexText text={a.selectedAnswerText || '(no answer)'} /></span>
              </div>
              <div className="flashcard-answer-row correct">
                <strong>Correct answer:</strong>
                <span><LatexText text={a.correctAnswerText || '(unavailable)'} /></span>
              </div>
            </div>

            <div className="flashcard-due-info">
              <Clock3 size={14} />
              <span>{dueLabel}</span>
              <span className="flashcard-retention">Retention: {retentionPct}%</span>
              <span className="flashcard-date">Answered {new Date(a.answeredAt).toLocaleDateString()}</span>
            </div>

            {/* Explanation button — opens popup */}
            {hasExplanation && (
              <button className="ghost-button full flashcard-explain-popup-btn" onClick={() => setShowExplanationPopup(true)}>
                <BookOpen size={16} />
                Show explanation
              </button>
            )}

            {/* AI explanation */}
            <button
              className="ghost-button full flashcard-ai-btn"
              onClick={handleAskAI}
              disabled={aiLoading}
            >
              <Sparkles size={16} />
              {aiLoading ? 'Getting AI explanation...' : aiExplanation ? 'Ask AI again' : 'Ask AI to explain'}
            </button>

            {aiExplanation && (
              <div className="flashcard-ai-response">
                <div className="flashcard-ai-header">
                  <Bot size={16} />
                  <strong>AI Explanation</strong>
                </div>
                <p>{aiExplanation}</p>
              </div>
            )}

            {aiError && (
              <div className="flashcard-ai-response error">
                <AlertCircle size={14} />
                <p>{aiError}</p>
              </div>
            )}

            {/* Review rating buttons */}
            <div className="flashcard-rating-actions">
              {rated ? (
                <div className="flashcard-rated-msg">
                  <CheckCircle2 size={16} />
                  <span>Reviewed! Scroll for next card.</span>
                </div>
              ) : (
                <>
                  <span className="flashcard-rate-label">How well did you remember?</span>
                  <div className="flashcard-rate-buttons">
                    <button className="rate-btn again" onClick={() => handleRate('again')}>
                      <RotateCcw size={14} />
                      Again
                    </button>
                    <button className="rate-btn hard" onClick={() => handleRate('hard')}>
                      Hard
                    </button>
                    <button className="rate-btn good" onClick={() => handleRate('good')}>
                      Good
                    </button>
                    <button className="rate-btn easy" onClick={() => handleRate('easy')}>
                      <Sparkles size={14} />
                      Easy
                    </button>
                  </div>
                </>
              )}
            </div>

            {/* Flip back button */}
            {!rated && (
              <button className="ghost-button full flashcard-flip-back-btn" onClick={handleFlip}>
                <RotateCcw size={16} />
                Flip back to question
              </button>
            )}
          </div>
        </div>
      </article>

      {/* === EXPLANATION POPUP OVERLAY === */}
      {showExplanationPopup && (
        <div className="flashcard-popup-overlay" onClick={() => setShowExplanationPopup(false)}>
          <div className="flashcard-popup" onClick={(e) => e.stopPropagation()}>
            <div className="flashcard-popup-header">
              <div className="flashcard-popup-title">
                <BookOpen size={18} />
                <strong>Explanation</strong>
              </div>
              <button className="ghost-button icon-only" onClick={() => setShowExplanationPopup(false)} aria-label="Close explanation">
                <X size={18} />
              </button>
            </div>
            <div className="flashcard-popup-body">
              {a.explanation && (
                <div className="explanation-text">
                  <p><LatexText text={a.explanation} /></p>
                </div>
              )}
              {a.solutionSteps.length > 0 && (
                <div className="explanation-steps">
                  <strong>Solution steps:</strong>
                  <ol>
                    {a.solutionSteps.map((step, i) => (
                      <li key={i}><LatexText text={step} /></li>
                    ))}
                  </ol>
                </div>
              )}
              {!a.explanation && a.solutionSteps.length === 0 && (
                <p className="explanation-fallback">No detailed explanation is available for this question.</p>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  )
}

function FlashcardsPage() {
  const [refreshKey, setRefreshKey] = useState(0)
  const [currentIndex, setCurrentIndex] = useState(0)
  const [syncMeta, setSyncMeta] = useState<FlashcardSyncMeta>(() => readFlashcardSyncMeta())
  const feedRef = useRef<HTMLDivElement | null>(null)

  // Reactive sync on localStorage changes
  useEffect(() => {
    const sync = () => {
      setRefreshKey((k) => k + 1)
      setSyncMeta(readFlashcardSyncMeta())
    }
    window.addEventListener('storage', sync)
    window.addEventListener('vens-hub-storage', sync)
    return () => {
      window.removeEventListener('storage', sync)
      window.removeEventListener('vens-hub-storage', sync)
    }
  }, [])

  const now = new Date().toISOString()
  const attempts = readFlashcardAttempts()
  const states = readFlashcardStates()
  const deck = buildReviewDeck(attempts, states, now)
  const stats = getDeckStats(deck)
  void refreshKey // used only to trigger re-render
  const syncStatusText = syncMeta.lastError
    ? 'Database sync failed. We will retry in the background.'
    : syncMeta.dirty
      ? 'Saved locally. Database sync is queued after a short delay.'
      : syncMeta.lastSyncedAt
        ? `Synced to database ${new Date(syncMeta.lastSyncedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`
        : 'Saved locally. Database sync starts after your first review.'

  function handleRate(card: FlashcardCard, rating: ReviewRating) {
    updateFlashcardReview(card.state.questionKey, rating)
    setRefreshKey((k) => k + 1)
  }

  // Scroll snap observer
  useEffect(() => {
    const feed = feedRef.current
    if (!feed) return
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            const idx = Number((entry.target as HTMLElement).dataset.cardIndex)
            if (!isNaN(idx)) setCurrentIndex(idx)
          }
        }
      },
      { root: feed, threshold: 0.6 },
    )
    const cards = feed.querySelectorAll('.flashcard-card')
    cards.forEach((c) => observer.observe(c))
    return () => observer.disconnect()
  }, [deck.length])

  if (deck.length === 0) {
    return (
      <div className="page-stack">
        <PageHeader title="Flashcards" />
        <EmptyState
          icon={<BrainCircuit />}
          title="No flashcards yet"
          body="Flashcards appear after you take quizzes. Each question you answer is saved for spaced review."
        />
        <Link className="primary-button" to="/app/courses">Browse courses & start a quiz</Link>
      </div>
    )
  }

  return (
    <div className="page-stack">
      <PageHeader title="Flashcards">
        <span className="score-chip">{stats.dueNow} due</span>
      </PageHeader>

      <div className="flashcards-stats-row">
        <div className="flashcard-stat">
          <span className="flashcard-stat-value due">{stats.dueNow}</span>
          <span className="flashcard-stat-label">Due now</span>
        </div>
        <div className="flashcard-stat">
          <span className="flashcard-stat-value weak">{stats.weak}</span>
          <span className="flashcard-stat-label">Weak</span>
        </div>
        <div className="flashcard-stat">
          <span className="flashcard-stat-value strong">{stats.strong}</span>
          <span className="flashcard-stat-label">Strong</span>
        </div>
        <div className="flashcard-stat">
          <span className="flashcard-stat-value mastered">{stats.mastered}</span>
          <span className="flashcard-stat-label">Mastered</span>
        </div>
      </div>

      <div className={cx('flashcard-sync-status', syncMeta.dirty && 'queued', syncMeta.lastError && 'error')}>
        {syncMeta.lastError ? <AlertCircle size={16} /> : syncMeta.dirty ? <Clock3 size={16} /> : <CheckCircle2 size={16} />}
        <span>{syncStatusText}</span>
      </div>

      <div className="flashcard-progress-info">
        <span>{currentIndex + 1} of {deck.length}</span>
        <span className="flashcard-scroll-hint">
          <ChevronDown size={16} /> Scroll to review cards
        </span>
      </div>

      <div className="flashcard-feed" ref={feedRef}>
        {deck.map((card, i) => (
          <FlashcardCardUI
            key={card.state.questionKey}
            card={card}
            index={i}
            now={now}
            onRate={(rating) => handleRate(card, rating)}
          />
        ))}
      </div>
    </div>
  )
}

function HubPage() {
  const firebaseUser = useFirebaseUser()
  const userId = (firebaseUser as import('firebase/auth').User | null)?.uid
  const [stats, setStats] = useState<Record<string, CourseStats>>({})
  const [mastery, setMastery] = useState<MasteryRecord[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  // Local attempts from localStorage (always available)
  const localAttempts = readJson<QuizAttempt[]>(ATTEMPTS_KEY, [])
  const courseTitleMap: Record<string, string> = {}
  localAttempts.forEach((a) => { courseTitleMap[a.courseCode] = a.courseTitle })

  useEffect(() => {
    if (!userId) {
      setLoading(false)
      return
    }
    let active = true
    setLoading(true)
    Promise.all([
      getUserStats(userId),
      getUserMastery(userId),
    ]).then(([s, m]) => {
      if (!active) return
      setStats(s.courses ?? {})
      setMastery(m.topics ?? [])
      setLoading(false)
    }).catch(() => {
      if (!active) return
      setError('Failed to load progress data')
      setLoading(false)
    })
    return () => { active = false }
  }, [userId])

  // Aggregate local quiz data by course
  const localCourseStats: Record<string, { attempts: number; correct: number; total: number; lastAttempt: string }> = {}
  localAttempts.forEach((a) => {
    if (!localCourseStats[a.courseCode]) {
      localCourseStats[a.courseCode] = { attempts: 0, correct: 0, total: 0, lastAttempt: a.createdAt }
    }
    localCourseStats[a.courseCode].attempts++
    localCourseStats[a.courseCode].correct += a.score
    localCourseStats[a.courseCode].total += a.total
    if (a.createdAt > localCourseStats[a.courseCode].lastAttempt) {
      localCourseStats[a.courseCode].lastAttempt = a.createdAt
    }
  })

  const totalAnswered = localAttempts.reduce((sum, a) => sum + a.total, 0)
  const totalCorrect = localAttempts.reduce((sum, a) => sum + a.score, 0)
  const average = totalAnswered ? Math.round((totalCorrect / totalAnswered) * 100) : 0
  const streakStats = getStreakStats(localAttempts)

  // Server-side aggregates
  const totalKcs = Object.values(stats).reduce((sum, s) => sum + s.totalKcs, 0)
  const masteredKcs = Object.values(stats).reduce((sum, s) => sum + s.masteredKcs, 0)
  const serverTotalAttempts = Object.values(stats).reduce((sum, s) => sum + s.totalAttempts, 0)
  const avgMastery = totalKcs > 0 ? Math.round((masteredKcs / totalKcs) * 100) : 0

  function masteryColor(prob: number) {
    if (prob >= 0.75) return 'mastery-high'
    if (prob >= 0.5) return 'mastery-mid'
    return 'mastery-low'
  }

  return (
    <div className="page-stack">
      <PageHeader title="Hub" />
      {loading && <LoadingState label="Loading your progress..." />}
      {error && !loading && <ErrorState message={error} />}
      {!loading && !error && (
        <>
          {/* Summary metrics */}
          <section className="metrics-grid">
            <MetricCard icon={<BarChart3 />} label="Average score" value={`${average}%`} hint="Across all quizzes" />
            <MetricCard icon={<BrainCircuit />} label="Questions answered" value={totalAnswered} hint="Total questions" />
            <MetricCard icon={<Flame />} label="Study streak" value={streakStats.currentStreak} hint={streakStats.completedToday ? 'Completed today' : 'Take a quiz today'} to="/app/streaks" />
            <MetricCard icon={<Target />} label="Quiz sessions" value={localAttempts.length} hint="Quizzes completed" />
            <MetricCard icon={<GraduationCap />} label="Courses studied" value={Object.keys(localCourseStats).length} hint="Unique courses" />
          </section>

          {/* Server-side mastery summary (if available) */}
          {userId && totalKcs > 0 && (
            <section className="section-card">
              <div className="section-title">
                <h2>Mastery overview</h2>
                <span className="score-chip">{avgMastery}% avg</span>
              </div>
              <div className="mastery-summary-row">
                <div className="mastery-summary-stat">
                  <span className="mastery-summary-value">{masteredKcs}</span>
                  <span className="mastery-summary-label">Topics mastered</span>
                </div>
                <div className="mastery-summary-stat">
                  <span className="mastery-summary-value">{totalKcs}</span>
                  <span className="mastery-summary-label">Total topics</span>
                </div>
                <div className="mastery-summary-stat">
                  <span className="mastery-summary-value">{serverTotalAttempts}</span>
                  <span className="mastery-summary-label">Adaptive attempts</span>
                </div>
              </div>
            </section>
          )}

          {!userId && localAttempts.length > 0 && (
            <div className="section-card" style={{ padding: '0.8rem 1.2rem' }}>
              <p style={{ margin: 0, color: 'var(--muted)', fontSize: '0.85rem' }}>
                <Link to="/app/profile" style={{ color: 'var(--primary)', fontWeight: 600 }}>Sign in</Link> to unlock adaptive mastery tracking and save progress across devices.
              </p>
            </div>
          )}

          {/* Course performance breakdown (from localStorage) */}
          {Object.keys(localCourseStats).length > 0 && (
            <section className="section-card">
              <div className="section-title">
                <h2>Course performance</h2>
              </div>
              <div className="mastery-table">
                <div className="mastery-table-header">
                  <span>Course</span>
                  <span>Score</span>
                  <span>Quizzes</span>
                  <span>Questions</span>
                  <span>Last active</span>
                </div>
                {Object.entries(localCourseStats)
                  .sort(([, a], [, b]) => (b.correct / b.total) - (a.correct / a.total))
                  .map(([code, data]) => {
                    const pct = data.total > 0 ? Math.round((data.correct / data.total) * 100) : 0
                    return (
                      <Link className="mastery-table-row analytics-link-row" key={code} to={`/app/hub/${encodeURIComponent(code)}`}>
                        <div className="mastery-course">
                          <strong>{code}</strong>
                          <span>{courseTitleMap[code] || code}</span>
                        </div>
                        <div className="mastery-bar-cell">
                          <div className="mastery-bar">
                            <span className={cx('mastery-bar-fill', pct >= 75 ? 'mastery-high' : pct >= 50 ? 'mastery-mid' : 'mastery-low')} style={{ width: `${pct}%` }} />
                          </div>
                          <span>{pct}%</span>
                        </div>
                        <span>{data.attempts}</span>
                        <span>{data.correct}/{data.total}</span>
                        <span>{data.lastAttempt ? new Date(data.lastAttempt).toLocaleDateString() : '—'}</span>
                      </Link>
                    )
                  })}
              </div>
            </section>
          )}

          {/* Server-side topic mastery (if available) */}
          {userId && mastery.length > 0 && (() => {
            const now = new Date()
            const overdueTopics = mastery.filter((t) => {
              if (!t.next_review_due) return false
              return new Date(t.next_review_due) <= now
            })
            const fragileTopics = mastery.filter((t) => t.s_parameter < 1.5 && t.status === 'reviewing')
            const stableTopics = mastery.filter((t) => t.s_parameter >= 2.0 && t.status === 'reviewing')

            return (
              <>
                {/* Review schedule alerts */}
                {(overdueTopics.length > 0 || fragileTopics.length > 0) && (
                  <section className="section-card review-alerts">
                    <div className="section-title">
                      <h2>Retention alerts</h2>
                    </div>
                    {overdueTopics.length > 0 && (
                      <div className="review-alert-group">
                        <h3 className="review-alert-heading review-overdue">
                          <TimerReset size={14} />
                          Overdue for review ({overdueTopics.length})
                        </h3>
                        <p className="review-alert-desc">These topics are past their review date. Practice now to prevent forgetting.</p>
                        <div className="review-topic-chips">
                          {overdueTopics.slice(0, 8).map((t) => (
                            <Link
                              to={`/app/courses/${encodeURIComponent(t.course_code)}/quiz?topic=${encodeURIComponent(t.topic_name)}`}
                              className="review-topic-chip overdue"
                              key={`${t.course_code}-${t.topic_name}`}
                            >
                              <span className="review-chip-code">{t.course_code}</span>
                              <span className="review-chip-name">{t.topic_name}</span>
                              <span className="review-chip-date">{new Date(t.next_review_due).toLocaleDateString()}</span>
                            </Link>
                          ))}
                        </div>
                      </div>
                    )}
                    {fragileTopics.length > 0 && (
                      <div className="review-alert-group">
                        <h3 className="review-alert-heading review-fragile">
                          <AlertCircle size={14} />
                          Fragile memory ({fragileTopics.length})
                        </h3>
                        <p className="review-alert-desc">Low stability — these topics are at risk of being forgotten soon.</p>
                        <div className="review-topic-chips">
                          {fragileTopics.slice(0, 8).map((t) => (
                            <Link
                              to={`/app/courses/${encodeURIComponent(t.course_code)}/quiz?topic=${encodeURIComponent(t.topic_name)}`}
                              className="review-topic-chip fragile"
                              key={`${t.course_code}-${t.topic_name}`}
                            >
                              <span className="review-chip-code">{t.course_code}</span>
                              <span className="review-chip-name">{t.topic_name}</span>
                              <span className="review-chip-stability">Stability: {t.s_parameter.toFixed(1)}</span>
                            </Link>
                          ))}
                        </div>
                      </div>
                    )}
                  </section>
                )}

                {/* Full topic mastery list */}
                <section className="section-card">
                  <div className="section-title">
                    <h2>Topic mastery</h2>
                    <span className="score-chip">{mastery.length} topics</span>
                  </div>
                  <div className="topic-mastery-list">
                    {mastery
                      .sort((a, b) => a.mastery_prob - b.mastery_prob)
                      .slice(0, 10)
                      .map((t) => {
                        const isOverdue = t.next_review_due && new Date(t.next_review_due) <= now
                        const isFragile = t.s_parameter < 1.5
                        const daysSinceLastAttempt = t.last_attempt_at
                          ? Math.floor((now.getTime() - new Date(t.last_attempt_at).getTime()) / (1000 * 60 * 60 * 24))
                          : null

                        return (
                          <article className={cx('topic-mastery-item', isOverdue && 'overdue', isFragile && 'fragile')} key={`${t.course_code}-${t.topic_name}`}>
                            <div className="topic-mastery-info">
                              <strong>{t.topic_name}</strong>
                              <span>{t.course_code}</span>
                            </div>
                            <div className="topic-mastery-bar-wrap">
                              <div className="topic-mastery-bar">
                                <span className={cx('mastery-bar-fill', masteryColor(t.mastery_prob))} style={{ width: `${Math.round(t.mastery_prob * 100)}%` }} />
                              </div>
                              <span className={cx('status-badge', t.status === 'reviewing' ? 'status-reviewing' : 'status-learning')}>
                                {t.status === 'reviewing' ? 'Reviewing' : 'Learning'}
                              </span>
                            </div>
                            <div className="topic-mastery-meta">
                              <span>{t.correct_attempts}/{t.total_attempts} correct</span>
                              <span className={cx('stability-indicator', isFragile ? 'stability-fragile' : t.s_parameter >= 2.0 ? 'stability-strong' : 'stability-moderate')}>
                                Stability: {t.s_parameter.toFixed(1)}
                              </span>
                              {daysSinceLastAttempt !== null && (
                                <span className={cx('recency', daysSinceLastAttempt > 7 && 'recency-stale')}>
                                  {daysSinceLastAttempt === 0 ? 'Today' : `${daysSinceLastAttempt}d ago`}
                                </span>
                              )}
                              {t.next_review_due && (
                                <span className={cx('review-due', isOverdue && 'review-overdue')}>
                                  {isOverdue ? 'Overdue' : `Review: ${new Date(t.next_review_due).toLocaleDateString()}`}
                                </span>
                              )}
                            </div>
                          </article>
                        )
                      })}
                  </div>
                </section>

                {/* Strong retention stats */}
                {stableTopics.length > 0 && (
                  <section className="section-card">
                    <div className="section-title">
                      <h2>Strong retention</h2>
                      <span className="score-chip">{stableTopics.length} topics</span>
                    </div>
                    <p className="section-hint">Topics with high stability — you're unlikely to forget these soon.</p>
                    <div className="topic-mastery-list">
                      {stableTopics
                        .sort((a, b) => b.s_parameter - a.s_parameter)
                        .slice(0, 5)
                        .map((t) => (
                          <article className="topic-mastery-item strong" key={`${t.course_code}-${t.topic_name}`}>
                            <div className="topic-mastery-info">
                              <strong>{t.topic_name}</strong>
                              <span>{t.course_code}</span>
                            </div>
                            <div className="topic-mastery-bar-wrap">
                              <div className="topic-mastery-bar">
                                <span className="mastery-bar-fill mastery-high" style={{ width: `${Math.round(t.mastery_prob * 100)}%` }} />
                              </div>
                              <span className="status-badge status-reviewing">Reviewing</span>
                            </div>
                            <div className="topic-mastery-meta">
                              <span className="stability-indicator stability-strong">Stability: {t.s_parameter.toFixed(1)}</span>
                              <span>{t.correct_attempts}/{t.total_attempts} correct</span>
                            </div>
                          </article>
                        ))}
                    </div>
                  </section>
                )}
              </>
            )
          })()}

          {/* Recent quiz history (from localStorage) */}
          {localAttempts.length > 0 && (
            <section className="section-card">
              <div className="section-title">
                <h2>Recent quizzes</h2>
                <Link to="/app/courses">Take a quiz</Link>
              </div>
              <div className="attempt-list">
                {localAttempts.slice(0, 8).map((attempt) => (
                  <article key={attempt.id}>
                    <div>
                      <strong>{attempt.courseCode}</strong>
                      <span>{attempt.courseTitle} · {attempt.mode ?? 'multiple-choice'}</span>
                    </div>
                    <div className="bar-track">
                      <span style={{ width: `${Math.round((attempt.score / attempt.total) * 100)}%` }} />
                    </div>
                    <b>{attempt.score}/{attempt.total}</b>
                  </article>
                ))}
              </div>
            </section>
          )}

          {localAttempts.length === 0 && (
            <EmptyState
              icon={<LineChart />}
              title="No quiz data yet"
              body="Complete a course quiz and your progress will appear here."
            />
          )}
        </>
      )}
    </div>
  )
}

function StreaksPage() {
  const attempts = readJson<QuizAttempt[]>(ATTEMPTS_KEY, [])
  const stats = getStreakStats(attempts)
  const [tab, setTab] = useState<'personal' | 'friends'>('personal')
  const latestAttempt = attempts[0]
  const quizTarget = latestAttempt ? `/app/courses/${encodeURIComponent(latestAttempt.courseCode)}/quiz` : '/app/courses'

  return (
    <div className="page-stack narrow streaks-page">
      <Link className="back-link" to="/app">
        <ArrowLeft size={18} /> Back to dashboard
      </Link>
      <PageHeader title="Streaks" />
      <div className="streak-tabs" role="tablist" aria-label="Streak views">
        <button className={cx(tab === 'personal' && 'active')} onClick={() => setTab('personal')} type="button">
          PERSONAL
        </button>
        <button className={cx(tab === 'friends' && 'active')} onClick={() => setTab('friends')} type="button">
          FRIENDS
        </button>
      </div>

      {tab === 'personal' ? (
        <>
          <section className={cx('streak-hero-card', !stats.completedToday && 'needs-action')}>
            <div className="streak-number-block">
              <span>STREAKS HUB</span>
              <strong>{stats.currentStreak}</strong>
              <p>day streak!</p>
            </div>
            <Flame className="streak-fire" />
          </section>

          <section className="streak-cta-card">
            <div className="streak-clock">
              <TimerReset size={34} />
            </div>
            <div>
              <h2>{stats.completedToday ? 'Today is covered' : 'Keep your streak alive'}</h2>
              <p>{stats.completedToday ? 'Come back tomorrow and keep the chain going.' : 'Jump back into the Hub for a quick quiz before the day ends.'}</p>
              <Link to={quizTarget}>DO YOUR QUIZ</Link>
            </div>
          </section>

          <section className="streak-calendar-card">
            <div className="section-title">
              <div>
                <p className="eyebrow">Study calendar</p>
                <h2>{stats.completedInWindow}/{STREAK_WINDOW_DAYS} days completed</h2>
              </div>
            </div>
            <div className="streak-calendar-grid">
              {stats.days.map((day) => (
                <div className={cx('streak-day', day.completed && 'completed', day.isToday && 'today')} key={day.key}>
                  <span>{day.date.toLocaleDateString(undefined, { weekday: 'short' })}</span>
                  <strong>{day.date.getDate()}</strong>
                  <small>{day.completed ? 'Done' : day.isToday ? 'Today' : 'Open'}</small>
                </div>
              ))}
            </div>
          </section>
        </>
      ) : (
        <section className="state-card streak-friends-card">
          <Users size={52} />
          <h3>Friends streaks coming soon</h3>
          <p>Keep building your personal rhythm. Friend comparisons can come after the core learning flow feels solid.</p>
        </section>
      )}
    </div>
  )
}

function CourseAnalyticsPage() {
  const { code = '' } = useParams()
  const courseCode = decodeURIComponent(code)
  const navigate = useNavigate()
  const firebaseUser = useFirebaseUser()
  const userId = (firebaseUser as import('firebase/auth').User | null)?.uid
  const [mastery, setMastery] = useState<MasteryRecord[]>([])
  const [attempts, setAttempts] = useState<AttemptRecord[]>([])
  const [loading, setLoading] = useState(Boolean(userId))
  const [error, setError] = useState('')

  const localAttempts = readJson<QuizAttempt[]>(ATTEMPTS_KEY, []).filter((attempt) => attempt.courseCode === courseCode)
  const title = localAttempts[0]?.courseTitle || courseCode

  useEffect(() => {
    if (!userId || !courseCode) {
      setLoading(false)
      return
    }
    let active = true
    setLoading(true)
    setError('')
    Promise.all([
      getUserMasteryForCourse(userId, courseCode),
      getUserAttempts(userId, { course: courseCode, limit: 200 }),
    ]).then(([courseMastery, attemptHistory]) => {
      if (!active) return
      setMastery(courseMastery.topics ?? [])
      setAttempts(attemptHistory.attempts ?? [])
      setLoading(false)
    }).catch(() => {
      if (!active) return
      setError('Failed to load course analytics')
      setLoading(false)
    })
    return () => { active = false }
  }, [courseCode, userId])

  const orderedAttempts = [...attempts].sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
  const totalQuestions = attempts.length || localAttempts.reduce((sum, attempt) => sum + attempt.total, 0)
  const correctQuestions = attempts.length
    ? attempts.filter((attempt) => Boolean(attempt.is_correct)).length
    : localAttempts.reduce((sum, attempt) => sum + attempt.score, 0)
  const accuracy = totalQuestions ? Math.round((correctQuestions / totalQuestions) * 100) : 0
  const avgMastery = mastery.length ? Math.round((mastery.reduce((sum, topic) => sum + topic.mastery_prob, 0) / mastery.length) * 100) : 0
  const masteredTopics = mastery.filter((topic) => topic.status === 'reviewing').length
  const strongestTopics = [...mastery].sort((a, b) => b.mastery_prob - a.mastery_prob).slice(0, 6)
  const weakestTopics = [...mastery].sort((a, b) => a.mastery_prob - b.mastery_prob).slice(0, 6)
  const progressPoints = orderedAttempts.map((attempt, index) => ({
    label: new Date(attempt.created_at).toLocaleDateString(),
    value: Math.round(attempt.mastery_after * 100),
    before: Math.round(attempt.mastery_before * 100),
    index: index + 1,
  }))
  const polyline = progressPoints.map((point, index) => {
    const x = progressPoints.length === 1 ? 50 : (index / (progressPoints.length - 1)) * 100
    const y = 100 - point.value
    return `${x},${y}`
  }).join(' ')
  const topicBars = (strongestTopics.length ? strongestTopics : weakestTopics).slice(0, 8)

  return (
    <div className="page-stack">
      <button className="ghost-button inline-back" onClick={() => navigate('/app/hub')}><ArrowLeft size={16} /> Back to Hub</button>
      <PageHeader eyebrow="Course analytics" title={title}>Detailed adaptive learning progress, mastery movement, strengths, and topics that need attention.</PageHeader>
      {loading && <LoadingState label="Loading course analytics..." />}
      {error && !loading && <ErrorState message={error} />}
      {!loading && !error && (
        <>
          <section className="metrics-grid">
            <MetricCard icon={<Target />} label="Accuracy" value={`${accuracy}%`} hint={`${correctQuestions}/${totalQuestions} correct`} />
            <MetricCard icon={<BrainCircuit />} label="Adaptive mastery" value={`${avgMastery}%`} hint={`${masteredTopics}/${mastery.length} topics reviewing`} />
            <MetricCard icon={<BarChart3 />} label="Answer events" value={attempts.length || totalQuestions} hint={attempts.length ? 'Synced adaptive attempts' : 'Local quiz questions'} />
            <MetricCard icon={<CalendarDays />} label="Quiz sessions" value={localAttempts.length} hint="Completed on this device" />
          </section>

          <section className="section-card">
            <div className="section-title">
              <h2>Progress over time</h2>
              <span className="score-chip">{progressPoints.length} answers</span>
            </div>
            {progressPoints.length > 0 ? (
              <div className="progress-chart-card">
                <svg className="progress-line-chart" viewBox="0 0 100 100" preserveAspectRatio="none" role="img" aria-label="Mastery progress line chart">
                  <polyline className="progress-line-area" points={`0,100 ${polyline} 100,100`} />
                  <polyline className="progress-line" points={polyline} />
                </svg>
                <div className="progress-chart-labels">
                  <span>{progressPoints[0]?.label}</span>
                  <span>{progressPoints.at(-1)?.label}</span>
                </div>
              </div>
            ) : (
              <EmptyState icon={<LineChart />} title="No adaptive answer history yet" body="Complete a signed-in multiple-choice quiz to see mastery change after each answer." />
            )}
          </section>

          <section className="analytics-two-column">
            <div className="section-card">
              <div className="section-title"><h2>Strengths bar chart</h2></div>
              <div className="topic-bar-chart">
                {topicBars.map((topic) => {
                  const pct = Math.round(topic.mastery_prob * 100)
                  return (
                    <div className="topic-bar-row" key={`${topic.course_code}-${topic.topic_name}`}>
                      <span>{topic.topic_name}</span>
                      <div className="topic-bar-track"><b style={{ width: `${pct}%` }} /></div>
                      <strong>{pct}%</strong>
                    </div>
                  )
                })}
                {topicBars.length === 0 && <p className="section-hint">No topic mastery has been synced for this course yet.</p>}
              </div>
            </div>

            <div className="section-card">
              <div className="section-title"><h2>Needs attention</h2></div>
              <div className="topic-mastery-list">
                {weakestTopics.map((topic) => (
                  <article className="topic-mastery-item fragile" key={`${topic.course_code}-${topic.topic_name}`}>
                    <div className="topic-mastery-info"><strong>{topic.topic_name}</strong><span>{topic.correct_attempts}/{topic.total_attempts} correct</span></div>
                    <div className="topic-mastery-bar"><span className={cx('mastery-bar-fill', topic.mastery_prob >= 0.75 ? 'mastery-high' : topic.mastery_prob >= 0.5 ? 'mastery-mid' : 'mastery-low')} style={{ width: `${Math.round(topic.mastery_prob * 100)}%` }} /></div>
                  </article>
                ))}
                {weakestTopics.length === 0 && <p className="section-hint">More adaptive attempts will identify weak topics and review priorities.</p>}
              </div>
            </div>
          </section>
        </>
      )}
    </div>
  )
}

function ProfilePage() {
  const navigate = useNavigate()
  const profile = useProfile()
  const firebaseUser = useFirebaseUser()
  const userId = firebaseUser && firebaseUser !== 'loading' ? firebaseUser.uid : null
  const { theme, setTheme, scheme, setScheme, resolved } = useTheme()
  const attempts = readJson<QuizAttempt[]>(ATTEMPTS_KEY, [])
  const [draft, setDraft] = useState<Profile>(() => profile ?? demoProfile('engineer@example.com'))
  const [saveError, setSaveError] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (profile) setDraft(profile)
  }, [profile])

  const totalAttempts = attempts.reduce((s, a) => s + a.total, 0)
  const totalCorrect = attempts.reduce((s, a) => s + a.score, 0)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSaveError('')
    setSaving(true)
    const department = departments.find((d) => d.code === draft.departmentCode)
    const nextProfile = { ...draft, departmentName: department?.name ?? draft.departmentName }
    try {
      if (userId) {
        await saveUserProfile(userId, nextProfile)
      }
      saveProfile(nextProfile)
      navigate('/app')
    } catch (err: any) {
      setSaveError(err?.message || 'Profile saved on this device, but cloud sync failed. Try again.')
      saveProfile(nextProfile)
    } finally {
      setSaving(false)
    }
  }

  function getInitials(first: string, last: string) {
    return `${(first[0] ?? '').toUpperCase()}${(last[0] ?? '').toUpperCase()}` || 'U'
  }

  function onSignOut() {
    signOutUser()
    saveProfile(null)
    navigate('/welcome')
  }

  return (
    <div className="page-stack profile-page">
      {/* Hero */}
      <section className="profile-hero profile-stagger" style={{ animationDelay: '0ms' }}>
        <div className="profile-avatar-wrap">
          <div className="profile-avatar-inner">
            {draft.firstName || draft.lastName
              ? getInitials(draft.firstName, draft.lastName)
              : <User size={32} />}
          </div>
        </div>
        <h1>{draft.firstName || 'Engineer'} {draft.lastName}</h1>
        <p className="profile-email">{draft.email}</p>
        <div className="profile-badge-row">
          <span className="profile-badge">
            <Building2 size={13} />
            {(departments.find((d) => d.code === draft.departmentCode)?.name ?? draft.departmentName) || 'No department'}
          </span>
        </div>
      </section>

      {/* Stats */}
      <section className="profile-stats profile-stagger" style={{ animationDelay: '60ms' }}>
        <div className="profile-stat">
          <GraduationCap size={20} />
          <strong>{draft.selectedCourses.length}</strong>
          <span>Courses</span>
        </div>
        <div className="profile-stat">
          <BrainCircuit size={20} />
          <strong>{totalAttempts}</strong>
          <span>Answered</span>
        </div>
        <div className="profile-stat">
          <Flame size={20} />
          <strong>{attempts.length ? Math.min(attempts.length, 30) : 1}</strong>
          <span>Streak</span>
        </div>
        <div className="profile-stat">
          <Trophy size={20} />
          <strong>{totalAttempts ? Math.round(totalCorrect / totalAttempts * 100) : 0}%</strong>
          <span>Accuracy</span>
        </div>
      </section>

      {/* Two-col: Appearance + Academic */}
      <div className="profile-two-col profile-stagger" style={{ animationDelay: '120ms' }}>
        {/* Appearance */}
        <section className="profile-card">
          <div className="profile-card-header">
            <Palette size={18} />
            <div>
              <h2>Appearance</h2>
              <p>Theme mode &amp; color accent</p>
            </div>
          </div>
          <p className="profile-color-label">Theme</p>
          <div className="profile-theme-picker">
            {([
              { id: 'light', icon: <Sun size={16} />, label: 'Light' },
              { id: 'dark', icon: <Moon size={16} />, label: 'Dark' },
              { id: 'system', icon: <Laptop size={16} />, label: 'Auto' },
            ] as const).map((mode) => (
              <button
                key={mode.id}
                type="button"
                className={cx('profile-theme-btn', theme === mode.id && 'selected')}
                onClick={() => setTheme(mode.id)}
              >
                {mode.icon}
                <span>{mode.label}</span>
              </button>
            ))}
          </div>
          <p className="profile-color-label">Color accent</p>
          <div className="profile-swatch-grid">
            {colorSchemes.map((schemeItem) => (
              <button
                key={schemeItem.name}
                type="button"
                className={cx('profile-swatch', scheme === schemeItem.color && 'selected')}
                style={{ backgroundColor: schemeItem.color, color: schemeItem.color }}
                onClick={() => setScheme(schemeItem.color)}
                title={schemeItem.name}
                aria-label={schemeItem.name}
              >
                {scheme === schemeItem.color && <Check size={16} color={resolved === 'dark' ? '#111' : '#fff'} />}
              </button>
            ))}
          </div>
        </section>

        {/* Academic */}
        <section className="profile-card">
          <div className="profile-card-header">
            <GraduationCap size={18} />
            <div>
              <h2>Academic Profile</h2>
              <p>Your department &amp; info</p>
            </div>
          </div>
          <form id="profile-form" onSubmit={submit}>
            <div className="two-col" style={{ marginBottom: '0.75rem' }}>
              <label>
                First name
                <input value={draft.firstName} onChange={(e) => setDraft({ ...draft, firstName: e.target.value })} />
              </label>
              <label>
                Last name
                <input value={draft.lastName} onChange={(e) => setDraft({ ...draft, lastName: e.target.value })} />
              </label>
            </div>
            <label>
              Email
              <input value={draft.email} onChange={(e) => setDraft({ ...draft, email: e.target.value })} />
            </label>
            <label style={{ marginTop: '0.75rem' }}>
              Department
              <select value={draft.departmentCode} onChange={(e) => setDraft({ ...draft, departmentCode: e.target.value })}>
                {departments.map((d) => (
                  <option key={d.code} value={d.code}>{d.name}</option>
                ))}
              </select>
            </label>
            {saveError && <p className="form-error">{saveError}</p>}
            <button className="primary-button full" type="submit" style={{ marginTop: '1rem' }} disabled={saving}>
              <CheckCircle2 size={18} /> {saving ? 'Saving...' : 'Save profile'}
            </button>
          </form>
        </section>
      </div>

      {/* My Courses */}
      <section className="profile-card profile-stagger" style={{ animationDelay: '180ms' }}>
        <div className="profile-card-header">
          <BookOpen size={18} />
          <div>
            <h2>My Courses</h2>
            <p>{draft.selectedCourses.length} course{draft.selectedCourses.length !== 1 ? 's' : ''} selected</p>
          </div>
        </div>
        {draft.selectedCourses.length === 0 ? (
          <p className="profile-empty-hint">No courses selected yet. Complete registration to pick courses.</p>
        ) : (
          <div className="profile-course-list">
            {draft.selectedCourses.map((course) => (
              <div className="profile-course-item" key={course.code}>
                <div className="profile-course-info">
                  <span className="profile-course-code">{course.code}</span>
                  <span className="profile-course-title">{course.title}</span>
                </div>
                <button
                  type="button"
                  className="profile-course-remove"
                  onClick={() => setDraft({
                    ...draft,
                    selectedCourses: draft.selectedCourses.filter((c) => c.code !== course.code)
                  })}
                >
                  <X size={14} />
                </button>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Account Actions */}
      <section className="profile-card profile-stagger" style={{ animationDelay: '240ms' }}>
        <div className="profile-card-header">
          <Lock size={18} />
          <div>
            <h2>Account</h2>
            <p>Sign out or delete your account</p>
          </div>
        </div>
        <div className="profile-account-actions">
          <button className="ghost-button" onClick={onSignOut} type="button">
            <LogOut size={18} /> Sign out
          </button>
          <button className="profile-danger-btn" type="button">
            <Trash2 size={18} /> Delete account
          </button>
        </div>
      </section>
    </div>
  )
}

function NotFoundPage() {
  return (
    <div className="page-stack narrow">
      <EmptyState icon={<AlertCircle />} title="Page not found" body="This page is not available in Vens Hub yet." />
      <Link className="primary-button" to="/app">Back home</Link>
    </div>
  )
}

// Suppress unused-component warnings (used conditionally across module boundaries)
void TheoryQuizMode; void GapFillQuizMode;

function App() {
  // Apply saved theme/scheme on every mount
  useEffect(() => {
    applyTheme(getTheme())
    applyScheme(getScheme())
  }, [])

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/welcome" element={<LandingPage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route element={<RequireAuth />}>
          <Route path="/app" element={<AppShell />}>
            <Route index element={<DashboardPage />} />
            <Route path="courses" element={<CoursesPage />} />
            <Route path="courses/:code" element={<CourseDetailPage />} />
            <Route path="courses/:code/quiz" element={<QuizSetupPage />} />
            <Route path="quiz/:code" element={<QuizPage />} />
            <Route path="schedule" element={<SchedulePage />} />
            <Route path="study" element={<FlashcardsPage />} />
            <Route path="flashcards" element={<FlashcardsPage />} />
            <Route path="hub" element={<HubPage />} />
            <Route path="hub/:code" element={<CourseAnalyticsPage />} />
            <Route path="streaks" element={<StreaksPage />} />
            <Route path="profile" element={<ProfilePage />} />
          </Route>
        </Route>
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
