// Helpers every adapter uses to build its result for one word.

export const skipped = (reason) => ({ skipped: reason });

/** A non-2xx / timeout / network error becomes a result row, not an exception. */
export const failed = (r, error = r.error) => ({ ms: r.ms, status: r.status, error });

export const found = (r, { definitions, audio = { brE: null, amE: null }, otherAudio, extra } = {}) => ({
  ms: r.ms,
  status: r.status,
  definitions,
  senseCount: definitions.length,
  audio,
  ...(otherAudio?.length ? { otherAudio } : {}),
  ...(extra ? { extra } : {}),
});
