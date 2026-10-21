/** Gemini model for every Cherry call. Checked against ai.google.dev model list, Oct 2026. */
export const GEMINI_MODEL = 'gemini-3.8-flash';

/** A chat with no human message for this long counts as stalled; Cherry may offer one prompt. */
export const STUCK_MINUTES = 2;

/** If nobody answers for this long after Cherry's prompt, Cherry sends its one gentle reminder. */
export const REMINDER_MINUTES = 10;

/** Human messages that must pass after Cherry speaks before it may chime in unprompted. */
export const QUIET_AFTER_CHERRY = 3;

/** How long one Cherry action holds the per-chat lock, so two triggers can't both speak. */
export const LOCK_SECONDS = 45;

/** Recent messages Gemini sees when deciding what Cherry does. */
export const HISTORY_MESSAGES = 20;
