import { LOCK_SECONDS, QUIET_AFTER_CHERRY, REMINDER_MINUTES, STUCK_MINUTES } from '../config';
import type { DatePlan } from './planState';

/** The parts of a match document Cherry's rules read. */
export interface MatchState {
  users: string[];
  cherryState?: 'active' | 'left';
  createdAt?: Date | null;
  lastHumanMessageAt?: Date | null;
  lastHumanBy?: string | null;
  lastCherryMessageAt?: Date | null;
  reminderSentAt?: Date | null;
  humanMessagesSinceCherry?: number;
  cherryBusyUntil?: Date | null;
  datePlan?: DatePlan;
  dateDeclinedAt?: Date | null;
  humanMessagesSinceDecline?: number;
}

const minutes = (n: number) => n * 60_000;
const after = (a?: Date | null, b?: Date | null) => !!a && (!b || a.getTime() > b.getTime());

export const cherryHasLeft = (m: MatchState) => m.cherryState === 'left';

export const lockIsFree = (m: MatchState, now: Date) => !m.cherryBusyUntil || m.cherryBusyUntil.getTime() <= now.getTime();

export const lockUntil = (now: Date) => new Date(now.getTime() + LOCK_SECONDS * 1000);

/** Names a message may use for the wingman. Jack or Jill is skipped when one of the two people has that name. */
export function wingmanWords(peopleNames: string[] = []): string[] {
  const taken = new Set(peopleNames.map((n) => n.trim().split(/\s+/)[0]?.toLowerCase()));
  return ['cherry', 'jack', 'jill'].filter((w) => w === 'cherry' || !taken.has(w));
}

/** The message could be talking to the wingman, so the people's names are worth looking up. */
export const mightNameWingman = (text: string) => /\b(jack|jill)\b/i.test(text);

export const mentionsCherry = (text: string, peopleNames: string[] = []) =>
  new RegExp(`\\b(${wingmanWords(peopleNames).join('|')})\\b`, 'i').test(text);

/** Clear requests for the wingman to go. Gemini can also decide "leave" for less direct phrasing. */
export function asksCherryToLeave(text: string, peopleNames: string[] = []): boolean {
  if (!mentionsCherry(text, peopleNames)) return false;
  return /\b(leave|go away|give us (some )?(space|privacy)|bye|you can go|we('| a)re good|take it from here)\b/i.test(text);
}

/**
 * After a human message: may Cherry even consider speaking? It stays out of a flowing
 * conversation unless someone talks to it directly.
 */
export function mayConsiderSpeaking(m: MatchState, text: string, peopleNames: string[] = []): boolean {
  if (cherryHasLeft(m)) return false;
  if (mentionsCherry(text, peopleNames)) return true;
  return (m.humanMessagesSinceCherry ?? 0) >= QUIET_AFTER_CHERRY;
}

export type TickAction = { kind: 'finish' } | { kind: 'stall' } | { kind: 'reminder'; quietUser: string | null } | null;

/**
 * Timer decision for one chat.
 * - finish: both confirmed the date but the recipe, song, or goodbye didn't go out → retry.
 * - stall: humans went quiet after their own message and Cherry hasn't spoken since → one prompt.
 * - reminder: Cherry already prompted, still nobody answered for a long while → one gentle nudge
 *   to whoever hasn't replied (or both, if nobody has said anything yet). Then Cherry waits.
 */
export function tickAction(m: MatchState, now: Date): TickAction {
  if (cherryHasLeft(m)) return null;
  if (m.datePlan?.status === 'confirmed') return { kind: 'finish' };
  const lastHuman = m.lastHumanMessageAt ?? null;
  const quietSince = lastHuman ?? m.createdAt ?? null;
  if (!quietSince) return null;
  const quietFor = now.getTime() - quietSince.getTime();

  const humansSpokeLast = !!lastHuman && after(lastHuman, m.lastCherryMessageAt);
  if (humansSpokeLast && quietFor >= minutes(STUCK_MINUTES)) return { kind: 'stall' };

  const remindedSinceQuiet = !!m.reminderSentAt && m.reminderSentAt.getTime() >= quietSince.getTime();
  if (!humansSpokeLast && !remindedSinceQuiet && quietFor >= minutes(REMINDER_MINUTES)) {
    const quietUser = m.lastHumanBy ? (m.users.find((u) => u !== m.lastHumanBy) ?? null) : null;
    return { kind: 'reminder', quietUser };
  }
  return null;
}
