// enum AiModel { pro, flash }

enum QuestionType { multipleChoice, practical, theory, gapFill }

enum Difficulty { easy, medium, hard }

/// 5-state memory model for the adaptive learning engine.
/// Order matters: MASTERED (0) → SECURE (1) → LEARNING (2) → FRAGILE (3) → LOST (4).
enum MemoryState {
  mastered,   // Strong memory, mastering proficiency
  secure,     // Strong memory, competent proficiency
  learning,   // Weak memory, building proficiency
  fragile,    // Fading memory, building proficiency
  lost;       // Forgotten, struggling

  String get displayName => switch (this) {
    MemoryState.mastered => 'Mastered',
    MemoryState.secure   => 'Secure',
    MemoryState.learning => 'Learning',
    MemoryState.fragile  => 'Fragile',
    MemoryState.lost     => 'Lost',
  };

  static MemoryState fromIndex(int i) => MemoryState.values[i.clamp(0, 4)];
}

/// Map Difficulty enum to numeric tier for HMM emission lookup.
int difficultyToTier(Difficulty d) => switch (d) {
  Difficulty.easy   => 0,
  Difficulty.medium => 1,
  Difficulty.hard   => 2,
};

enum AppConstantsDepartmentalCodes {
  eee,
  coe,
  bme,
  cve,
  mct,
  mee,
  chm,
  aae,
  pte,
}
