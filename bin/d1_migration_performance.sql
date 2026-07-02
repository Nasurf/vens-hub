-- Vens Hub: User Performance Monitoring Migration
-- Adds user_attempts and user_mastery tables for adaptive learning persistence
-- Run: wrangler d1 execute vens-hub-questions --file=bin/d1_migration_performance.sql

-- Attempt log — one row per answer submission
-- No full question data stored here — just FK references and computed BKT values
CREATE TABLE IF NOT EXISTS user_attempts (
  id TEXT PRIMARY KEY,                          -- uuid v4
  user_id TEXT NOT NULL,                         -- Firebase auth UID
  question_id INTEGER NOT NULL,                  -- FK into questions table
  course_code TEXT NOT NULL,                     -- denormalized for fast queries
  topic_name TEXT DEFAULT '',                    -- denormalized for fast queries
  is_correct INTEGER NOT NULL,                   -- 0 or 1
  selected_answer_index INTEGER NOT NULL,
  elapsed_seconds INTEGER DEFAULT 0,
  mastery_before REAL DEFAULT 0.15,
  mastery_after REAL DEFAULT 0.15,
  created_at TEXT NOT NULL                       -- ISO 8601
);

CREATE INDEX IF NOT EXISTS idx_attempts_user ON user_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_user_course ON user_attempts(user_id, course_code);
CREATE INDEX IF NOT EXISTS idx_attempts_user_topic ON user_attempts(user_id, topic_name);
CREATE INDEX IF NOT EXISTS idx_attempts_created ON user_attempts(created_at);
CREATE INDEX IF NOT EXISTS idx_attempts_user_course_created ON user_attempts(user_id, course_code, created_at);

-- Per-KC mastery state — upserted after every answer
-- Composite PK: one row per (user, course, topic)
CREATE TABLE IF NOT EXISTS user_mastery (
  user_id TEXT NOT NULL,
  course_code TEXT NOT NULL,
  topic_name TEXT NOT NULL,
  mastery_prob REAL DEFAULT 0.15,
  s_parameter REAL DEFAULT 1.0,
  status TEXT DEFAULT 'learning',                -- 'learning' | 'reviewing'
  total_attempts INTEGER DEFAULT 0,
  correct_attempts INTEGER DEFAULT 0,
  last_attempt_at TEXT NOT NULL,
  next_review_due TEXT DEFAULT '',
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, course_code, topic_name)
);

CREATE INDEX IF NOT EXISTS idx_mastery_user ON user_mastery(user_id);
CREATE INDEX IF NOT EXISTS idx_mastery_full ON user_mastery(user_id, course_code);
