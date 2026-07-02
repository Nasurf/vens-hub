# Spec: Course Search, Filtering, and Pagination

Date: 2026-07-02
Topic: Course Search, Filtering, and Pagination
Status: Approved

---

## 1. Problem Statement
The "Browse Courses" page ([CoursesPage](file:///home/nasbombz/Documents/Projects/vens-hub/vens-hub-web/src/App.tsx#L1369)) currently fetches all 426 courses in a single request via the `GET /courses` endpoint and filters them client-side. This doesn't scale well, increases payload size, and ignores the backend database's capabilities. 

We need to transition this page to use server-side search, filtering, and pagination.

---

## 2. Proposed Changes

### A. Cloudflare Worker Backend (`workers/api/src/index.js`)
* Extend the `GET /courses` route:
  * Parse query parameters:
    * `q`: Search string matching course code or title (case-insensitive `LIKE`).
    * `limit`: Page limit (default `20`, maximum `50`).
    * `cursor`: Cursor offset (default `0`).
    * `department`: Department code filter.
    * `level`: Course level filter (e.g. `100`). Matches using `levels LIKE ?`.
  * Return response:
    ```json
    {
      "courses": [...],
      "total": number,
      "hasMore": boolean,
      "nextCursor": number
    }
    ```

### B. React Frontend (`vens-hub-web/src/App.tsx`)
* Update `api.courses` signature to support query parameters.
* Refactor `CoursesPage` component:
  * Maintain dynamic state for search query, department, level, and pagination cursor.
  * Use a debounced search input to avoid triggering excessive API calls.
  * Implement pagination via a "Load More" button at the bottom of the course grid.

---

## 3. Detailed Component Plan

### 1. Worker API Extension (`workers/api/src/index.js`)
We will rewrite the handler for `/courses`:
```javascript
// GET /courses
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

// Get total count
const countRow = await db.prepare(
  `SELECT COUNT(*) as total FROM courses ${whereClause}`
).bind(...params).first();
const total = countRow?.total ?? 0;

// Fetch page
const { results } = await db.prepare(
  `SELECT code, title, type, units, levels, semesters, description, department, department_code, question_count 
   FROM courses 
   ${whereClause} 
   ORDER BY code 
   LIMIT ? OFFSET ?`
).bind(...params, limit, cursor).all();

return json({
  courses: results,
  total,
  hasMore: cursor + limit < total,
  nextCursor: cursor + limit,
});
```

### 2. Frontend API Update (`vens-hub-web/src/App.tsx`)
```typescript
courses: (params: { q?: string; limit?: number; cursor?: number; department?: string; level?: string } = {}) => {
  const searchParams = new URLSearchParams();
  if (params.q) searchParams.set('q', params.q);
  if (params.limit) searchParams.set('limit', String(params.limit));
  if (params.cursor) searchParams.set('cursor', String(params.cursor));
  if (params.department) searchParams.set('department', params.department);
  if (params.level) searchParams.set('level', params.level);
  
  const queryStr = searchParams.toString();
  return fetchJson<{ courses: Course[]; total: number; hasMore: boolean; nextCursor: number }>(
    `/courses${queryStr ? `?${queryStr}` : ''}`
  );
}
```

### 3. Frontend UI Updates (`vens-hub-web/src/App.tsx` - `CoursesPage`)
We will introduce states to track loaded items, cursor, loading, errors, and debounced queries.
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
        setCourses(data.courses)
        setTotal(data.total)
        setHasMore(data.hasMore)
        setCursor(data.nextCursor)
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
        setCourses((prev) => [...prev, ...data.courses])
        setTotal(data.total)
        setHasMore(data.hasMore)
        setCursor(data.nextCursor)
        setLoading(false)
      })
      .catch((err: Error) => {
        setError(err.message)
        setLoading(false)
      })
  }

  // Render course-grid and optional "Load more" button
}
```

---

## 4. Verification Plan
1. **API correctness**: Verify with cURL that `/courses?q=calc&limit=5` returns paginated, matched items.
2. **Integration testing**: Navigate to `/app/courses`, type a search term, select a department/level, and verify list refreshes.
3. **Pagination verification**: Scroll to the bottom, click "Load More", and check that more items are appended successfully.
