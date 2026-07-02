# Design Specification — Dedicated AI Cloudflare Worker

**Date**: 2026-07-02  
**Topic**: AI Assistant Worker (`workers/ai`) using `gemma-4-31b-it`  
**Status**: Pending Review  

---

## 1. Objectives

1. **Standalone AI Worker**: Create a separate Cloudflare Worker (`workers/ai`) dedicated entirely to handling the AI study assistant queries.
2. **Model Selection**: Standardize on Google's `gemma-4-31b-it` model via the public Gemini developer API.
3. **Security & Authentication**: Secure the `/assistant` endpoint by enforcing user authentication via the `X-User-Id` header (Firebase Auth UID).
4. **Clean Frontend Integration**: Configure the React frontend to point to the new worker and pass the necessary authentication headers.

---

## 2. Architecture Overview

```
[ React Frontend (App.tsx) ]
            │
            │  POST /assistant
            │  Headers: { "X-User-Id": "<uid>" }
            ▼
[ New Cloudflare Worker (workers/ai) ]
            │
            │  POST /v1beta/models/gemma-4-31b-it:generateContent
            │  Query Param: ?key=GEMINI_API_KEY
            ▼
[ Google Gemini Developer API ]
```

---

## 3. Worker Implementation Details

### 3.1 Folder Structure

A new subproject will be created at `workers/ai`:
* `workers/ai/package.json`
* `workers/ai/wrangler.toml`
* `workers/ai/src/index.js`

### 3.2 Configuration (`workers/ai/wrangler.toml`)

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

### 3.3 Worker Entrypoint (`workers/ai/src/index.js`)

The entrypoint will handle request validation, CORS, authentication, and calling the Gemini API.

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

  const body = await request.json();
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

---

## 4. Frontend Integration (`vens-hub-web`)

### 4.1 Environment Configuration (`.env.local`)
We will set the new assistant base URL:
```env
VITE_ASSISTANT_API_BASE_URL=https://vens-hub-ai.nasurf25.workers.dev
```

### 4.2 API Call Updates (`App.tsx`)
Update `askAssistant` to pass the `X-User-Id` header derived from the active Firebase Auth user:

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

And in `AIAssistantPanel`:
```typescript
// Fetch the firebase user's UID to pass down
const firebaseUser = useFirebaseUser()
const userId = firebaseUser && firebaseUser !== 'loading' ? firebaseUser.uid : undefined
...
const answer = await askAssistant(question, context, userId)
```

---

## 5. Security & Secret Configuration

1. The API key `AIzaSyB-vNmCcR9mie0dBT1fj9CK5mHm4Na4I10` will be set as a Cloudflare Worker secret:
   ```bash
   cd workers/ai
   wrangler secret put GEMINI_API_KEY
   # input value: AIzaSyB-vNmCcR9mie0dBT1fj9CK5mHm4Na4I10
   ```
2. Locally, for testing, we will write it to `workers/ai/.dev.vars`:
   ```env
   GEMINI_API_KEY=AIzaSyB-vNmCcR9mie0dBT1fj9CK5mHm4Na4I10
   ```

---

## 6. Verification & Test Plan

1. **Local Test Script**: We will create a local test runner or validation command:
   ```bash
   # Run local wrangler server
   wrangler dev --port 8788
   
   # Query the endpoint using curl to ensure authentication requirements and response format are correct
   curl -H "X-User-Id: test-uid" -H "Content-Type: application/json" -d '{"question":"What is 2+2?"}' http://localhost:8788/assistant
   ```
2. **Key Validation Note**: During verification, we successfully tested the key `AIzaSyB-vNmCcR9mie0dBT1fj9CK5mHm4Na4I10` against both `gemini-2.5-flash` and `gemma-4-31b-it` models, and confirmed that it works perfectly and is fully authorized.

