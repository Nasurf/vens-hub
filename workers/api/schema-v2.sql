-- Vens Hub Questions DB v2 — rag_sources removed to stay under D1 500MB limit

CREATE TABLE IF NOT EXISTS courses (
  code TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT DEFAULT '',
  units INTEGER DEFAULT 0,
  levels TEXT DEFAULT '[]',
  semesters TEXT DEFAULT '[]',
  is_elective INTEGER DEFAULT 0,
  description TEXT DEFAULT '',
  outline TEXT DEFAULT '[]',
  offered_by_programs TEXT DEFAULT '[]',
  department TEXT DEFAULT '',
  department_code TEXT DEFAULT '',
  question_count INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS departments (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  course_count INTEGER DEFAULT 0,
  courses TEXT DEFAULT '[]',
  question_count INTEGER DEFAULT 0
);

-- questions: rag_sources column intentionally omitted
CREATE TABLE IF NOT EXISTS questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  course_code TEXT NOT NULL,
  course_name TEXT DEFAULT '',
  department TEXT DEFAULT '',
  level TEXT DEFAULT '',
  semester TEXT DEFAULT '',
  topic_name TEXT DEFAULT '',
  subtopic_name TEXT DEFAULT '',
  question_type TEXT DEFAULT '',
  difficulty TEXT DEFAULT '',
  difficulty_ranking INTEGER DEFAULT 0,
  question TEXT DEFAULT '',
  options TEXT DEFAULT '[]',
  correct_answer_index INTEGER DEFAULT 0,
  correct_answer TEXT DEFAULT '',
  correct_answer_text TEXT DEFAULT '',
  explanation TEXT DEFAULT '',
  solution_steps TEXT DEFAULT '[]',
  extra_metadata TEXT DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_questions_course_code ON questions(course_code);
CREATE INDEX IF NOT EXISTS idx_questions_topic ON questions(topic_name);

CREATE TABLE IF NOT EXISTS user_attempts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  question_id INTEGER NOT NULL,
  course_code TEXT NOT NULL,
  topic_name TEXT DEFAULT '',
  is_correct INTEGER NOT NULL,
  selected_answer_index INTEGER NOT NULL,
  elapsed_seconds INTEGER DEFAULT 0,
  mastery_before REAL DEFAULT 0.15,
  mastery_after REAL DEFAULT 0.15,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_attempts_user_course ON user_attempts(user_id, course_code);
CREATE INDEX IF NOT EXISTS idx_attempts_user_created ON user_attempts(user_id, created_at);

CREATE TABLE IF NOT EXISTS user_mastery (
  user_id TEXT NOT NULL,
  course_code TEXT NOT NULL,
  topic_name TEXT NOT NULL,
  mastery_prob REAL DEFAULT 0.15,
  s_parameter REAL DEFAULT 1.0,
  status TEXT DEFAULT 'learning',
  total_attempts INTEGER DEFAULT 0,
  correct_attempts INTEGER DEFAULT 0,
  last_attempt_at TEXT NOT NULL,
  next_review_due TEXT DEFAULT '',
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, course_code, topic_name)
);

CREATE INDEX IF NOT EXISTS idx_mastery_user ON user_mastery(user_id);

CREATE TABLE IF NOT EXISTS user_flashcard_attempts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  question_key TEXT NOT NULL,
  question_id TEXT DEFAULT '',
  course_code TEXT NOT NULL,
  course_title TEXT DEFAULT '',
  topic_name TEXT DEFAULT '',
  mode TEXT NOT NULL,
  question_text TEXT NOT NULL,
  options TEXT DEFAULT '[]',
  selected_answer_text TEXT DEFAULT '',
  selected_answer_index INTEGER,
  correct_answer_text TEXT DEFAULT '',
  correct_answer_index INTEGER,
  is_correct INTEGER NOT NULL,
  score REAL,
  explanation TEXT DEFAULT '',
  solution_steps TEXT DEFAULT '[]',
  rag_sources TEXT DEFAULT '',
  answered_at TEXT NOT NULL,
  synced_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_flashcard_attempts_user_answered ON user_flashcard_attempts(user_id, answered_at);
CREATE INDEX IF NOT EXISTS idx_flashcard_attempts_user_question ON user_flashcard_attempts(user_id, question_key);

CREATE TABLE IF NOT EXISTS user_flashcard_states (
  user_id TEXT NOT NULL,
  question_key TEXT NOT NULL,
  first_seen_at TEXT NOT NULL,
  last_answered_at TEXT NOT NULL,
  last_reviewed_at TEXT DEFAULT '',
  next_review_at TEXT NOT NULL,
  stability_days REAL DEFAULT 1,
  ease_factor REAL DEFAULT 2.3,
  repetitions INTEGER DEFAULT 0,
  lapses INTEGER DEFAULT 0,
  last_result TEXT DEFAULT 'incorrect',
  last_quality TEXT DEFAULT '',
  synced_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, question_key)
);

CREATE INDEX IF NOT EXISTS idx_flashcard_states_user_due ON user_flashcard_states(user_id, next_review_at);

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id TEXT PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  department_code TEXT NOT NULL,
  department_name TEXT NOT NULL,
  selected_courses TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
