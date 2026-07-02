// BKT Engine — Pure Math Functions (Stateless)
// Ported from TypeScript. All values double, no I/O, no side effects.

/**
 * Default BKT parameters (hardcoded for V1).
 */
export const DEFAULT_PARAMS = {
  pLearning0: 0.15,          // Initial mastery before any attempt
  pTransition: 0.12,         // Probability of learning per opportunity
  pSlip: 0.10,               // Probability of careless error on known item
  pGuess: 0.25,              // Probability of correct guess on unknown item
  sBase: 1.0,                // Base stability in days
  sFactor: 2.0,              // Stability multiplier on correct answer
  sDecay: 0.5,               // Stability multiplier on incorrect answer
  minimumSpacingDays: 0.25,  // ~6 hours — min gap between qualified reviews
  reviewThreshold: 0.75,     // Mastery threshold for "learned" status
};

/**
 * Compute P(correct) = P(L)·(1-P(S)) + (1-P(L))·P(G)
 */
export function probabilityCorrect(masteryProb, params) {
  return masteryProb * (1 - params.pSlip) + (1 - masteryProb) * params.pGuess;
}

/**
 * Update mastery after observing correct/incorrect answer.
 * Returns posterior P(Lₙ₊₁).
 */
export function updateMastery(priorMastery, isCorrect, params) {
  let posterior;
  if (isCorrect) {
    const pCorr = probabilityCorrect(priorMastery, params);
    if (pCorr === 0) return priorMastery;
    posterior = (priorMastery * (1 - params.pSlip)) / pCorr;
  } else {
    const pWrong = priorMastery * params.pSlip + (1 - priorMastery) * (1 - params.pGuess);
    if (pWrong === 0) return priorMastery;
    posterior = (priorMastery * params.pSlip) / pWrong;
  }
  // M-step: apply learning transition
  return posterior + (1 - posterior) * params.pTransition;
}

/**
 * Compute status label from mastery probability.
 */
export function computeStatus(masteryProb, threshold) {
  return masteryProb >= threshold ? 'reviewing' : 'learning';
}

/**
 * Apply BKT update to a KC state.
 * Pure function — returns new state, never mutates input.
 */
export function applyBktUpdate(state, isCorrect, params) {
  const masteryBefore = state?.masteryProb ?? params.pLearning0;
  const masteryAfter = updateMastery(masteryBefore, isCorrect, params);

  const now = new Date().toISOString();

  const newState = {
    masteryProb: masteryAfter,
    sParameter: state?.sParameter ?? params.sBase,
    status: computeStatus(masteryAfter, params.reviewThreshold),
    totalAttempts: (state?.totalAttempts ?? 0) + 1,
    correctAttempts: (state?.correctAttempts ?? 0) + (isCorrect ? 1 : 0),
    lastAttemptAt: now,
    nextReviewDue: now,
  };

  // Status can drop back to learning if mastery falls below threshold
  if (state?.status === 'reviewing' && masteryAfter < params.reviewThreshold) {
    newState.status = 'learning';
  }

  // S update only if in reviewing status and enough time has passed
  const isReviewMode = state?.status === 'reviewing';
  if (isReviewMode && state?.lastAttemptAt) {
    const lastTime = new Date(state.lastAttemptAt).getTime();
    const elapsedDays = (Date.now() - lastTime) / (1000 * 60 * 60 * 24);
    if (elapsedDays >= params.minimumSpacingDays) {
      newState.sParameter = isCorrect
        ? state.sParameter * params.sFactor
        : state.sParameter * params.sDecay;
    }
  }

  return { newState, masteryBefore, masteryAfter };
}
