# Deployment Guide

This document covers deploying the Vens Hub API to Cloudflare Workers.

## Prerequisites

1. **Node.js** (v18+)
2. **Cloudflare account** with Workers, D1, and R2 enabled
3. **Wrangler CLI** installed (`npm install -g wrangler`)

## Environment Setup

### 1. Authentication

```bash
# Login to Cloudflare
wrangler login

# Or set API token
export CLOUDFLARE_API_TOKEN=your_token_here
```

### 2. Configure Secrets (Optional)

Some features require secrets:

```bash
cd workers/api

# For AI assistant (Gemini)
wrangler secret put GEMINI_API_KEY

# For file uploads
wrangler secret put UPLOAD_SIGNING_SECRET
```

### 3. Verify Configuration

```bash
# Check wrangler.toml
cat workers/api/wrangler.toml

# Should show:
# - D1 database binding: QUESTIONS_DB
# - R2 bucket binding: STUDY_MATERIALS_BUCKET
```

## Deployment

### Quick Deploy

```bash
# From project root
./deploy.sh
```

### Manual Deploy

```bash
cd workers/api
npx wrangler deploy --env=""
```

### Deploy to Production

```bash
npx wrangler deploy --env="production"
```

## Post-Deployment Verification

### Health Check

```bash
curl https://vens-hub-api.nasurf25.workers.dev/health
# Expected: {"status":"ok","db":"vens-hub-questions"}
```

### Test Course Endpoint

```bash
curl "https://vens-hub-api.nasurf25.workers.dev/courses/AAE%20101"
# Should return course details
```

### Test Questions Endpoint

```bash
curl "https://vens-hub-api.nasurf25.workers.dev/questions/AAE%20101"
# Should return questions array
```

## Database Management

### Check Database Status

```bash
cd workers/api
npx wrangler d1 execute vens-hub-questions --remote --command "SELECT COUNT(*) FROM questions"
```

### Backfill Questions

If courses are missing questions in D1:

```bash
cd bin
python3 backfill_questions.py
```

### Remove Courses

```bash
# Edit courses.json to remove courses, then:
cd bin
python3 remove_courses.py
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `R2_PUBLIC_DOMAIN` | Public URL for uploaded files | `https://files.nuesaabuad.ng` |
| `GEMINI_MODEL` | Gemini AI model | `gemini-2.5-flash-lite` |

## Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key | Optional (for AI assistant) |
| `UPLOAD_SIGNING_SECRET` | Secret for signing upload URLs | Optional (for file uploads) |

## Troubleshooting

### "D1 database not found"

Ensure the D1 database ID in `wrangler.toml` matches your database:

```bash
wrangler d1 list
```

### "R2 bucket not found"

Create the R2 bucket:

```bash
wrangler r2 bucket create vens-hub-study-materials
```

### Worker not responding

Check worker logs:

```bash
wrangler tail
```

### Questions not appearing

Verify questions are in D1:

```bash
wrangler d1 execute vens-hub-questions --remote --command "SELECT COUNT(*) FROM questions"
```

If count is 0, run the backfill script.
