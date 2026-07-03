# Vens Hub — Registration & Dashboard Implementation Plan

Generated: 2026-07-05
Branch: main
Repo: Nasurf/vens-hub

## Problem Statement

The web frontend registration flow needs 4 improvements:
1. Course selection loads everything at once — needs search, pagination, debounce
2. Course selection and credentials are crammed into one step — needs separation
3. Question count on onboarding course cards wastes DB reads — remove it
4. User profile is localStorage-only — needs atomic Worker persistence + server fallback for dashboard display

**Root cause of dashboard not showing courses/info:** The entire profile system is localStorage-only. RequireAuth redirects to /register if localStorage is empty, even with a valid Firebase account. No Worker-side user profile exists.

---

## Architecture

```
Web UI ──▶ Cloudflare Worker ──▶ D1
                │                  ├── questions
                │                  ├── courses
                │                  ├── departments
                │                  ├── user_attempts   (existing)
                │                  ├── user_mastery    (existing)
                │                  └── user_profiles   ← NEW
                │
                ├── Firebase Auth (login only)
                │
Frontend sends: { headers: { "X-User-Id": "<firebase-uid>" } }
Worker: reads userId, uses it for all profile writes + queries
```

---

## Phase 1: D1 Schema — user_profiles table

### Migration file: `bin/d1_migration_user_profiles.sql`

```sql
CREATE TABLE IF NOT EXISTS user_profiles (
  user_id TEXT PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  department_code TEXT NOT NULL,
  department_name TEXT NOT NULL,
  selected_courses TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

Apply to both local and remote D1 (`vens-hub-questions`, WEUR).

---

## Phase 2: Worker endpoints — user profile CRUD

### POST /user/profile — create/update profile (atomic UPSERT)

Headers: `X-User-Id`, `Content-Type: application/json`
Body:
```json
{
  "firstName": "string",
  "lastName": "string",
  "email": "string",
  "departmentCode": "string",
  "departmentName": "string",
  "selectedCourses": [{ "code": "MTH101", "title": "Calculus I" }]
}
```

Single `INSERT ... ON CONFLICT(user_id) DO UPDATE` — atomic, all-or-nothing.

### GET /user/profile — read profile back

Headers: `X-User-Id`
Response: `{ profile: { ... } }` or `{ profile: null }`

### Route into Worker's fetch() handler

Add alongside existing routes in `workers/api/src/index.js`.

---

## Phase 3: Worker — course search + pagination

### Extend GET /departments/:code/courses

```
GET /departments/COM/courses?q=mach&limit=20&cursor=0

Response:
{
  "courses": [...],
  "total": 78,
  "hasMore": true,
  "nextCursor": 20
}
```

Params:
- `q` (string, default ""): filters by course code or title (LIKE match)
- `limit` (int, default 20, max 50): results per page
- `cursor` (int, default 0): offset for pagination

SQL:
```sql
-- Count
SELECT COUNT(*) as total FROM courses WHERE department_code = ? [AND (code LIKE ? OR title LIKE ?)]

-- Page
SELECT * FROM courses WHERE department_code = ? [AND (code LIKE ? OR title LIKE ?)] ORDER BY code LIMIT ? OFFSET ?
```

---

## Phase 4: Frontend — profile loading from Worker

### RequireAuth server fallback

```
1. Check localStorage → if profile exists with selectedCourses, use it
2. If localStorage empty OR missing selectedCourses → call GET /user/profile with X-User-Id
3. If Worker returns profile → save to localStorage + return it
4. If Worker returns null → redirect to /register
```

### Changes to RequireAuth

- After Firebase auth confirmed, if no localStorage profile, fetch from Worker
- Worker profile gets saved to localStorage for fast subsequent access
- Dashboard reads from useProfile() (localStorage) — no changes needed there

---

## Phase 5: Frontend — registration flow improvements

### Split step 2/3 (courses → credentials)

| Step | Content |
|------|---------|
| 0 | Name |
| 1 | Department |
| 2 | Course selection (search + paginated grid, max 10) |
| 3 | Credentials (email/password + Google) |

Step indicator: `['Your Name', 'Your Department', 'Courses', 'Account']`

### Course search + debounce

- Search input above course grid, 300ms debounce
- Worker paginated endpoint (Phase 3)
- "Load more" button at bottom when hasMore is true
- Initial load: first 20 courses

### Remove question count from onboarding cards

Remove `<span>{course.question_count ?? 0} questions</span>` from course-select-meta in RegisterPage step 2.

### Atomic profile save after auth

After Firebase auth succeeds:
1. Register with Firebase Auth
2. POST /user/profile to Worker (atomic)
3. saveProfile() to localStorage (fast cache)
4. Navigate to /app

Same for Google sign-up. Both Worker + localStorage writes happen. If Worker fails, localStorage still has data — next load retries sync.

---

## Implementation Order

| Phase | What | Est. |
|-------|------|------|
| 1 | D1 migration: user_profiles table | 5 min |
| 2 | Worker: POST /user/profile + GET /user/profile | 15 min |
| 3 | Worker: extend /departments/:code/courses with search + pagination | 15 min |
| 4 | Frontend: RequireAuth server fallback | 10 min |
| 5 | Frontend: split steps (courses → credentials) | 10 min |
| 6 | Frontend: course search + debounce + "load more" | 15 min |
| 7 | Frontend: remove question count from onboarding cards | 2 min |
| 8 | Frontend: atomic profile save (Worker + localStorage) | 10 min |
| 9 | Build + verify | 5 min |

**Total: ~87 min**

---

## Key Decisions

- Worker is source of truth for user profile data
- localStorage is fast-access cache, populated from Worker on first load
- Switching browsers/devices shows same courses as long as Firebase auth is active
- Selected courses stored as JSON string in D1 (no native JSON type)
- Course search is server-side (LIKE match on code + title)
- Pagination is cursor-based (offset), not token-based
- Profile write is atomic UPSERT — all fields or nothing

---

## Files Changed

| File | What changes |
|------|-------------|
| `bin/d1_migration_user_profiles.sql` | NEW — D1 schema |
| `workers/api/src/index.js` | Add POST/GET /user/profile, extend course search |
| `vens-hub-web/src/App.tsx` | RequireAuth fallback, split steps, search, profile save |
| `vens-hub-web/src/index.css` | Course search input, load-more button styles |

---

## Edge Cases

| Case | Handling |
|------|----------|
| User clears localStorage | RequireAuth fetches from Worker, re-populates localStorage |
| User switches browser | Same — Worker has the data, Firebase auth is the identity |
| Worker profile write fails | localStorage has data, user proceeds. Next load retries |
| No courses in department | Empty state shown, credentials step still accessible |
| User selects 10 courses then tries 11 | Silently ignored (max enforced in toggleCourse) |
| Google sign-up | Same flow — Worker profile written after Firebase auth |
| Old profile without selectedCourses | RequireAuth detects missing field, fetches from Worker |
