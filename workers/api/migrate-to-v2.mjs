#!/usr/bin/env node
// migrate-to-v2.mjs
// Migrates data from vens-hub-questions → vens-hub-questions-v2 (no rag_sources)
// Uses Cloudflare D1 REST /query endpoint in batches.

const ACCOUNT_ID = 'a06481b3ed7ddcf617cc917bf38d39d4';
const OLD_DB_ID  = 'c9949c3a-09a9-4b43-b39f-b15e30c38b99';
const NEW_DB_ID  = 'fc097b23-2d08-48ec-b63a-d24e6f62190f';
const TOKEN      = process.env.CF_TOKEN;

if (!TOKEN) { console.error('CF_TOKEN env var required'); process.exit(1); }

const BASE = `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/d1/database`;

async function dbQuery(dbId, sql, params = []) {
  const res = await fetch(`${BASE}/${dbId}/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ sql, params }),
  });
  const data = await res.json();
  if (!data.success) throw new Error(`Query failed [${dbId}]: ${JSON.stringify(data.errors)}\nSQL: ${sql.slice(0, 120)}`);
  return data.result?.[0] ?? {};
}

async function queryOld(sql, params = []) {
  const r = await dbQuery(OLD_DB_ID, sql, params);
  return r.results ?? [];
}

async function execNew(sql) {
  return dbQuery(NEW_DB_ID, sql);
}

function esc(val) {
  if (val === null || val === undefined) return 'NULL';
  if (typeof val === 'number') return isFinite(val) ? String(val) : '0';
  return `'${String(val).replace(/'/g, "''")}'`;
}

// Execute multiple INSERTs as a single batched SQL string
// D1 REST /query only supports one statement per call, so we send them one by one.
// To keep it fast we parallelize within each page.
async function insertBatch(sqls) {
  // Send up to 5 in parallel
  const CONCURRENCY = 5;
  for (let i = 0; i < sqls.length; i += CONCURRENCY) {
    await Promise.all(sqls.slice(i, i + CONCURRENCY).map(sql => execNew(sql)));
  }
}

async function migrateTable({ name, fetchSql, buildInsert, batchSize = 100 }) {
  console.log(`\n=== Migrating ${name} ===`);
  const total = (await queryOld(`SELECT COUNT(*) as c FROM ${name}`))[0]?.c ?? 0;
  console.log(`  Total rows: ${total}`);
  let offset = 0;
  let migrated = 0;

  while (offset < total) {
    const rows = await queryOld(fetchSql(batchSize, offset));
    if (rows.length === 0) break;
    const sqls = rows.map(buildInsert);
    await insertBatch(sqls);
    migrated += rows.length;
    offset += batchSize;
    process.stdout.write(`  ${migrated}/${total}\r`);
  }
  console.log(`  Done: ${migrated} rows migrated`);
}

async function main() {
  console.log('Vens Hub D1 Migration: old → v2 (no rag_sources)\n');

  // ── departments ──────────────────────────────────────────────
  await migrateTable({
    name: 'departments',
    fetchSql: (limit, offset) => `SELECT * FROM departments LIMIT ${limit} OFFSET ${offset}`,
    buildInsert: (r) =>
      `INSERT OR REPLACE INTO departments (code, name, course_count, courses, question_count) VALUES (${esc(r.code)},${esc(r.name)},${esc(r.course_count)},${esc(r.courses)},${esc(r.question_count)});`,
    batchSize: 50,
  });

  // ── courses ───────────────────────────────────────────────────
  await migrateTable({
    name: 'courses',
    fetchSql: (limit, offset) => `SELECT * FROM courses LIMIT ${limit} OFFSET ${offset}`,
    buildInsert: (r) =>
      `INSERT OR REPLACE INTO courses (code,title,type,units,levels,semesters,is_elective,description,outline,offered_by_programs,department,department_code,question_count) VALUES (${esc(r.code)},${esc(r.title)},${esc(r.type)},${esc(r.units)},${esc(r.levels)},${esc(r.semesters)},${esc(r.is_elective)},${esc(r.description)},${esc(r.outline)},${esc(r.offered_by_programs)},${esc(r.department)},${esc(r.department_code)},${esc(r.question_count)});`,
    batchSize: 50,
  });

  // ── questions (no rag_sources) ────────────────────────────────
  await migrateTable({
    name: 'questions',
    fetchSql: (limit, offset) =>
      `SELECT id,course_code,course_name,department,level,semester,topic_name,subtopic_name,question_type,difficulty,difficulty_ranking,question,options,correct_answer_index,correct_answer,correct_answer_text,explanation,solution_steps,extra_metadata FROM questions LIMIT ${limit} OFFSET ${offset}`,
    buildInsert: (r) =>
      `INSERT OR IGNORE INTO questions (id,course_code,course_name,department,level,semester,topic_name,subtopic_name,question_type,difficulty,difficulty_ranking,question,options,correct_answer_index,correct_answer,correct_answer_text,explanation,solution_steps,extra_metadata) VALUES (${esc(r.id)},${esc(r.course_code)},${esc(r.course_name)},${esc(r.department)},${esc(r.level)},${esc(r.semester)},${esc(r.topic_name)},${esc(r.subtopic_name)},${esc(r.question_type)},${esc(r.difficulty)},${esc(r.difficulty_ranking)},${esc(r.question)},${esc(r.options)},${esc(r.correct_answer_index)},${esc(r.correct_answer)},${esc(r.correct_answer_text)},${esc(r.explanation)},${esc(r.solution_steps)},${esc(r.extra_metadata)});`,
    batchSize: 100,
  });

  // ── Verify counts ─────────────────────────────────────────────
  console.log('\n=== Verification ===');
  for (const tbl of ['departments','courses','questions']) {
    const r = await dbQuery(NEW_DB_ID, `SELECT COUNT(*) as c FROM ${tbl}`);
    console.log(`  ${tbl}: ${r.results?.[0]?.c} rows`);
  }
  const sizeR = await dbQuery(NEW_DB_ID, 'SELECT 1');
  const sizeMB = ((sizeR.meta?.size_after ?? 0) / 1024 / 1024).toFixed(1);
  console.log(`  DB size: ${sizeMB} MB`);
  console.log('\n✅ Migration complete!');
}

main().catch((err) => { console.error('\n❌', err.message); process.exit(1); });
