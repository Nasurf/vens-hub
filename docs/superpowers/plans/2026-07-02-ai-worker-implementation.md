# AI Assistant Dedicated Worker Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a standalone Cloudflare Worker (`workers/ai`) to proxy study assistant requests securely to Gemini using the `gemma-4-31b-it` model, and integrate it with the frontend.

**Architecture:** A new dedicated Cloudflare Worker handles `POST /assistant`, validates user identity via `X-User-Id` header, formats prompts for `gemma-4-31b-it`, and calls the public Gemini API. The frontend `AIAssistantPanel` communicates with this new worker, passing the user's UID.

**Tech Stack:** Cloudflare Workers (Wrangler), React (Vite/TS), Playwright (Smoke testing), Node.js (native test runner).

## Global Constraints

- Standalone dedicated worker at `workers/ai` using `gemma-4-31b-it`.
- Security: Require `X-User-Id` header (Firebase Auth UID) on all assistant requests.
- Environment variables: Use `GEMINI_API_KEY` and `GEMINI_MODEL`.
- Verified working key: `AIzaSyB-vNmCcR9mie0dBT1fj9CK5mHm4Na4I10`.

---

### Task 1: Scaffold & Implement AI Cloudflare Worker (`workers/ai`)

**Files:**
- Create: `workers/ai/package.json`
- Create: `workers/ai/wrangler.toml`
- Create: `workers/ai/src/index.js`
- Create: `workers/ai/test/index.test.js`

**Interfaces:**
- Consumes: User payload `{ question, context }` and header `X-User-Id`.
- Produces: JSON response `{ answer: string }`.

- [ ] **Step 1: Write the tests for the Worker**
  Create `workers/ai/test/index.test.js` using Node's native test runner to assert request routing, validation (missing header, missing body), and successful API proxying (mocking the global fetch).
  ```javascript
  import { test } from 'node:test';
  import assert from 'node:assert';
  import worker from '../src/index.js';

  test('Worker returns 401 if X-User-Id header is missing', async () => {
    const request = new Request('http://localhost/assistant', {
      method: 'POST',
      body: JSON.stringify({ question: 'Hi' }),
    });
    const env = { GEMINI_API_KEY: 'test-key' };
    const response = await worker.fetch(request, env);
    assert.strictEqual(response.status, 401);
    const data = await response.json();
    assert.match(data.error, /X-User-Id header required/);
  });

  test('Worker returns 400 if question is missing', async () => {
    const request = new Request('http://localhost/assistant', {
      method: 'POST',
      headers: { 'X-User-Id': 'user-123' },
      body: JSON.stringify({}),
    });
    const env = { GEMINI_API_KEY: 'test-key' };
    const response = await worker.fetch(request, env);
    assert.strictEqual(response.status, 400);
    const data = await response.json();
    assert.match(data.error, /question is required/);
  });
  ```

- [ ] **Step 2: Run test to verify it fails**
  Run: `node --test workers/ai/test/index.test.js`
  Expected: FAIL (Cannot find module '../src/index.js')

- [ ] **Step 3: Create package.json and wrangler.toml**
  Create `workers/ai/package.json`:
  ```json
  {
    "name": "vens-hub-ai",
    "version": "1.0.0",
    "type": "module",
    "devDependencies": {
      "wrangler": "^3.109.0"
    }
  }
  ```
  Create `workers/ai/wrangler.toml`:
  ```toml
  name = "vens-hub-ai"
  main = "src/index.js"
  compatibility_date = "2025-01-01"

  [vars]
  GEMINI_MODEL = "gemma-4-31b-it"

  [env.production]
  [env.production.vars]
  GEMINI_MODEL = "gemma-4-31b-it"
  ```

- [ ] **Step 4: Implement worker fetch handler**
  Create `workers/ai/src/index.js`:
  ```javascript
  const CORS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-User-Id',
  };

  function json(data, status = 200) {
    return new Response(JSON.stringify(data), {
      status,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  function error(msg, status = 400) {
    return json({ error: msg }, status);
  }

  async function handleAssistant(request, env) {
    const userId = request.headers.get('X-User-Id');
    if (!userId) {
      return error('X-User-Id header required', 401);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return error('Invalid JSON body', 400);
    }

    const question = String(body.question || '').trim();
    const context = String(body.context || '').trim();

    if (!question) {
      return error('question is required', 400);
    }

    const apiKey = env.GEMINI_API_KEY;
    if (!apiKey) {
      return error('GEMINI_API_KEY is not configured', 501);
    }

    const model = env.GEMINI_MODEL || 'gemma-4-31b-it';
    const systemInstruction = "You are an expert Tutor specializing in engineering and science. Explain concepts clearly, use examples, format formulas plainly, and be concise.";
    const prompt = `${context ? `Context: ${context}\n\n` : ''}Question: ${question}`;

    try {
      const geminiResp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            systemInstruction: { parts: [{ text: systemInstruction }] },
            generationConfig: {
              temperature: 0.3,
              maxOutputTokens: 2048,
            },
          }),
        }
      );

      if (!geminiResp.ok) {
        const detail = await geminiResp.text();
        return error(`Gemini API request failed: ${detail}`, geminiResp.status);
      }

      const data = await geminiResp.json();
      const answer = data.candidates?.[0]?.content?.parts?.map(part => part.text || '').join('\n').trim();

      return json({ answer: answer || 'No answer returned by model.' });
    } catch (err) {
      return error(`Internal error calling AI API: ${err.message}`, 500);
    }
  }

  export default {
    async fetch(request, env) {
      if (request.method === 'OPTIONS') {
        return new Response(null, { headers: CORS });
      }

      const url = new URL(request.url);
      if (url.pathname === '/assistant' && request.method === 'POST') {
        return handleAssistant(request, env);
      }

      return error('Not Found', 404);
    },
  };
  ```

- [ ] **Step 5: Run tests and verify they pass**
  Run: `node --test workers/ai/test/index.test.js`
  Expected: PASS

- [ ] **Step 6: Add mock API response test**
  Add mock testing for the happy path in `workers/ai/test/index.test.js`:
  ```javascript
  test('Worker successfully proxies request to Gemini API', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async (url, options) => {
      assert.match(url, /gemma-4-31b-it:generateContent/);
      assert.match(url, /key=mock-key/);
      const reqBody = JSON.parse(options.body);
      assert.strictEqual(reqBody.contents[0].parts[0].text, 'Explain gravity.');
      return new Response(JSON.stringify({
        candidates: [{ content: { parts: [{ text: 'Gravity pulls objects.' }] } }]
      }), { status: 200 });
    };

    try {
      const request = new Request('http://localhost/assistant', {
        method: 'POST',
        headers: { 'X-User-Id': 'user-123', 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: 'Explain gravity.' }),
      });
      const env = { GEMINI_API_KEY: 'mock-key', GEMINI_MODEL: 'gemma-4-31b-it' };
      const response = await worker.fetch(request, env);
      assert.strictEqual(response.status, 200);
      const data = await response.json();
      assert.strictEqual(data.answer, 'Gravity pulls objects.');
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
  ```
  Run: `node --test workers/ai/test/index.test.js`
  Expected: PASS

- [ ] **Step 7: Commit Worker code**
  ```bash
  git add workers/ai/
  git commit -m "feat(ai-worker): implement dedicated Cloudflare Worker for AI assistant"
  ```

---

### Task 2: Frontend Integration & Updates

**Files:**
- Modify: `vens-hub-web/src/App.tsx:437-454`
- Modify: `vens-hub-web/.env.local`
- Modify: `vens-hub-web/env.example`

**Interfaces:**
- Consumes: Firebase authenticated user details.
- Produces: Properly configured network headers (`X-User-Id`) to local or production AI worker.

- [ ] **Step 1: Update vens-hub-web/.env.local and env.example**
  Add the local/dev port for the AI worker to `vens-hub-web/.env.local`:
  ```env
  VITE_ASSISTANT_API_BASE_URL=http://localhost:8788
  ```
  Add `VITE_ASSISTANT_API_BASE_URL=` to `vens-hub-web/env.example`.

- [ ] **Step 2: Update askAssistant in App.tsx**
  Update `askAssistant` function to support sending the `userId` in the headers.
  Replace:
  ```typescript
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
  ```
  With:
  ```typescript
  async function askAssistant(question: string, context?: string, userId?: string) {
    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      }
      if (userId) {
        headers['X-User-Id'] = userId
      }
      const response = await fetch(`${ASSISTANT_API_BASE}/assistant`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ question, context }),
      })
      if (!response.ok) {
        const detail = await response.text()
        throw new Error(detail || `Request failed with status ${response.status}`)
      }
      const data = (await response.json()) as { answer?: string }
      return data.answer?.trim() || makeAssistantFallback(question, context)
    } catch (error) {
      console.error('AI assistant error:', error)
      return makeAssistantFallback(question, context)
    }
  }
  ```

- [ ] **Step 3: Update AIAssistantPanel usage in App.tsx**
  Derive the `userId` from the Firebase user and pass it to `askAssistant`.
  Modify:
  ```typescript
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
  ```
  To:
  ```typescript
  const firebaseUser = useFirebaseUser()
  const userId = firebaseUser && firebaseUser !== 'loading' ? firebaseUser.uid : undefined

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const question = draft.trim()
    if (!question || isLoading) return
    const userMessage: AssistantMessage = { id: crypto.randomUUID(), role: 'user', text: question }
    setMessages((items) => [...items, userMessage])
    setDraft('')
    setIsLoading(true)
    try {
      const answer = await askAssistant(question, context, userId)
  ```

- [ ] **Step 4: Commit frontend changes**
  ```bash
  git add vens-hub-web/src/App.tsx vens-hub-web/.env.local vens-hub-web/env.example
  git commit -m "feat(web): update AI assistant integration to connect to new AI worker with X-User-Id auth header"
  ```

---

### Task 3: Integration Verification

- [ ] **Step 1: Write local dev variables for the worker**
  Create `workers/ai/.dev.vars`:
  ```env
  GEMINI_API_KEY=AIzaSyB-vNmCcR9mie0dBT1fj9CK5mHm4Na4I10
  ```

- [ ] **Step 2: Run verification test suite**
  1. Start the new AI worker locally:
     Run: `npx wrangler dev --port 8788 --ip 127.0.0.1` (in background/separate terminal)
  2. Start the core API worker:
     Run: `cd workers/api && npx wrangler dev --port 8787` (in background/separate terminal)
  3. Start the Web App dev server:
     Run: `cd vens-hub-web && npm run dev` (in background/separate terminal)
  4. Run Playwright smoke test script to verify UI assistant panel makes the call successfully:
     Run: `cd vens-hub-web && node scripts/smoke.cjs`
     Expected output: "Playwright smoke passed: ..."

- [ ] **Step 3: Commit all remaining verification changes**
  ```bash
  git commit -am "test: verify AI assistant end-to-end integration via Playwright smoke tests"
  ```
