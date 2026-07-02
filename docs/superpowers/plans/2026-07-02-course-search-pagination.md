# Course Search and Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement server-side search, filtering, and pagination for the course catalog browse page.

**Architecture:** Extend the `GET /courses` endpoint on the Cloudflare Worker to accept search queries, pagination offsets, and filter parameters. Update the frontend API utility and the `CoursesPage` component to load courses page-by-page dynamically.

**Tech Stack:** React, TypeScript, Cloudflare Workers, SQLite / D1

## Global Constraints
- Target directory for Worker: `workers/api/src/index.js`
- Target directory for Web UI: `vens-hub-web/src/App.tsx`
- Search queries use case-insensitive SQL `LIKE` queries.
- Pagination is cursor (offset) based.

---

### Task 1: Extend Worker API Courses Endpoint

**Files:**
- Modify: `workers/api/src/index.js:704-710`

**Interfaces:**
- Consumes: Static database schema queries for courses.
- Produces: `GET /courses?q={q}&limit={limit}&cursor={cursor}&department={department}&level={level}` returning `{ courses: Course[], total: number, hasMore: boolean, nextCursor: number }`.

- [ ] **Step 1: Implement server-side filtering and pagination**

Update the `/courses` route handler in `workers/api/src/index.js`:

```javascript
      if (path === '/courses') {
        const url = new URL(request.url);
        const q = url.searchParams.get('q') || '';
        const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
        const cursor = parseInt(url.searchParams.get('cursor') || '0');
        const dept = url.searchParams.get('department') || '';
        const lvl = url.searchParams.get('level') || '';

        let whereClauses = [];
        const params = [];

        if (dept) {
          whereClauses.push('department_code = ?');
          params.push(dept.toUpperCase());
        }
        if (q) {
          whereClauses.push('(code LIKE ? OR title LIKE ?)');
          const like = `%${q}%`;
          params.push(like, like);
        }
        if (lvl) {
          whereClauses.push('levels LIKE ?');
          params.push(`%${lvl}%`);
        }

        const whereClause = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

        const countRow = await db.prepare(
          `SELECT COUNT(*) as total FROM courses ${whereClause}`
        ).bind(...params).first();

        const { results } = await db.prepare(
          `SELECT code, title, type, units, levels, semesters, description, department, department_code, question_count 
           FROM courses ${whereClause} 
           ORDER BY code 
           LIMIT ? OFFSET ?`
        ).bind(...params, limit, cursor).all();

        const total = countRow?.total ?? 0;
        return json({
          courses: results,
          total,
          hasMore: cursor + limit < total,
          nextCursor: cursor + limit,
        });
      }
```

- [ ] **Step 2: Verify D1 courses endpoint locally**

Assuming Wrangler dev server can run, we will run the dev server or test using static verification.
Run Wrangler test command (or manual curl test if deployed/running):
Run: `curl "http://localhost:8787/courses?limit=2&q=Calculus"` (adjust port if different).
Expected response contains:
```json
{
  "courses": [...],
  "total": ...,
  "hasMore": ...,
  "nextCursor": 2
}
```

- [ ] **Step 3: Commit Worker changes**

```bash
git add workers/api/src/index.js
git commit -m "feat: add search, filter, and pagination support to GET /courses"
```

---

### Task 2: Integrate Course Catalog Frontend

**Files:**
- Modify: `vens-hub-web/src/App.tsx:334` and `vens-hub-web/src/App.tsx:1369-1428`

**Interfaces:**
- Consumes: Extended `GET /courses` endpoint.
- Produces: Upgraded `CoursesPage` component with server-side pagination and debounced search inputs.

- [ ] **Step 1: Update API call definition**

Modify `api.courses` in `vens-hub-web/src/App.tsx`:

```typescript
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
```

- [ ] **Step 2: Update CoursesPage Component**

Replace `CoursesPage` in `vens-hub-web/src/App.tsx`:

```typescript
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
```

- [ ] **Step 3: Run web compilation and verify smoke tests**

Run verification commands:
Run: `npm run build` in `vens-hub-web` directory to make sure compilation passes without TS errors.

- [ ] **Step 4: Commit UI changes**

```bash
git add vens-hub-web/src/App.tsx
git commit -m "feat: implement server-side search and pagination in CoursesPage"
```

---

### Task 3: Interactive Topics and Subtopics Accordion Dropdown on Course Detail Page

**Files:**
- Modify: `vens-hub-web/src/App.tsx:1430-1502`
- Modify: `vens-hub-web/src/index.css`

**Interfaces:**
- Consumes: `questions` from `api.questions(code)`.
- Produces: An interactive accordion component displaying unique topics, their associated subtopics, and expandable item toggle state.

- [ ] **Step 1: Modify CourseDetailPage component and import ChevronDown**

In `vens-hub-web/src/App.tsx`, import `ChevronDown` from `'lucide-react'`:
```typescript
import {
  ...
  ChevronRight,
  ChevronDown,
  ...
} from 'lucide-react'
```

In `CourseDetailPage`, process the question topics and subtopics and define accordion state:
```typescript
  const course = courseState.data?.course
  if (!course) return <ErrorState message="Course was not returned by the API." />
  const outline = courseOutline(course)
  const questions = questionState.data?.questions ?? []
  
  // Group by topic and find unique subtopics
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

  const [expandedTopics, setExpandedTopics] = useState<Record<string, boolean>>({})

  const toggleTopic = (topicName: string) => {
    setExpandedTopics((prev) => ({
      ...prev,
      [topicName]: !prev[topicName],
    }))
  }
```

Update the JSX in `CourseDetailPage` for the "Question topics" article:
```tsx
        <article className="section-card">
          <div className="section-title">
            <h2>Question topics</h2>
          </div>
          {questionState.loading && <LoadingState label="Loading questions..." />}
          {questionState.error && <ErrorState message={questionState.error} />}
          {!questionState.loading && !questionState.error && (
            <div className="topic-dropdown-list">
              {topicsList.length === 0 ? (
                <EmptyState icon={<BrainCircuit />} title="No topics available" body="This course has no loaded topics in the API yet." />
              ) : (
                topicsList.map((topic) => {
                  const isExpanded = !!expandedTopics[topic.name]
                  return (
                    <div key={topic.name} className="topic-dropdown-item">
                      <button
                        type="button"
                        className="topic-dropdown-header"
                        onClick={() => toggleTopic(topic.name)}
                      >
                        <span className={cx("chevron-icon", isExpanded && "expanded")}>
                          {isExpanded ? <ChevronDown size={18} /> : <ChevronRight size={18} />}
                        </span>
                        <strong>{topic.name}</strong>
                        <span className="subtopic-count-badge">
                          {topic.subtopics.length} subtopic{topic.subtopics.length !== 1 ? 's' : ''}
                        </span>
                      </button>
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
```

- [ ] **Step 2: Add styles to index.css**

Add the CSS rules to the end of `vens-hub-web/src/index.css`:
```css
/* Topic Accordion Dropdowns */
.topic-dropdown-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-top: 1rem;
}

.topic-dropdown-item {
  border: 1px solid var(--line);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.4);
  overflow: hidden;
  transition: all 0.2s ease;
}

.topic-dropdown-item:hover {
  background: rgba(255, 255, 255, 0.8);
}

.topic-dropdown-header {
  width: 100%;
  background: transparent;
  border: none;
  display: flex;
  align-items: center;
  padding: 1rem;
  text-align: left;
  gap: 0.75rem;
  color: var(--ink);
  outline: none;
}

.chevron-icon {
  display: flex;
  align-items: center;
  color: var(--muted);
}

.chevron-icon.expanded {
  color: var(--primary);
}

.subtopic-count-badge {
  margin-left: auto;
  font-size: 0.8rem;
  background: var(--primary-soft);
  color: var(--primary-dark);
  padding: 0.25rem 0.6rem;
  border-radius: 12px;
  font-weight: 700;
}

.subtopic-dropdown-content {
  margin: 0;
  padding: 0 1rem 1rem 2.5rem;
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  border-top: 1px solid rgba(15, 118, 110, 0.08);
}

.subtopic-dropdown-content li {
  font-size: 0.9rem;
  color: var(--muted);
  position: relative;
}

.subtopic-dropdown-content li::before {
  content: "•";
  color: var(--primary);
  font-weight: bold;
  display: inline-block;
  width: 1em;
  margin-left: -1em;
}
```

- [ ] **Step 3: Run build and verify styling**
Run: `npm run build` in `vens-hub-web` directory to make sure compilation passes without TS errors.

- [ ] **Step 4: Commit Accordion changes**
```bash
git add vens-hub-web/src/App.tsx vens-hub-web/src/index.css
git commit -m "feat: implement interactive topics and subtopics accordion list in CourseDetailPage"
```

