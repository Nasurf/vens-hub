import { useEffect, useMemo, useRef, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import {
  AlertCircle,
  ArrowLeft,
  BarChart3,
  Bot,
  BookOpen,
  BrainCircuit,
  Building2,
  CalendarDays,
  CheckCircle2,
  ChevronRight,
  CircleUserRound,
  ClipboardList,
  FileText,
  Flame,
  GraduationCap,
  Home,
  Layers3,
  LineChart,
  Lock,
  LogOut,
  Mail,
  Menu,
  MessageCircle,
  PlayCircle,
  Plus,
  RefreshCw,
  Search,
  Send,
  Sparkles,
  Target,
  TimerReset,
  Trophy,
  UploadCloud,
  User,
  X,
} from 'lucide-react'
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
  getUserIdHeader,
} from './firebase'

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
  level: string
  departmentCode: string
  departmentName: string
}

type EventItem = {
  id: string
  title: string
  course?: string
  date: string
  start: string
  end: string
  venue?: string
}

type StudyUpload = {
  id: string
  name: string
  size: number
  subject: string
  createdAt: string
  contentType?: string
  objectKey?: string
  status?: 'uploaded' | 'pending_upload' | 'failed'
  url?: string
  error?: string
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
const UPLOAD_API_BASE = import.meta.env.VITE_UPLOAD_API_BASE_URL
const ASSISTANT_API_BASE = import.meta.env.VITE_ASSISTANT_API_BASE_URL

if (!API_BASE) {
  throw new Error('VITE_API_BASE_URL is required — copy env.example to .env.local and set it')
}

const PROFILE_KEY = 'vens-hub-web-profile'
const EVENTS_KEY = 'vens-hub-web-events'
const UPLOADS_KEY = 'vens-hub-web-uploads'
const ATTEMPTS_KEY = 'vens-hub-web-quiz-attempts'

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

const levelOptions = ['100', '200', '300', '400', '500']

const featureHighlights = [
  'Interactive quizzes: multiple choice, theory and gap-fill ready',
  'Smart schedule for class planning and self-study blocks',
  'Course workspace backed by the live Vens Hub question API',
  'Progress hub for streaks, performance and subject focus',
]

function cx(...classes: Array<string | false | undefined>) {
  return classes.filter(Boolean).join(' ')
}

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
    const unsub = onAuthChange((u) => setUser(u))
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
  courses: () => fetchJson<{ courses: Course[] }>('/courses'),
  departmentCourses: (code: string) =>
    fetchJson<{ courses: Course[] }>(`/departments/${encodeURIComponent(code)}/courses`),
  course: (code: string) => fetchJson<{ course: Course }>(`/courses/${encodeURIComponent(code)}`),
  questions: (code: string) =>
    fetchJson<{ questions: Question[]; count: number }>(`/questions/${encodeURIComponent(code)}`),
}


function safePathPart(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'user'
}

function safeFilename(value: string) {
  return value.trim().replace(/[^A-Za-z0-9._-]+/g, '_').replace(/_+/g, '_') || 'document'
}

function makeObjectKey(file: File, profile: Profile | null) {
  const owner = safePathPart(profile?.email ?? profile?.firstName ?? 'demo-user')
  return `users/${owner}/uploads/${Date.now()}-${crypto.randomUUID()}-${safeFilename(file.name)}`
}

async function uploadStudyFile(file: File, profile: Profile | null): Promise<StudyUpload> {
  const objectKey = makeObjectKey(file, profile)
  const metadata = {
    uploaded_by: profile?.email ?? 'demo-user',
    original_filename: file.name,
    subject: 'General',
  }

  try {
    const presign = await postJson<{
      upload?: { url: string; method?: string; headers?: Record<string, string> }
      object_key?: string
      public_url?: string
      finalize_url?: string
    }>(UPLOAD_API_BASE, '/uploads/presign', {
      object_key: objectKey,
      filename: file.name,
      content_type: file.type || 'application/octet-stream',
      size_bytes: file.size,
      metadata,
    })

    if (!presign.upload?.url) {
      throw new Error('Upload endpoint did not return an upload URL.')
    }

    const put = await fetch(presign.upload.url, {
      method: presign.upload.method ?? 'PUT',
      headers: {
        ...(presign.upload.headers ?? {}),
        'Content-Type': file.type || 'application/octet-stream',
        'x-vens-upload-size': String(file.size),
      },
      body: file,
    })

    if (!put.ok) {
      throw new Error(`R2 upload PUT failed with status ${put.status}`)
    }

    const finalObjectKey = presign.object_key ?? objectKey
    const finalize = await postJson<{ record?: { url?: string }; public_url?: string }>(
      UPLOAD_API_BASE,
      presign.finalize_url ?? '/uploads/finalize',
      {
        object_key: finalObjectKey,
        size_bytes: file.size,
        metadata,
      },
    )

    return {
      id: crypto.randomUUID(),
      name: file.name,
      size: file.size,
      subject: 'General',
      contentType: file.type || 'application/octet-stream',
      objectKey: finalObjectKey,
      url: finalize.record?.url ?? finalize.public_url ?? presign.public_url,
      status: 'uploaded',
      createdAt: new Date().toISOString(),
    }
  } catch (error) {
    return {
      id: crypto.randomUUID(),
      name: file.name,
      size: file.size,
      subject: 'General',
      contentType: file.type || 'application/octet-stream',
      objectKey,
      status: 'pending_upload',
      error: error instanceof Error ? error.message : String(error),
      createdAt: new Date().toISOString(),
    }
  }
}

function makeAssistantFallback(question: string, context?: string) {
  const scoped = context ? `

Context I used: ${context}` : ''
  return `The AI endpoint is not deployed/configured yet, but the assistant shell is working. For now, use this as the study prompt: ${question}.${scoped}`
}

async function askAssistant(question: string, context?: string) {
  try {
    const response = await postJson<{ answer?: string }>(ASSISTANT_API_BASE, '/assistant', {
      question,
      context,
    })
    return response.answer?.trim() || makeAssistantFallback(question, context)
  } catch {
    return makeAssistantFallback(question, context)
  }
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
  const directAnswerHit = normalizedCorrect.length > 0 && normalizeText(answer).includes(normalizedCorrect.slice(0, 24).trim())
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

function formatBytes(size: number) {
  if (size < 1024) return `${size} B`
  if (size < 1024 * 1024) return `${Math.round(size / 1024)} KB`
  return `${(size / (1024 * 1024)).toFixed(1)} MB`
}

function todayIso() {
  return new Date().toISOString().slice(0, 10)
}

function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <Link to={getProfile() ? '/app' : '/'} className={cx('logo-lockup', compact && 'compact')}>
      <span className="logo-mark">
        <img src="/brand/logo.svg" alt="Vens Hub" />
      </span>
      {!compact && (
        <span>
          <strong>Vens Hub</strong>
          <small>Engineering Hub</small>
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
  return (
    <header className="page-header">
      <div>
        {eyebrow && <p className="eyebrow">{eyebrow}</p>}
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
}: {
  icon: ReactNode
  label: string
  value: string | number
  hint: string
}) {
  return (
    <article className="metric-card">
      <div className="metric-icon">{icon}</div>
      <p>{label}</p>
      <strong>{value}</strong>
      <span>{hint}</span>
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

function PublicShell({ children }: { children: ReactNode }) {
  const profile = useProfile()
  if (profile) return <Navigate to="/app" replace />
  return <main className="public-shell">{children}</main>
}

function LandingPage() {
  return (
    <PublicShell>
      <section className="landing-grid">
        <div className="landing-copy">
          <Logo />
          <div className="hero-text">
            <span className="eyebrow">React migration started</span>
            <h1>
              Engineer <span>smarter</span> on the web.
            </h1>
            <p>
              Courses, practice quizzes, schedules, study uploads and progress analytics are now
              moving into a real React web app for the hackathon flow.
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
                <p>Live course API</p>
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
    </PublicShell>
  )
}

function LoginPage() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!email.includes('@') || password.length < 6) {
      setError('Use a valid email and a password with at least 6 characters.')
      return
    }
    const existing = getProfile()
    const profile: Profile = existing?.email === email ? existing : demoProfile(email)
    saveProfile(profile)
    navigate('/app')
  }

  function useDemo() {
    saveProfile(demoProfile('engineer@example.com'))
    navigate('/app')
  }

  return (
    <PublicShell>
      <AuthCard
        title="Welcome back"
        subtitle="Continue to your engineering workspace. Firebase auth will plug into this shell next."
      >
        <form onSubmit={submit} className="auth-form">
          <label>
            Email address
            <span>
              <Mail size={18} />
              <input value={email} onChange={(event) => setEmail(event.target.value)} placeholder="engineer@example.com" />
            </span>
          </label>
          <label>
            Password
            <span>
              <Lock size={18} />
              <input
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder="Minimum 6 characters"
                type="password"
              />
            </span>
          </label>
          {error && <p className="form-error">{error}</p>}
          <button className="primary-button full" type="submit">
            Sign in
          </button>
          <button className="ghost-button full" type="button" onClick={useDemo}>
            Continue with demo account
          </button>
        </form>
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
  const [level, setLevel] = useState('')
  const [departmentCode, setDepartmentCode] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const selectedDepartment = departments.find((department) => department.code === departmentCode)
  const canContinue =
    (step === 0 && firstName.trim() && lastName.trim()) ||
    (step === 1 && level) ||
    (step === 2 && departmentCode) ||
    (step === 3 && email.includes('@') && password.length >= 6 && password === confirmPassword)

  async function next() {
    if (!canContinue) return
    if (step < 3) {
      setStep((value) => value + 1)
      return
    }
    // Step 3 — create Firebase account
    setError('')
    setLoading(true)
    try {
      await registerWithEmail(email, password)
      if (!selectedDepartment) return
      saveProfile({
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
        level,
        departmentCode: selectedDepartment.code,
        departmentName: selectedDepartment.name,
      })
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
      saveProfile({
        firstName: user.displayName?.split(' ')[0] || firstName.trim() || 'User',
        lastName: user.displayName?.split(' ').slice(1).join(' ') || lastName.trim() || '',
        email: user.email || email.trim(),
        level,
        departmentCode: selectedDepartment.code,
        departmentName: selectedDepartment.name,
      })
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
        <aside className="signup-progress">
          <Logo />
          <h1>Create Account</h1>
          <p>Follow the steps to set up your web workspace.</p>
          {['Your Name', 'Your Level', 'Your Department', 'Your Credentials'].map((title, index) => (
            <div className={cx('step-row', step === index && 'active', step > index && 'done')} key={title}>
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
                  <input value={firstName} onChange={(event) => setFirstName(event.target.value)} />
                </label>
                <label>
                  Last name
                  <input value={lastName} onChange={(event) => setLastName(event.target.value)} />
                </label>
              </div>
            </StepPanel>
          )}
          {step === 1 && (
            <StepPanel icon={<GraduationCap />} title="What level are you in?">
              <div className="selection-grid">
                {levelOptions.map((item) => (
                  <button className={cx(level === item && 'selected')} key={item} onClick={() => setLevel(item)}>
                    <GraduationCap size={18} /> {item} Level
                  </button>
                ))}
              </div>
            </StepPanel>
          )}
          {step === 2 && (
            <StepPanel icon={<Building2 />} title="Which department are you in?">
              <div className="selection-grid departments">
                {departments.map((department) => (
                  <button
                    className={cx(departmentCode === department.code && 'selected')}
                    key={department.code}
                    onClick={() => setDepartmentCode(department.code)}
                  >
                    <Building2 size={18} /> {department.name}
                  </button>
                ))}
              </div>
            </StepPanel>
          )}
          {step === 3 && (
            <StepPanel icon={<Lock />} title="Last step, set up your login.">
              <label>
                Email address
                <input value={email} onChange={(event) => setEmail(event.target.value)} disabled={loading} />
              </label>
              <label>
                Create password
                <input value={password} onChange={(event) => setPassword(event.target.value)} type="password" disabled={loading} />
              </label>
              <label>
                Confirm password
                <input value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} type="password" disabled={loading} />
              </label>
              {error && <p className="form-error">{error}</p>}
            </StepPanel>
          )}
          <div className="signup-actions">
            <button className="ghost-button" disabled={step === 0 || loading} onClick={() => setStep((value) => Math.max(0, value - 1))}>
              Back
            </button>
            <button className="primary-button" disabled={!canContinue || loading} onClick={next}>
              {loading ? 'Creating account...' : step === 3 ? 'Create Account' : 'Continue'}
            </button>
          </div>
          {step === 3 && (
            <div className="auth-divider"><span>or</span></div>
          )}
          {step === 3 && (
            <button className="google-button full" type="button" onClick={handleGoogleSignUp} disabled={loading}>
              Sign up with Google
            </button>
          )}
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
          <strong>Web migration shell</strong>
          <span>React routes, live course API and local demo auth are working.</span>
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
    level: '400',
    departmentCode: 'ELE',
    departmentName: 'ELECTRICAL AND ELECTRONICS ENGINEERING',
  }
}

function RequireAuth() {
  const firebaseUser = useFirebaseUser()
  const profile = useProfile()
  const location = useLocation()

  if (firebaseUser === 'loading') {
    return <div className="page-stack narrow"><div className="loading-spinner" /></div>
  }
  if (!firebaseUser) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  // Still need profile for user metadata — redirect to register if missing
  if (!profile) return <Navigate to="/register" replace state={{ from: location.pathname }} />
  return <Outlet />
}

function AppShell() {
  const profile = useProfile()
  const navigate = useNavigate()
  const location = useLocation()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [assistantOpen, setAssistantOpen] = useState(false)
  const navItems = [
    { to: '/app', label: 'Home', icon: <Home size={22} />, end: true },
    { to: '/app/schedule', label: 'Schedule', icon: <CalendarDays size={22} /> },
    { to: '/app/hub', label: 'Hub', icon: <Layers3 size={22} /> },
    { to: '/app/study', label: 'Study', icon: <BookOpen size={22} /> },
    { to: '/app/courses', label: 'Courses', icon: <GraduationCap size={22} /> },
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
        <button className="close-mobile" onClick={() => setMobileMenuOpen(false)}>
          <X />
        </button>
        <Logo compact />
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
          <NavLink className="profile-chip" to="/app/profile">
            <CircleUserRound />
            <span>{profile?.firstName ?? 'User'}</span>
          </NavLink>
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
      <AIAssistantPanel
        context={`Route: ${location.pathname}. User: ${profile?.firstName ?? 'Student'} in ${profile?.departmentName ?? 'engineering'}.`}
        onClose={() => setAssistantOpen(false)}
        open={assistantOpen}
      />
      <button className="ai-fab" onClick={() => setAssistantOpen(true)} type="button">
        <MessageCircle size={22} />
        <span>AI Assistant</span>
      </button>
    </div>
  )
}

function AIAssistantPanel({ open, onClose, context }: { open: boolean; onClose: () => void; context: string }) {
  const [messages, setMessages] = useState<AssistantMessage[]>([
    {
      id: 'welcome',
      role: 'assistant',
      text: 'Ask for a hint, a concept explanation, quiz help, or study guidance.',
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
      const answer = await askAssistant(question, context)
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
            <Bot />
            <div>
              <p className="eyebrow">AI Assistant</p>
              <h2>Study helper</h2>
            </div>
          </div>
          <div className="assistant-actions">
            <button onClick={() => setMessages([])} title="Clear chat" type="button"><RefreshCw size={18} /></button>
            <button onClick={onClose} title="Close" type="button"><X size={18} /></button>
          </div>
        </header>
        <div className="assistant-context">{context}</div>
        <div className="assistant-messages" ref={scrollRef}>
          {messages.map((message) => (
            <article className={cx('assistant-message', message.role, message.isError && 'error')} key={message.id}>
              <span>{message.role === 'assistant' ? <Bot size={16} /> : <User size={16} />}</span>
              <p>{message.text}</p>
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

function DashboardPage() {
  const profile = useProfile()
  const courseState = useAsync(`department:${profile?.departmentCode ?? 'ELE'}`, () =>
    api.departmentCourses(profile?.departmentCode ?? 'ELE'),
  )
  const attempts = readJson<QuizAttempt[]>(ATTEMPTS_KEY, [])
  const events = readJson<EventItem[]>(EVENTS_KEY, [])

  const levelCourses = useMemo(() => {
    const courses = courseState.data?.courses ?? []
    if (!profile?.level) return courses
    return courses.filter((course) => courseLevels(course).includes(profile.level))
  }, [courseState.data?.courses, profile?.level])

  if (courseState.loading) return <LoadingState />
  if (courseState.error) return <ErrorState message={courseState.error} />

  return (
    <div className="page-stack">
      <PageHeader eyebrow="Dashboard" title={`Welcome, ${profile?.firstName ?? 'Engineer'}`}>
        <Link className="ghost-button" to="/app/courses">
          Browse courses
        </Link>
      </PageHeader>
      <section className="hero-dashboard">
        <div>
          <p className="eyebrow">{profile?.departmentName}</p>
          <h2>{profile?.level} Level learning workspace</h2>
          <p>
            The web app is now using the live Cloudflare Worker course API and a React route shell
            that replaces the Flutter navigation stack.
          </p>
          <Link to="/app/courses" className="primary-button">
            Start studying <ChevronRight size={18} />
          </Link>
        </div>
        <img src="/brand/hub.svg" alt="Vens Hub mark" />
      </section>
      <section className="metrics-grid">
        <MetricCard icon={<GraduationCap />} label="Department courses" value={courseState.data?.courses.length ?? 0} hint="From Worker API" />
        <MetricCard icon={<BookOpen />} label="Your level" value={levelCourses.length} hint="Filtered by profile" />
        <MetricCard icon={<CalendarDays />} label="Saved events" value={events.length} hint="Local schedule" />
        <MetricCard icon={<Trophy />} label="Quiz attempts" value={attempts.length} hint="Tracked in Hub" />
      </section>
      <section className="section-card">
        <div className="section-title">
          <div>
            <p className="eyebrow">Recommended</p>
            <h2>Your courses</h2>
          </div>
          <Link to="/app/courses">View all</Link>
        </div>
        {levelCourses.length === 0 ? (
          <EmptyState icon={<BookOpen />} title="No level-specific courses yet" body="Open the full course catalog while the profile mapping is completed." />
        ) : (
          <div className="course-grid">
            {levelCourses.slice(0, 6).map((course) => (
              <CourseCard course={course} key={course.code} />
            ))}
          </div>
        )}
      </section>
    </div>
  )
}

function CoursesPage() {
  const [query, setQuery] = useState('')
  const [department, setDepartment] = useState('')
  const [level, setLevel] = useState('')
  const courseState = useAsync('courses', api.courses)

  const filtered = useMemo(() => {
    const normalized = query.trim().toLowerCase()
    return (courseState.data?.courses ?? []).filter((course) => {
      const matchesQuery =
        !normalized ||
        course.code.toLowerCase().includes(normalized) ||
        course.title.toLowerCase().includes(normalized) ||
        course.description?.toLowerCase().includes(normalized)
      const matchesDepartment = !department || course.department_code === department
      const matchesLevel = !level || courseLevels(course).includes(level)
      return matchesQuery && matchesDepartment && matchesLevel
    })
  }, [courseState.data?.courses, department, level, query])

  return (
    <div className="page-stack">
      <PageHeader eyebrow="Course catalog" title="Engineering courses" />
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
          {levelOptions.map((item) => (
            <option key={item} value={item}>
              {item} Level
            </option>
          ))}
        </select>
      </section>
      {courseState.loading && <LoadingState label="Loading course catalog..." />}
      {courseState.error && <ErrorState message={courseState.error} />}
      {!courseState.loading && !courseState.error && (
        <>
          <p className="result-count">Showing {filtered.length} of {courseState.data?.courses.length ?? 0} courses</p>
          <div className="course-grid">
            {filtered.map((course) => (
              <CourseCard course={course} key={course.code} />
            ))}
          </div>
        </>
      )}
    </div>
  )
}

function CourseDetailPage() {
  const params = useParams()
  const code = decodeURIComponent(params.code ?? '')
  const courseState = useAsync(`course:${code}`, () => api.course(code))
  const questionState = useAsync(`questions:${code}`, () => api.questions(code))

  if (courseState.loading) return <LoadingState label="Loading course details..." />
  if (courseState.error) return <ErrorState message={courseState.error} />

  const course = courseState.data?.course
  if (!course) return <ErrorState message="Course was not returned by the API." />
  const outline = courseOutline(course)
  const questions = questionState.data?.questions ?? []
  const topics = Array.from(new Set(questions.map((question) => question.topic_name).filter(Boolean)))

  return (
    <div className="page-stack">
      <Link className="back-link" to="/app/courses">
        <ArrowLeft size={18} /> Back to courses
      </Link>
      <section className="course-detail-hero">
        <div>
          <p className="eyebrow">{course.department ?? course.department_code}</p>
          <h1>{course.code}: {course.title}</h1>
          <p>{course.description || 'Course information is available from the Vens Hub Worker API.'}</p>
          <div className="pill-row">
            {course.units ? <span>{course.units} units</span> : null}
            {courseLevels(course).map((item, itemIndex) => <span key={`${item}-${itemIndex}`}>{item} Level</span>)}
            {courseSemesters(course).map((item, itemIndex) => <span key={`${item}-${itemIndex}`}>{item}</span>)}
            <span>{questionState.data?.count ?? 0} questions</span>
          </div>
        </div>
        <div className="quiz-mode-actions">
          <Link className="primary-button" to={`/app/quiz/${encodeURIComponent(course.code)}?mode=mcq`}>
            Multiple choice <PlayCircle size={18} />
          </Link>
          <Link className="ghost-button" to={`/app/quiz/${encodeURIComponent(course.code)}?mode=theory`}>
            Theory mode
          </Link>
          <Link className="ghost-button" to={`/app/quiz/${encodeURIComponent(course.code)}?mode=gap`}>
            Gap-fill mode
          </Link>
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
            <div className="topic-cloud">
              {topics.slice(0, 20).map((topic) => <span key={topic}>{topic}</span>)}
            </div>
          )}
        </article>
      </section>
    </div>
  )
}

function QuizPage() {
  const params = useParams()
  const location = useLocation()
  const code = decodeURIComponent(params.code ?? '')
  const modeParam = new URLSearchParams(location.search).get('mode')
  const mode = modeParam === 'theory' ? 'theory' : modeParam === 'gap' ? 'gap' : 'mcq'
  const questionState = useAsync(`quiz-questions:${code}`, () => api.questions(code))
  const courseState = useAsync(`quiz-course:${code}`, () => api.course(code))

  const questions = useMemo(
    () => (questionState.data?.questions ?? []).filter((question) => question.question?.trim()).slice(0, 10),
    [questionState.data?.questions],
  )

  if (questionState.loading) return <LoadingState label="Preparing quiz..." />
  if (questionState.error) return <ErrorState message={questionState.error} />
  if (questions.length === 0) {
    return <EmptyState icon={<BrainCircuit />} title="No questions found" body="This course has no loaded questions in the API yet." />
  }

  const courseTitle = courseState.data?.course.title ?? code

  if (mode === 'theory') {
    return <TheoryQuizMode code={code} courseTitle={courseTitle} questions={questions} />
  }

  if (mode === 'gap') {
    return <GapFillQuizMode code={code} courseTitle={courseTitle} questions={questions} />
  }

  return <MultipleChoiceQuizMode code={code} courseTitle={courseTitle} questions={questions} />
}

function QuizCompletion({
  score,
  total,
  mode,
  onRetake,
}: {
  score: number
  total: number
  mode: string
  onRetake: () => void
}) {
  return (
    <div className="page-stack narrow">
      <section className="completion-card">
        <Trophy size={48} />
        <p className="eyebrow">{mode} complete</p>
        <h1>{score} / {total}</h1>
        <p>Your attempt has been saved to the Hub analytics page.</p>
        <div className="cta-row center">
          <button className="ghost-button" onClick={onRetake}>Retake quiz</button>
          <Link className="primary-button" to="/app/hub">View Hub</Link>
        </div>
      </section>
    </div>
  )
}

function MultipleChoiceQuizMode({ code, courseTitle, questions }: { code: string; courseTitle: string; questions: Question[] }) {
  const mcqQuestions = questions.filter((question) => questionOptions(question).length >= 2)
  const [index, setIndex] = useState(0)
  const [selected, setSelected] = useState<number | null>(null)
  const [answers, setAnswers] = useState<Array<{ selected: number; correct: number }>>([])
  const current = mcqQuestions[index]
  const finished = mcqQuestions.length > 0 && answers.length === mcqQuestions.length
  const score = answers.filter((answer) => answer.selected === answer.correct).length

  function submitAnswer() {
    if (selected === null || !current) return
    const next = [...answers, { selected, correct: answerIndex(current) }]
    setAnswers(next)
    setSelected(null)
    if (next.length < mcqQuestions.length) {
      setIndex((value) => value + 1)
    } else {
      saveQuizAttempt({
        courseCode: code,
        courseTitle,
        mode: 'multiple-choice',
        score: next.filter((answer) => answer.selected === answer.correct).length,
        total: mcqQuestions.length,
      })
    }
  }

  if (mcqQuestions.length === 0) {
    return <EmptyState icon={<BrainCircuit />} title="No multiple choice questions found" body="Try theory or gap-fill mode for this course." />
  }

  if (finished) {
    return <QuizCompletion mode="Multiple choice" onRetake={() => { setAnswers([]); setIndex(0) }} score={score} total={mcqQuestions.length} />
  }

  const options = questionOptions(current)
  return (
    <div className="page-stack narrow">
      <PageHeader eyebrow={`${code} multiple choice`} title={`Question ${index + 1} of ${mcqQuestions.length}`}>
        <span className="score-chip">Score {score}</span>
      </PageHeader>
      <section className="quiz-card">
        <div className="quiz-meta">
          <span>{current.topic_name ?? 'General'}</span>
          <span>{current.difficulty ?? 'Mixed difficulty'}</span>
        </div>
        <h2>{displayText(current.question)}</h2>
        <div className="answers-list">
          {options.map((option, optionIndex) => (
            <button
              className={cx(selected === optionIndex && 'selected')}
              key={`${option}-${optionIndex}`}
              onClick={() => setSelected(optionIndex)}
            >
              <span>{String.fromCharCode(65 + optionIndex)}</span>
              <p>{displayText(option)}</p>
            </button>
          ))}
        </div>
        <button className="primary-button full" disabled={selected === null} onClick={submitAnswer}>
          {index === mcqQuestions.length - 1 ? 'Finish quiz' : 'Next question'}
        </button>
      </section>
    </div>
  )
}

function TheoryQuizMode({ code, courseTitle, questions }: { code: string; courseTitle: string; questions: Question[] }) {
  const [index, setIndex] = useState(0)
  const [answer, setAnswer] = useState('')
  const [feedback, setFeedback] = useState<{ isCorrect: boolean; score: number; expected: string } | null>(null)
  const [results, setResults] = useState<boolean[]>([])
  const current = questions[index]
  const finished = questions.length > 0 && results.length === questions.length
  const score = results.filter(Boolean).length

  function submitTheoryAnswer() {
    if (!answer.trim() || !current) return
    const result = scoreTheoryAnswer(answer, current)
    setFeedback(result)
    const next = [...results, result.isCorrect]
    setResults(next)
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
  const finished = questions.length > 0 && results.length === questions.length
  const score = results.filter(Boolean).length

  function submitGapAnswer() {
    if (!selected) return
    const isCorrect = normalizeText(selected) === normalizeText(gap.correct)
    setFeedback(isCorrect)
    const next = [...results, isCorrect]
    setResults(next)
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

function SchedulePage() {
  const [events, setEvents] = useStoredList<EventItem>(EVENTS_KEY, [])
  const [form, setForm] = useState({ title: '', course: '', date: todayIso(), start: '09:00', end: '10:00', venue: '' })
  const todaysEvents = events.filter((event) => event.date === form.date).sort((a, b) => a.start.localeCompare(b.start))

  function addEvent(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!form.title.trim()) return
    setEvents([{ id: crypto.randomUUID(), ...form, title: form.title.trim() }, ...events])
    setForm((value) => ({ ...value, title: '', course: '', venue: '' }))
  }

  function removeEvent(id: string) {
    setEvents(events.filter((event) => event.id !== id))
  }

  return (
    <div className="page-stack">
      <PageHeader eyebrow="Planner" title="Schedule" />
      <section className="planner-grid">
        <form className="section-card event-form" onSubmit={addEvent}>
          <h2>Add Event</h2>
          <label>
            Event title
            <input value={form.title} onChange={(event) => setForm({ ...form, title: event.target.value })} placeholder="Power Systems lecture" />
          </label>
          <label>
            Course
            <input value={form.course} onChange={(event) => setForm({ ...form, course: event.target.value })} placeholder="EEE 401" />
          </label>
          <div className="three-col">
            <label>
              Date
              <input value={form.date} onChange={(event) => setForm({ ...form, date: event.target.value })} type="date" />
            </label>
            <label>
              Start
              <input value={form.start} onChange={(event) => setForm({ ...form, start: event.target.value })} type="time" />
            </label>
            <label>
              End
              <input value={form.end} onChange={(event) => setForm({ ...form, end: event.target.value })} type="time" />
            </label>
          </div>
          <label>
            Venue
            <input value={form.venue} onChange={(event) => setForm({ ...form, venue: event.target.value })} placeholder="Engineering block" />
          </label>
          <button className="primary-button full" type="submit"><Plus size={18} /> Add Event</button>
        </form>
        <section className="section-card agenda-card">
          <div className="section-title">
            <div>
              <p className="eyebrow">Agenda</p>
              <h2>{new Date(`${form.date}T00:00:00`).toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</h2>
            </div>
            <span className="score-chip">{todaysEvents.length} events</span>
          </div>
          {todaysEvents.length === 0 ? (
            <EmptyState icon={<CalendarDays />} title="No events for this date" body="Add lectures, study sessions or assignment deadlines." />
          ) : (
            <div className="timeline-list">
              {todaysEvents.map((item) => (
                <article key={item.id}>
                  <time>{item.start} - {item.end}</time>
                  <div>
                    <strong>{item.title}</strong>
                    <p>{item.course || 'Personal event'} {item.venue ? `at ${item.venue}` : ''}</p>
                  </div>
                  <button onClick={() => removeEvent(item.id)}><X size={16} /></button>
                </article>
              ))}
            </div>
          )}
        </section>
      </section>
    </div>
  )
}

function StudyPage() {
  const profile = useProfile()
  const [uploads, setUploads] = useStoredList<StudyUpload>(UPLOADS_KEY, [])
  const [query, setQuery] = useState('')
  const [isUploading, setIsUploading] = useState(false)
  const [statusMessage, setStatusMessage] = useState('')
  const filtered = uploads.filter((item) => `${item.name} ${item.subject} ${item.status ?? ''}`.toLowerCase().includes(query.toLowerCase()))

  async function onFileChange(fileList: FileList | null) {
    if (!fileList?.length) return
    setIsUploading(true)
    setStatusMessage(`Uploading ${fileList.length} file(s) through the R2 signed-upload flow...`)
    const uploaded: StudyUpload[] = []
    for (const file of Array.from(fileList)) {
      const result = await uploadStudyFile(file, profile)
      uploaded.push(result)
    }
    setUploads([...uploaded, ...uploads])
    const uploadedCount = uploaded.filter((item) => item.status === 'uploaded').length
    const pendingCount = uploaded.length - uploadedCount
    setStatusMessage(
      pendingCount
        ? `${uploadedCount} uploaded, ${pendingCount} queued as pending until the Worker R2 binding is deployed.`
        : `${uploadedCount} file(s) uploaded to R2.`,
    )
    setIsUploading(false)
  }

  function removeUpload(id: string) {
    setUploads(uploads.filter((item) => item.id !== id))
  }

  return (
    <div className="page-stack">
      <PageHeader eyebrow="Materials" title="Study Materials" />
      <section className="study-grid">
        <div className="section-card upload-drop">
          <UploadCloud size={42} />
          <h2>R2 study uploads</h2>
          <p>
            Files now go through a Worker-compatible signed upload flow: presign, PUT bytes, then finalize metadata.
            If the deployed Worker does not have the R2 binding yet, the file is clearly marked pending instead of pretending it uploaded.
          </p>
          <label className="primary-button">
            {isUploading ? 'Uploading...' : 'Choose files'}
            <input multiple onChange={(event) => onFileChange(event.target.files)} type="file" disabled={isUploading} />
          </label>
          {statusMessage && <p className="upload-status">{statusMessage}</p>}
        </div>
        <div className="section-card">
          <div className="section-title">
            <h2>Uploads</h2>
            <label className="search-box compact">
              <Search size={18} />
              <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search" />
            </label>
          </div>
          {filtered.length === 0 ? (
            <EmptyState icon={<FileText />} title="No uploads yet" body="Add PDFs, notes or textbooks for your study workspace." />
          ) : (
            <div className="file-list">
              {filtered.map((file) => (
                <article key={file.id}>
                  <FileText />
                  <div>
                    <strong>{file.name}</strong>
                    <span>{formatBytes(file.size)} saved {new Date(file.createdAt).toLocaleDateString()}</span>
                    <span className={cx('upload-badge', file.status ?? 'pending_upload')}>
                      {file.status === 'uploaded' ? 'Uploaded to R2' : file.status === 'failed' ? 'Failed' : 'Pending Worker/R2'}
                    </span>
                    {file.objectKey && <code>{file.objectKey}</code>}
                    {file.error && <small>{file.error}</small>}
                  </div>
                  <div className="file-actions">
                    {file.url && <a href={file.url} target="_blank" rel="noreferrer">Open</a>}
                    <button onClick={() => removeUpload(file.id)}><X size={16} /></button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>
      </section>
    </div>
  )
}

function HubPage() {
  const attempts = readJson<QuizAttempt[]>(ATTEMPTS_KEY, [])
  const totalAnswered = attempts.reduce((sum, attempt) => sum + attempt.total, 0)
  const totalCorrect = attempts.reduce((sum, attempt) => sum + attempt.score, 0)
  const average = totalAnswered ? Math.round((totalCorrect / totalAnswered) * 100) : 0
  const best = attempts.slice().sort((a, b) => b.score / b.total - a.score / a.total)[0]

  return (
    <div className="page-stack">
      <PageHeader eyebrow="Progress" title="Hub" />
      <section className="metrics-grid">
        <MetricCard icon={<BarChart3 />} label="Average score" value={`${average}%`} hint="Across saved attempts" />
        <MetricCard icon={<BrainCircuit />} label="Questions answered" value={totalAnswered} hint="Multiple choice mode" />
        <MetricCard icon={<Flame />} label="Study streak" value="1" hint="Demo streak active" />
        <MetricCard icon={<Target />} label="Best course" value={best?.courseCode ?? 'None'} hint={best ? `${best.score}/${best.total}` : 'Attempt a quiz'} />
      </section>
      <section className="section-card">
        <div className="section-title">
          <h2>Recent activity</h2>
          <Link to="/app/courses">Take a quiz</Link>
        </div>
        {attempts.length === 0 ? (
          <EmptyState icon={<LineChart />} title="No quiz attempts yet" body="Complete a course quiz and this hub will show performance trends." />
        ) : (
          <div className="attempt-list">
            {attempts.slice(0, 8).map((attempt) => (
              <article key={attempt.id}>
                <div>
                  <strong>{attempt.courseCode}</strong>
                  <span>{attempt.courseTitle}</span>
                </div>
                <div className="bar-track">
                  <span style={{ width: `${Math.round((attempt.score / attempt.total) * 100)}%` }} />
                </div>
                <b>{attempt.score}/{attempt.total}</b>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  )
}

function ProfilePage() {
  const navigate = useNavigate()
  const profile = useProfile()
  const [draft, setDraft] = useState<Profile>(() => profile ?? demoProfile('engineer@example.com'))

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const department = departments.find((item) => item.code === draft.departmentCode)
    saveProfile({ ...draft, departmentName: department?.name ?? draft.departmentName })
    navigate('/app')
  }

  return (
    <div className="page-stack narrow">
      <PageHeader eyebrow="Account" title="Profile" />
      <form className="section-card profile-form" onSubmit={submit}>
        <div className="two-col">
          <label>
            First name
            <input value={draft.firstName} onChange={(event) => setDraft({ ...draft, firstName: event.target.value })} />
          </label>
          <label>
            Last name
            <input value={draft.lastName} onChange={(event) => setDraft({ ...draft, lastName: event.target.value })} />
          </label>
        </div>
        <label>
          Email
          <input value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} />
        </label>
        <div className="two-col">
          <label>
            Level
            <select value={draft.level} onChange={(event) => setDraft({ ...draft, level: event.target.value })}>
              {levelOptions.map((item) => <option key={item} value={item}>{item} Level</option>)}
            </select>
          </label>
          <label>
            Department
            <select value={draft.departmentCode} onChange={(event) => setDraft({ ...draft, departmentCode: event.target.value })}>
              {departments.map((item) => <option key={item.code} value={item.code}>{item.name}</option>)}
            </select>
          </label>
        </div>
        <button className="primary-button full" type="submit">Save profile</button>
      </form>
    </div>
  )
}

function NotFoundPage() {
  return (
    <div className="page-stack narrow">
      <EmptyState icon={<AlertCircle />} title="Page not found" body="The route is not part of the React migration shell yet." />
      <Link className="primary-button" to="/app">Back home</Link>
    </div>
  )
}

function App() {
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
            <Route path="quiz/:code" element={<QuizPage />} />
            <Route path="schedule" element={<SchedulePage />} />
            <Route path="study" element={<StudyPage />} />
            <Route path="hub" element={<HubPage />} />
            <Route path="profile" element={<ProfilePage />} />
          </Route>
        </Route>
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
