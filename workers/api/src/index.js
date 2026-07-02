// Vens Hub API — Cloudflare Worker
// Serves courses, departments, questions from D1
// + Adaptive Learning Engine (BKT-based, stateless)

import { applyBktUpdate, DEFAULT_PARAMS } from './bkt.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
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
      // ── Adaptive: Submit answer (stateless BKT) ─────────────────
      if (path === '/adaptive/submit-answer' && request.method === 'POST') {
        const body = await request.json();

        // Validate input
        if (!body.questionId || body.selectedAnswerIndex === undefined || !body.attemptId) {
          return error('questionId, selectedAnswerIndex, and attemptId required');
        }

        // Load question from D1 (has correct_answer_index, explanation, topic_name)
        const { results } = await db.prepare(
          'SELECT id, correct_answer_index, correct_answer, correct_answer_text, explanation, topic_name FROM questions WHERE id = ?'
        ).bind(body.questionId).all();

        if (results.length === 0) {
          return error('Question not found', 404);
        }

        const question = results[0];
        const isCorrect = body.selectedAnswerIndex === question.correct_answer_index;

        // Client sends their current KC state for this topic
        const topicName = question.topic_name;
        const clientState = body.kcState || null;

        // Run BKT
        const { newState, masteryBefore, masteryAfter } = applyBktUpdate(clientState, isCorrect, DEFAULT_PARAMS);

        return json({
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
          // Return the full updated state so client can cache it
          updatedKcState: newState,
        });
      }

      // ── Adaptive: Get state summary ─────────────────────────────
      // Client sends its full KC state map, server returns course-level aggregation
      if (path === '/adaptive/state' && request.method === 'POST') {
        const body = await request.json();
        const kcStates = body.kcStates || {};

        // Group topics by course and compute per-course mastery
        // For each KC key (topic_name), we need to know which course it belongs to
        // We query D1 for a batch of topic → course mappings
        const topicNames = Object.keys(kcStates);
        if (topicNames.length === 0) {
          return json({ courses: {} });
        }

        // Build placeholders for SQL IN clause
        const placeholders = topicNames.map(() => '?').join(',');
        const { results: topicCourses } = await db.prepare(
          `SELECT DISTINCT topic_name, course_code FROM questions WHERE topic_name IN (${placeholders})`
        ).bind(...topicNames).all();

        // Map topic → course_code
        const topicToCourse = {};
        for (const row of topicCourses) {
          topicToCourse[row.topic_name] = row.course_code;
        }

        // Aggregate mastery per course
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

        // Build response
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

      // ── Existing: Health ────────────────────────────────────────
      if (request.method !== 'GET') {
        return error('Method not allowed', 405);
      }

      if (path === '/health') {
        return json({ status: 'ok', db: 'vens-hub-questions' });
      }

      // ── Existing: Courses ───────────────────────────────────────
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

      // ── Existing: Departments ───────────────────────────────────
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

      // ── Existing: Questions ─────────────────────────────────────
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
