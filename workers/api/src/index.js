// Vens Hub API — Cloudflare Worker
// Serves courses, departments, questions from D1
// + Adaptive Learning Engine (BKT-based, stateless)
// + User Performance Monitoring (attempts + mastery persistence)

import { applyBktUpdate, DEFAULT_PARAMS } from './bkt.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-User-Id, x-vens-upload-expires, x-vens-upload-signature, x-vens-upload-size',
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

/// Extract userId from request (body > header > none)
function getUserId(request, body) {
  // Prefer X-User-Id header (set by web/flutter frontend)
  const headerUserId = request.headers.get('X-User-Id');
  if (headerUserId) return headerUserId;
  // Fallback to body field
  if (body?.userId) return body.userId;
  return null;
}

const textEncoder = new TextEncoder();

function getUploadBucket(env) {
  return env.STUDY_MATERIALS_BUCKET || env.MATERIALS_BUCKET || env.R2_BUCKET || null;
}

function safeFilename(name = 'document') {
  const cleaned = String(name).trim().replace(/[^A-Za-z0-9._-]+/g, '_').replace(/_+/g, '_');
  return cleaned || 'document';
}

function safeObjectKey(key) {
  const cleaned = String(key || '')
    .split('/')
    .map((part) => safeFilename(part))
    .filter(Boolean)
    .join('/');
  if (!cleaned || cleaned.includes('..')) return null;
  return cleaned.startsWith('users/') ? cleaned : `users/demo/${cleaned}`;
}

function publicUrlFor(env, objectKey) {
  const base = (env.R2_PUBLIC_DOMAIN || env.R2_PUBLIC_URL || 'https://files.nuesaabuad.ng').replace(/\/$/, '');
  return `${base}/${objectKey.split('/').map(encodeURIComponent).join('/')}`;
}

async function hmacHex(secret, payload) {
  const key = await crypto.subtle.importKey(
    'raw',
    textEncoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, textEncoder.encode(payload));
  return [...new Uint8Array(signature)].map((value) => value.toString(16).padStart(2, '0')).join('');
}

function signaturePayload({ objectKey, expires, contentType, sizeBytes }) {
  return `${objectKey}.${expires}.${contentType}.${sizeBytes || 0}`;
}

async function signUpload(env, payload) {
  const secret = env.UPLOAD_SIGNING_SECRET || env.R2_UPLOAD_SECRET;
  if (!secret) return null;
  return hmacHex(secret, payload);
}

async function handleUploadPresign(request, env, origin) {
  const bucket = getUploadBucket(env);
  if (!bucket) return error('R2 bucket binding STUDY_MATERIALS_BUCKET is not configured', 501);
  if (!env.UPLOAD_SIGNING_SECRET && !env.R2_UPLOAD_SECRET) {
    return error('UPLOAD_SIGNING_SECRET is not configured', 501);
  }

  const body = await request.json();
  const filename = safeFilename(body.filename || 'document.pdf');
  const contentType = body.content_type || body.contentType || 'application/octet-stream';
  const sizeBytes = Number(body.size_bytes || body.sizeBytes || 0);
  const objectKey = safeObjectKey(body.object_key || body.objectKey || `users/demo/uploads/${Date.now()}-${filename}`);
  if (!objectKey) return error('Invalid object_key');
  if (!Number.isFinite(sizeBytes) || sizeBytes < 0) return error('Invalid size_bytes');

  const expires = String(Date.now() + 10 * 60 * 1000);
  const payload = signaturePayload({ objectKey, expires, contentType, sizeBytes });
  const signature = await signUpload(env, payload);
  if (!signature) return error('Upload signing is not configured', 501);

  const uploadUrl = new URL('/uploads/direct', origin);
  uploadUrl.searchParams.set('object_key', objectKey);
  uploadUrl.searchParams.set('filename', filename);
  uploadUrl.searchParams.set('content_type', contentType);
  uploadUrl.searchParams.set('size_bytes', String(sizeBytes));

  return json({
    object_key: objectKey,
    public_url: publicUrlFor(env, objectKey),
    finalize_url: '/uploads/finalize',
    upload: {
      url: uploadUrl.toString(),
      method: 'PUT',
      headers: {
        'x-vens-upload-expires': expires,
        'x-vens-upload-signature': signature,
      },
    },
  });
}

async function verifyUploadSignature(request, env, { objectKey, contentType, sizeBytes }) {
  const expires = request.headers.get('x-vens-upload-expires') || '';
  const provided = request.headers.get('x-vens-upload-signature') || '';
  if (!expires || !provided) return false;
  if (Number(expires) < Date.now()) return false;
  const expected = await signUpload(env, signaturePayload({ objectKey, expires, contentType, sizeBytes }));
  return Boolean(expected && expected === provided);
}

async function handleDirectUpload(request, env, url) {
  const bucket = getUploadBucket(env);
  if (!bucket) return error('R2 bucket binding STUDY_MATERIALS_BUCKET is not configured', 501);
  const objectKey = safeObjectKey(url.searchParams.get('object_key'));
  if (!objectKey) return error('Invalid object_key');
  const filename = safeFilename(url.searchParams.get('filename') || objectKey.split('/').pop());
  const contentType = request.headers.get('content-type') || url.searchParams.get('content_type') || 'application/octet-stream';
  const sizeBytes = Number(url.searchParams.get('size_bytes') || request.headers.get('x-vens-upload-size') || 0);
  const verified = await verifyUploadSignature(request, env, { objectKey, contentType, sizeBytes });
  if (!verified) return error('Invalid or expired upload signature', 403);

  const put = await bucket.put(objectKey, request.body, {
    httpMetadata: {
      contentType,
      contentDisposition: `inline; filename="${filename}"`,
    },
    customMetadata: {
      original_filename: filename,
      uploaded_via: 'vens-hub-web',
    },
  });

  return json({
    object_key: objectKey,
    public_url: publicUrlFor(env, objectKey),
    etag: put?.etag,
  });
}

async function handleUploadFinalize(request, env) {
  const body = await request.json();
  const objectKey = safeObjectKey(body.object_key || body.objectKey);
  if (!objectKey) return error('Invalid object_key');
  const bucket = getUploadBucket(env);
  const head = bucket ? await bucket.head(objectKey) : null;
  return json({
    record: {
      object_key: objectKey,
      url: publicUrlFor(env, objectKey),
      size_bytes: body.size_bytes || head?.size || null,
      content_type: head?.httpMetadata?.contentType || null,
      status: head ? 'uploaded' : 'metadata_only',
      metadata: body.metadata || {},
      created_at: new Date().toISOString(),
    },
  });
}

async function handleAssistant(request, env) {
  const body = await request.json();
  const question = String(body.question || '').trim();
  const context = String(body.context || '').trim();
  if (!question) return error('question is required');
  if (!env.GEMINI_API_KEY) return error('GEMINI_API_KEY is not configured', 501);

  const model = env.GEMINI_MODEL || 'gemini-2.5-flash-lite';
  const prompt = `${context ? `Context: ${context}\n\n` : ''}Question: ${question}\n\nPlease provide a helpful, clear answer. Explain concepts clearly, use examples when helpful, format mathematical expressions plainly, and be concise but thorough.`;
  const geminiResp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(env.GEMINI_API_KEY)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.4, maxOutputTokens: 1024 },
    }),
  });

  if (!geminiResp.ok) {
    const detail = await geminiResp.text();
    return error(`Gemini request failed: ${detail}`, geminiResp.status);
  }

  const data = await geminiResp.json();
  const answer = data.candidates?.[0]?.content?.parts?.map((part) => part.text || '').join('\n').trim();
  return json({ answer: answer || 'No answer was returned by Gemini.' });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS });
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/$/, '');
    const segments = path.split('/').filter(Boolean).map(s => decodeURIComponent(s));
    const db = env.QUESTIONS_DB;

    try {
      // ── Study materials: signed Worker/R2 upload flow ─────────────
      if (path === '/uploads/presign' && request.method === 'POST') {
        return handleUploadPresign(request, env, url.origin);
      }

      if (path === '/uploads/direct' && request.method === 'PUT') {
        return handleDirectUpload(request, env, url);
      }

      if (path === '/uploads/finalize' && request.method === 'POST') {
        return handleUploadFinalize(request, env);
      }

      // ── AI assistant: Gemini-backed study helper ─────────────────
      if (path === '/assistant' && request.method === 'POST') {
        return handleAssistant(request, env);
      }

      // ── Adaptive: Submit answer (stateless BKT + persistence) ─────────
      if (path === '/adaptive/submit-answer' && request.method === 'POST') {
        const body = await request.json();

        // Validate
        if (!body.questionId || body.selectedAnswerIndex === undefined || !body.attemptId) {
          return error('questionId, selectedAnswerIndex, and attemptId required');
        }

        const userId = getUserId(request, body);

        // Dedup — check if this attempt was already processed
        const existing = await db.prepare(
          'SELECT id FROM user_attempts WHERE id = ?'
        ).bind(body.attemptId).all();

        if (existing.results.length > 0) {
          // Attempt already processed — return cached if available, else skip
          return json({ status: 'duplicate', message: 'Attempt already recorded' });
        }

        // Load question from D1
        const { results } = await db.prepare(
          'SELECT id, course_code, correct_answer_index, correct_answer, correct_answer_text, explanation, topic_name FROM questions WHERE id = ?'
        ).bind(body.questionId).all();

        if (results.length === 0) {
          return error('Question not found', 404);
        }

        const question = results[0];
        const isCorrect = body.selectedAnswerIndex === question.correct_answer_index;

        // Client sends their current KC state for this topic
        const topicName = question.topic_name;
        const courseCode = question.course_code;
        let clientState = body.kcState || null;

        // Server-side fallback: if client state is missing, load from D1
        if (!clientState && userId) {
          const { results: existingMastery } = await db.prepare(
            'SELECT mastery_prob, s_parameter, status, total_attempts, correct_attempts, last_attempt_at, next_review_due FROM user_mastery WHERE user_id = ? AND course_code = ? AND topic_name = ?'
          ).bind(userId, courseCode, topicName).all();
          if (existingMastery.length > 0) {
            const row = existingMastery[0];
            clientState = {
              masteryProb: row.mastery_prob,
              sParameter: row.s_parameter,
              status: row.status,
              totalAttempts: row.total_attempts,
              correctAttempts: row.correct_attempts,
              lastAttemptAt: row.last_attempt_at,
              nextReviewDue: row.next_review_due,
            };
          }
        }

        // Run BKT
        const { newState, masteryBefore, masteryAfter } = applyBktUpdate(clientState, isCorrect, DEFAULT_PARAMS);

        const now = new Date().toISOString();

        // Persist attempt
        const attemptId = body.attemptId; // client-generated uuid
        await db.prepare(
          `INSERT INTO user_attempts (id, user_id, question_id, course_code, topic_name, is_correct, selected_answer_index, elapsed_seconds, mastery_before, mastery_after, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
        ).bind(
          attemptId,
          userId || '',
          question.id,
          courseCode,
          topicName,
          isCorrect ? 1 : 0,
          body.selectedAnswerIndex,
          body.clientElapsedSeconds || 0,
          masteryBefore,
          masteryAfter,
          now
        ).run();

        // Upsert mastery — only if we have a userId
        if (userId) {
          await db.prepare(
            `INSERT INTO user_mastery (user_id, course_code, topic_name, mastery_prob, s_parameter, status, total_attempts, correct_attempts, last_attempt_at, next_review_due, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(user_id, course_code, topic_name) DO UPDATE SET
               mastery_prob = excluded.mastery_prob,
               s_parameter = excluded.s_parameter,
               status = excluded.status,
               total_attempts = excluded.total_attempts,
               correct_attempts = excluded.correct_attempts,
               last_attempt_at = excluded.last_attempt_at,
               next_review_due = excluded.next_review_due,
               updated_at = excluded.updated_at`
          ).bind(
            userId,
            courseCode,
            topicName,
            newState.masteryProb,
            newState.sParameter,
            newState.status,
            newState.totalAttempts,
            newState.correctAttempts,
            now,
            newState.nextReviewDue || now,
            now
          ).run();
        }

        return json({
          status: 'applied',
          isCorrect,
          correctAnswerIndex: question.correct_answer_index,
          correctAnswer: question.correct_answer,
          correctAnswerText: question.correct_answer_text,
          explanation: question.explanation || '',
          kcKey: topicName,
          masteryBefore,
          masteryAfter,
          sParameter: newState.sParameter,
          kcStatus: newState.status,
          totalAttempts: newState.totalAttempts,
          correctAttempts: newState.correctAttempts,
          updatedKcState: newState,
        });
      }

      // ── Adaptive: Batch submit (quiz completion — no D1 lookup needed) ──
      // Flutter quiz screens know topic, courseCode, and correctness locally.
      // This endpoint accepts per-topic results, runs BKT, and persists.
      if (path === '/adaptive/submit-batch' && request.method === 'POST') {
        const body = await request.json();
        const userId = getUserId(request, body);
        const results = body.results || [];

        if (!Array.isArray(results) || results.length === 0) {
          return error('results array required');
        }

        const now = new Date().toISOString();
        let applied = 0;

        for (const item of results) {
          const { topicName, courseCode, isCorrect } = item;
          if (!topicName || !courseCode) continue;

          // Load existing mastery from D1 for this user+topic
          let kcState = null;
          if (userId) {
            const { results: existing } = await db.prepare(
              'SELECT mastery_prob, s_parameter, status, total_attempts, correct_attempts, last_attempt_at, next_review_due FROM user_mastery WHERE user_id = ? AND course_code = ? AND topic_name = ?'
            ).bind(userId, courseCode, topicName).all();
            if (existing.length > 0) {
              kcState = existing[0];
              kcState.masteryProb = kcState.mastery_prob;
              kcState.sParameter = kcState.s_parameter;
              kcState.totalAttempts = kcState.total_attempts;
              kcState.correctAttempts = kcState.correct_attempts;
              kcState.lastAttemptAt = kcState.last_attempt_at;
              kcState.nextReviewDue = kcState.next_review_due;
            }
          }

          // Run BKT
          const { newState, masteryBefore, masteryAfter } = applyBktUpdate(kcState, !!isCorrect, DEFAULT_PARAMS);

          // Persist attempt record
          const attemptId = crypto.randomUUID();
          await db.prepare(
            `INSERT INTO user_attempts (id, user_id, question_id, course_code, topic_name, is_correct, selected_answer_index, elapsed_seconds, mastery_before, mastery_after, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            attemptId,
            userId || '',
            -1, // batch submissions have no specific question ID
            courseCode,
            topicName,
            isCorrect ? 1 : 0,
            -1,
            0,
            masteryBefore,
            masteryAfter,
            now
          ).run();

          // Upsert mastery
          if (userId) {
            await db.prepare(
              `INSERT INTO user_mastery (user_id, course_code, topic_name, mastery_prob, s_parameter, status, total_attempts, correct_attempts, last_attempt_at, next_review_due, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(user_id, course_code, topic_name) DO UPDATE SET
                 mastery_prob = excluded.mastery_prob,
                 s_parameter = excluded.s_parameter,
                 status = excluded.status,
                 total_attempts = excluded.total_attempts,
                 correct_attempts = excluded.correct_attempts,
                 last_attempt_at = excluded.last_attempt_at,
                 next_review_due = excluded.next_review_due,
                 updated_at = excluded.updated_at`
            ).bind(
              userId,
              courseCode,
              topicName,
              newState.masteryProb,
              newState.sParameter,
              newState.status,
              newState.totalAttempts,
              newState.correctAttempts,
              now,
              newState.nextReviewDue || now,
              now
            ).run();
          }
          applied++;
        }

        return json({ status: 'applied', count: applied });
      }

      // ── Adaptive: Get state summary ─────────────────────────────
      if (path === '/adaptive/state' && request.method === 'POST') {
        const body = await request.json();
        const kcStates = body.kcStates || {};

        const topicNames = Object.keys(kcStates);
        if (topicNames.length === 0) {
          return json({ courses: {} });
        }

        const placeholders = topicNames.map(() => '?').join(',');
        const { results: topicCourses } = await db.prepare(
          `SELECT DISTINCT topic_name, course_code FROM questions WHERE topic_name IN (${placeholders})`
        ).bind(...topicNames).all();

        const topicToCourse = {};
        for (const row of topicCourses) {
          topicToCourse[row.topic_name] = row.course_code;
        }

        const courseAgg = {};
        for (const [topic, state] of Object.entries(kcStates)) {
          const courseCode = topicToCourse[topic] || 'Unknown';
          if (!courseAgg[courseCode]) {
            courseAgg[courseCode] = { totalKcs: 0, masterySum: 0, masteredKcs: 0 };
          }
          courseAgg[courseCode].totalKcs++;
          courseAgg[courseCode].masterySum += state.masteryProb;
          if (state.masteryProb >= DEFAULT_PARAMS.reviewThreshold) {
            courseAgg[courseCode].masteredKcs++;
          }
        }

        const courses = {};
        for (const [code, agg] of Object.entries(courseAgg)) {
          courses[code] = {
            masteryAvg: Math.round((agg.masterySum / agg.totalKcs) * 100) / 100,
            totalKcs: agg.totalKcs,
            masteredKcs: agg.masteredKcs,
            status: agg.masterySum / agg.totalKcs >= DEFAULT_PARAMS.reviewThreshold ? 'reviewing' : 'learning',
          };
        }

        return json({ courses });
      }

      // ── User: Get all mastery records ────────────────────────────
      if (path === '/user/mastery' && request.method === 'GET') {
        const userId = request.headers.get('X-User-Id');
        if (!userId) return error('X-User-Id header required', 401);

        const { results } = await db.prepare(
          'SELECT topic_name, course_code, mastery_prob, s_parameter, status, total_attempts, correct_attempts, last_attempt_at, next_review_due FROM user_mastery WHERE user_id = ? ORDER BY course_code, topic_name'
        ).bind(userId).all();

        return json({ topics: results });
      }

      // ── User: Get mastery for a specific course ──────────────────
      if (segments[0] === 'user' && segments[1] === 'mastery' && segments.length === 3 && request.method === 'GET') {
        const userId = request.headers.get('X-User-Id');
        if (!userId) return error('X-User-Id header required', 401);

        const courseCode = decodeURIComponent(segments[2]);
        const { results } = await db.prepare(
          'SELECT topic_name, course_code, mastery_prob, s_parameter, status, total_attempts, correct_attempts, last_attempt_at, next_review_due FROM user_mastery WHERE user_id = ? AND course_code = ? ORDER BY topic_name'
        ).bind(userId, courseCode).all();

        // Compute aggregates
        const totalKcs = results.length;
        let masterySum = 0;
        let masteredKcs = 0;
        for (const row of results) {
          masterySum += row.mastery_prob;
          if (row.status === 'reviewing') masteredKcs++;
        }
        const avgMastery = totalKcs > 0 ? Math.round((masterySum / totalKcs) * 100) / 100 : 0;

        return json({
          courseCode,
          topics: results,
          avgMastery,
          masteredKcs,
          totalKcs,
        });
      }

      // ── User: Get course-level stats ─────────────────────────────
      if (path === '/user/stats' && request.method === 'GET') {
        const userId = request.headers.get('X-User-Id');
        if (!userId) return error('X-User-Id header required', 401);

        // Per-course aggregates from mastery table
        const { results: masteryStats } = await db.prepare(
          `SELECT course_code,
                  COUNT(*) as total_kcs,
                  SUM(CASE WHEN status = 'reviewing' THEN 1 ELSE 0 END) as mastered_kcs,
                  AVG(mastery_prob) as avg_mastery
           FROM user_mastery WHERE user_id = ? GROUP BY course_code`
        ).bind(userId).all();

        // Per-course attempt counts
        const { results: attemptStats } = await db.prepare(
          `SELECT course_code,
                  COUNT(*) as total_attempts,
                  SUM(is_correct) as correct_attempts,
                  MAX(created_at) as last_activity_at
           FROM user_attempts WHERE user_id = ? GROUP BY course_code`
        ).bind(userId).all();

        // Merge by course_code
        const attemptMap = {};
        for (const row of attemptStats) {
          attemptMap[row.course_code] = row;
        }

        const courses = {};
        for (const row of masteryStats) {
          const att = attemptMap[row.course_code] || {};
          courses[row.course_code] = {
            totalKcs: row.total_kcs,
            masteredKcs: row.mastered_kcs,
            avgMastery: Math.round((row.avg_mastery || 0) * 100) / 100,
            totalAttempts: att.total_attempts || 0,
            correctAttempts: att.correct_attempts || 0,
            lastActivityAt: att.last_activity_at || '',
          };
        }

        // Add courses with attempts but no mastery records (edge case)
        for (const row of attemptStats) {
          if (!courses[row.course_code]) {
            courses[row.course_code] = {
              totalKcs: 0,
              masteredKcs: 0,
              avgMastery: 0,
              totalAttempts: row.total_attempts,
              correctAttempts: row.correct_attempts,
              lastActivityAt: row.last_activity_at || '',
            };
          }
        }

        return json({ courses });
      }

      // ── User: Get attempt history (paginated) ────────────────────
      if (path === '/user/attempts' && request.method === 'GET') {
        const userId = request.headers.get('X-User-Id');
        if (!userId) return error('X-User-Id header required', 401);

        const courseCode = url.searchParams.get('course') || null;
        const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 200);
        const cursor = url.searchParams.get('cursor') || null;

        let sql, params;
        if (courseCode && cursor) {
          sql = `SELECT id, user_id, question_id, course_code, topic_name, is_correct, selected_answer_index, elapsed_seconds, mastery_before, mastery_after, created_at
                 FROM user_attempts
                 WHERE user_id = ? AND course_code = ? AND created_at < ?
                 ORDER BY created_at DESC LIMIT ?`;
          params = [userId, courseCode, cursor, limit];
        } else if (courseCode) {
          sql = `SELECT id, user_id, question_id, course_code, topic_name, is_correct, selected_answer_index, elapsed_seconds, mastery_before, mastery_after, created_at
                 FROM user_attempts
                 WHERE user_id = ? AND course_code = ?
                 ORDER BY created_at DESC LIMIT ?`;
          params = [userId, courseCode, limit];
        } else if (cursor) {
          sql = `SELECT id, user_id, question_id, course_code, topic_name, is_correct, selected_answer_index, elapsed_seconds, mastery_before, mastery_after, created_at
                 FROM user_attempts
                 WHERE user_id = ? AND created_at < ?
                 ORDER BY created_at DESC LIMIT ?`;
          params = [userId, cursor, limit];
        } else {
          sql = `SELECT id, user_id, question_id, course_code, topic_name, is_correct, selected_answer_index, elapsed_seconds, mastery_before, mastery_after, created_at
                 FROM user_attempts
                 WHERE user_id = ?
                 ORDER BY created_at DESC LIMIT ?`;
          params = [userId, limit];
        }

        const { results } = await db.prepare(sql).bind(...params).all();

        const nextCursor = results.length === limit ? results[results.length - 1].created_at : null;

        return json({
          attempts: results,
          nextCursor,
          limit,
        });
      }

      // ── User: Seed mastery from client cache ─────────────────────
      if (path === '/user/seed-mastery' && request.method === 'POST') {
        const body = await request.json();
        const userId = getUserId(request, body);
        if (!userId) return error('X-User-Id header or userId in body required', 401);

        const kcStates = body.kcStates || {};
        const topicKeys = Object.keys(kcStates);

        if (topicKeys.length === 0) {
          return json({ seeded: 0, message: 'No KC states to seed' });
        }

        // Map topic names to course codes via questions table
        const placeholders = topicKeys.map(() => '?').join(',');
        const { results: topicCourses } = await db.prepare(
          `SELECT DISTINCT topic_name, course_code FROM questions WHERE topic_name IN (${placeholders})`
        ).bind(...topicKeys).all();

        const topicToCourse = {};
        for (const row of topicCourses) {
          topicToCourse[row.topic_name] = row.course_code;
        }

        // Batch upsert
        const now = new Date().toISOString();
        let seeded = 0;
        for (const [topicName, state] of Object.entries(kcStates)) {
          const courseCode = topicToCourse[topicName];
          if (!courseCode) continue; // skip unmapped topics

          await db.prepare(
            `INSERT INTO user_mastery (user_id, course_code, topic_name, mastery_prob, s_parameter, status, total_attempts, correct_attempts, last_attempt_at, next_review_due, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(user_id, course_code, topic_name) DO UPDATE SET
               mastery_prob = excluded.mastery_prob,
               s_parameter = excluded.s_parameter,
               status = excluded.status,
               total_attempts = excluded.total_attempts,
               correct_attempts = excluded.correct_attempts,
               last_attempt_at = excluded.last_attempt_at,
               next_review_due = excluded.next_review_due,
               updated_at = excluded.updated_at`
          ).bind(
            userId,
            courseCode,
            topicName,
            state.masteryProb || 0.15,
            state.sParameter || 1.0,
            state.status || 'learning',
            state.totalAttempts || 0,
            state.correctAttempts || 0,
            state.lastAttemptAt || now,
            state.nextReviewDue || '',
            now
          ).run();
          seeded++;
        }

        return json({ seeded, message: `Seeded ${seeded} KC states for user ${userId}` });
      }

      // ── User Profile ───────────────────────────────────────────
      if (path === '/user/profile' && request.method === 'POST') {
        const body = await request.json();
        const userId = getUserId(request, body);
        if (!userId) return error('X-User-Id header or userId in body required', 401);

        const { firstName, lastName, email, departmentCode, departmentName, selectedCourses } = body;
        if (!firstName || !email || !departmentCode) {
          return error('firstName, email, and departmentCode are required', 400);
        }

        const safeLastName = lastName || '';
        const safeDepartmentName = departmentName || '';
        const now = new Date().toISOString();
        const coursesJson = JSON.stringify(selectedCourses || []);

        await db.prepare(`
          INSERT INTO user_profiles (user_id, first_name, last_name, email, department_code, department_name, selected_courses, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(user_id) DO UPDATE SET
            first_name = excluded.first_name,
            last_name = excluded.last_name,
            email = excluded.email,
            department_code = excluded.department_code,
            department_name = excluded.department_name,
            selected_courses = excluded.selected_courses,
            updated_at = excluded.updated_at
        `).bind(userId, firstName, safeLastName, email, departmentCode, safeDepartmentName, coursesJson, now, now).run();

        return json({ ok: true, userId });
      }

      if (path === '/user/profile' && request.method === 'GET') {
        const userId = request.headers.get('X-User-Id');
        if (!userId) return error('X-User-Id header required', 401);

        const row = await db.prepare('SELECT * FROM user_profiles WHERE user_id = ?').bind(userId).first();
        if (!row) return json({ profile: null });

        return json({
          profile: {
            firstName: row.first_name,
            lastName: row.last_name,
            email: row.email,
            departmentCode: row.department_code,
            departmentName: row.department_name,
            selectedCourses: JSON.parse(row.selected_courses || '[]'),
          }
        });
      }

      // ── Existing: Health ─────────────────────────────────────────
      if (request.method !== 'GET') {
        return error('Method not allowed', 405);
      }

      if (path === '/health') {
        return json({ status: 'ok', db: 'vens-hub-questions' });
      }

      // ── Existing: Courses ────────────────────────────────────────
      if (path === '/courses') {
        const url = new URL(request.url);
        const q = url.searchParams.get('q') || '';
        let limit = parseInt(url.searchParams.get('limit') || '20');
        if (isNaN(limit) || limit < 1) limit = 20;
        limit = Math.min(limit, 50);

        let cursor = parseInt(url.searchParams.get('cursor') || '0');
        if (isNaN(cursor) || cursor < 0) cursor = 0;

        const dept = url.searchParams.get('department') || '';
        const lvl = url.searchParams.get('level') || '';

        let whereClauses = [];
        const params = [];

        if (dept) {
          whereClauses.push('department LIKE ?');
          params.push(`%${dept}%`);
        }
        if (q) {
          whereClauses.push('title LIKE ?');
          const like = `%${q}%`;
          params.push(like);
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

      if (segments[0] === 'courses' && segments.length === 2) {
        const courseCode = decodeURIComponent(segments[1]);
        const { results } = await db.prepare(
          'SELECT * FROM courses WHERE code = ?'
        ).bind(courseCode).all();
        if (results.length === 0) return error('Course not found', 404);
        return json({ course: results[0] });
      }

      if (segments[0] === 'courses' && segments.length === 3 && segments[2] === 'questions') {
        const courseCode = segments[1];
        const { results } = await db.prepare(
          'SELECT id, topic_name, subtopic_name, question_type, difficulty, difficulty_ranking, question, options, correct_answer_index, correct_answer, correct_answer_text, explanation, solution_steps, rag_sources FROM questions WHERE course_code = ? ORDER BY topic_name, difficulty_ranking'
        ).bind(courseCode).all();
        return json({ questions: results, count: results.length });
      }

      // ── Existing: Departments ────────────────────────────────────
      if (path === '/departments') {
        const { results } = await db.prepare(
          'SELECT name, code, course_count FROM departments ORDER BY name'
        ).all();
        return json({ departments: results });
      }

      if (segments[0] === 'departments' && segments.length === 3 && segments[2] === 'courses') {
        const deptName = decodeURIComponent(segments[1]);
        const url = new URL(request.url);
        const q = url.searchParams.get('q') || '';
        let limit = parseInt(url.searchParams.get('limit') || '20');
        if (isNaN(limit) || limit < 1) limit = 20;
        limit = Math.min(limit, 50);

        let cursor = parseInt(url.searchParams.get('cursor') || '0');
        if (isNaN(cursor) || cursor < 0) cursor = 0;

        let whereClause = 'WHERE department LIKE ?';
        const params = [`%${deptName}%`];

        if (q) {
          whereClause += ' AND title LIKE ?';
          const like = `%${q}%`;
          params.push(like);
        }

        const countRow = await db.prepare(
          `SELECT COUNT(*) as total FROM courses ${whereClause}`
        ).bind(...params).first();

        const { results } = await db.prepare(
          `SELECT code, title, type, units, levels, semesters, description, question_count FROM courses ${whereClause} ORDER BY code LIMIT ? OFFSET ?`
        ).bind(...params, limit, cursor).all();

        const total = countRow?.total ?? 0;
        return json({
          courses: results,
          total,
          hasMore: cursor + limit < total,
          nextCursor: cursor + limit,
        });
      }

      // ── Existing: Questions ──────────────────────────────────────
      if (segments[0] === 'questions' && segments.length === 2) {
        const courseCode = segments[1];
        const { results } = await db.prepare(
          'SELECT id, topic_name, subtopic_name, question_type, difficulty, difficulty_ranking, question, options, correct_answer_index, correct_answer, correct_answer_text, explanation, solution_steps, rag_sources FROM questions WHERE course_code = ? ORDER BY topic_name, difficulty_ranking'
        ).bind(courseCode).all();
        return json({ questions: results, count: results.length });
      }

      // 404
      return error('Not found', 404);

    } catch (e) {
      return error(`Internal error: ${e.message}`, 500);
    }
  },
};
