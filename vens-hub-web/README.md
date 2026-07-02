# Vens Hub Web

React/Vite migration of the Flutter `vens_hub` app for the hackathon web target.

## Current scope

- React Router app shell matching the Flutter route map: welcome, login, register, dashboard, courses, course detail, quiz, schedule, study, hub and profile.
- Live Cloudflare Worker API integration for departments, courses and questions.
- Local demo auth/profile so the web app is usable before Firebase web keys are provided.
- Local schedule and quiz attempt analytics for demo flow.
- Study Materials uses the Worker/R2 upload contract: presign, PUT bytes, finalize metadata, with a visible pending fallback if the deployed Worker is not updated yet.
- AI Assistant overlay wired to the `/assistant` Worker endpoint with a safe client fallback while `GEMINI_API_KEY` is not configured.
- Multiple choice, theory and gap-fill quiz modes ported into the React quiz route.
- Flutter brand assets and Geist fonts copied into `public/brand`.

## Run locally

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Smoke test

With the Vite dev server running on port 5173:

```bash
npm run smoke
```

This covers register, dashboard, AI assistant fallback, study upload fallback, course search, multiple-choice, theory and gap-fill quiz entry.

## API configuration

The app defaults to:

```text
https://vens-hub-api.nasurf25.workers.dev
```

Override it with a local env file copied from `env.example`:

```bash
cp env.example .env.local
npm run dev
```

or inline:

```bash
VITE_API_BASE_URL=https://your-worker.example npm run dev
```

The upload and assistant endpoints default to `VITE_API_BASE_URL`; set `VITE_UPLOAD_API_BASE_URL` or `VITE_ASSISTANT_API_BASE_URL` only if those routes are hosted elsewhere.

## Remaining migration tasks

1. Replace local demo auth with Firebase web auth after the team provides the Firebase JS config.
2. Wire schedule CRUD to Firestore collections used by the Flutter app.
3. Deploy the updated Worker with `STUDY_MATERIALS_BUCKET`, `UPLOAD_SIGNING_SECRET`, and optional `GEMINI_API_KEY` configured.
4. Add deployment config for the chosen host.
