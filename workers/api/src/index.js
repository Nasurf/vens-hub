// Vens Hub API — Cloudflare Worker
// Serves courses, departments, and questions from D1

// CORS headers for Flutter app
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
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
    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS });
    }

    if (request.method !== 'GET') {
      return error('Method not allowed', 405);
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/$/, '');
    const segments = path.split('/').filter(Boolean).map(s => decodeURIComponent(s));
    const db = env.QUESTIONS_DB;

    try {
      // GET /health
      if (path === '/health') {
        return json({ status: 'ok', db: 'vens-hub-questions' });
      }

      // GET /courses
      if (path === '/courses') {
        const { results } = await db.prepare(
          'SELECT code, title, type, units, levels, semesters, description, department, department_code, question_count FROM courses ORDER BY code'
        ).all();
        return json({ courses: results });
      }

      // GET /courses/:code
      if (segments[0] === 'courses' && segments.length === 2) {
        const courseCode = decodeURIComponent(segments[1]);
        const { results } = await db.prepare(
          'SELECT * FROM courses WHERE code = ?'
        ).bind(courseCode).all();
        if (results.length === 0) {
          return error('Course not found', 404);
        }
        return json({ course: results[0] });
      }

      // GET /courses/:code/questions
      if (segments[0] === 'courses' && segments.length === 3 && segments[2] === 'questions') {
        const courseCode = segments[1];
        const { results } = await db.prepare(
          'SELECT id, topic_name, subtopic_name, question_type, difficulty, difficulty_ranking, question, options, correct_answer_index, correct_answer, correct_answer_text, explanation, solution_steps, rag_sources FROM questions WHERE course_code = ? ORDER BY topic_name, difficulty_ranking'
        ).bind(courseCode).all();
        return json({ questions: results, count: results.length });
      }

      // GET /departments
      if (path === '/departments') {
        const { results } = await db.prepare(
          'SELECT name, code, course_count FROM departments ORDER BY name'
        ).all();
        return json({ departments: results });
      }

      // GET /departments/:code/courses
      if (segments[0] === 'departments' && segments.length === 3 && segments[2] === 'courses') {
        const deptCode = segments[1].toUpperCase();
        const { results } = await db.prepare(
          'SELECT code, title, type, units, levels, description, question_count FROM courses WHERE department_code = ? ORDER BY code'
        ).bind(deptCode).all();
        return json({ courses: results });
      }

      // GET /questions/:courseCode
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
