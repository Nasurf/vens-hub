// Vens Hub API — Cloudflare Worker
// Serves courses, departments, questions from D1
// + Adaptive Learning Engine (BKT-based, stateless)
// + User Performance Monitoring (attempts + mastery persistence)

import { applyBktUpdate, DEFAULT_PARAMS } from './bkt.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-User-Id',
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
        const clientState = body.kcState || null;

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

      // ── Existing: Health ─────────────────────────────────────────
      if (request.method !== 'GET') {
        return error('Method not allowed', 405);
      }

      if (path === '/health') {
        return json({ status: 'ok', db: 'vens-hub-questions' });
      }

      // ── Existing: Courses ────────────────────────────────────────
      if (path === '/courses') {
        const { results } = await db.prepare(
          'SELECT code, title, type, units, levels, semesters, description, department, department_code, question_count FROM courses ORDER BY code'
        ).all();
        return json({ courses: results });
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
        const deptCode = segments[1].toUpperCase();
        const { results } = await db.prepare(
          'SELECT code, title, type, units, levels, description, question_count FROM courses WHERE department_code = ? ORDER BY code'
        ).bind(deptCode).all();
        return json({ courses: results });
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
