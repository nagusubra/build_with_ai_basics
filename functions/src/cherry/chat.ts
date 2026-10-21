import { FieldValue, Timestamp, type DocumentSnapshot, type Firestore } from 'firebase-admin/firestore';

import { HISTORY_MESSAGES } from '../config';
import type { Person } from '../profiles';
import { readPlan } from './planState';
import type { ChatLine } from './prompts';
import { cherryHasLeft, lockIsFree, lockUntil, type MatchState } from './rules';

export const CHERRY = 'cherry';

const toDate = (v: unknown) => (v instanceof Timestamp ? v.toDate() : null);

export function readMatch(snap: DocumentSnapshot): MatchState {
  const d = snap.data() ?? {};
  return {
    users: (d.users as string[]) ?? [],
    cherryState: d.cherryState,
    createdAt: toDate(d.createdAt),
    lastHumanMessageAt: toDate(d.lastHumanMessageAt),
    lastHumanBy: d.lastHumanBy ?? null,
    lastCherryMessageAt: toDate(d.lastCherryMessageAt),
    reminderSentAt: toDate(d.reminderSentAt),
    humanMessagesSinceCherry: d.humanMessagesSinceCherry ?? 0,
    cherryBusyUntil: toDate(d.cherryBusyUntil),
    datePlan: readPlan(d.datePlan),
    dateDeclinedAt: toDate(d.dateDeclinedAt),
    humanMessagesSinceDecline: d.humanMessagesSinceDecline ?? 0,
  };
}

/** Takes the per-chat lock if Cherry is still here and nobody else holds it. */
export async function tryLock(db: Firestore, matchId: string, now: Date): Promise<MatchState | null> {
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`matches/${matchId}`);
    const match = readMatch(await tx.get(ref));
    if (cherryHasLeft(match) || !lockIsFree(match, now)) return null;
    tx.update(ref, { cherryBusyUntil: Timestamp.fromDate(lockUntil(now)) });
    return match;
  });
}

export const unlock = (db: Firestore, matchId: string) =>
  db.doc(`matches/${matchId}`).update({ cherryBusyUntil: null });

export interface CherryPost {
  /** Fields to set on the match in the same write, e.g. the new `datePlan`. */
  matchUpdate?: Record<string, unknown>;
  /** `text`, `dateCard`, `recipe`, `song`, or `cherryGoodbye`. */
  type?: string;
  payload?: Record<string, unknown>;
}

/** Posts as Cherry — unless Cherry has left in the meantime. Returns whether it posted. */
export async function postAsCherry(db: Firestore, matchId: string, text: string, post: CherryPost = {}): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`matches/${matchId}`);
    if (cherryHasLeft(readMatch(await tx.get(ref)))) return false;
    tx.set(ref.collection('messages').doc(), {
      sender: CHERRY,
      type: post.type ?? 'text',
      text,
      ...(post.payload && { payload: post.payload }),
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(ref, {
      lastCherryMessageAt: FieldValue.serverTimestamp(),
      lastMessageBy: CHERRY,
      humanMessagesSinceCherry: 0,
      ...post.matchUpdate,
    });
    return true;
  });
}

/** Posts Cherry's goodbye and marks Cherry gone for good. */
export async function cherryLeaves(db: Firestore, matchId: string, goodbye: string): Promise<void> {
  await postAsCherry(db, matchId, goodbye, { type: 'cherryGoodbye' });
  await db.doc(`matches/${matchId}`).update({ cherryState: 'left', cherryBusyUntil: null });
}

/** How a message reads in the transcript Gemini sees, including Cherry's cards. */
function transcriptText(type: string, text: string, payload: Record<string, unknown> | undefined): string {
  if (type === 'dateCard' && payload) {
    return `${text} [Date card v${payload.version}: ${payload.dish} on ${payload.day} at ${payload.time}]`.trim();
  }
  if (type === 'recipe' && payload) return `[Shared the recipe: ${payload.title}]`;
  if (type === 'song' && payload) return `[Suggested the song: ${payload.title} by ${payload.artist}]`;
  return text;
}

export async function recentHistory(db: Firestore, matchId: string, people: Person[]): Promise<ChatLine[]> {
  const snap = await db
    .collection(`matches/${matchId}/messages`)
    .orderBy('createdAt', 'desc')
    .limit(HISTORY_MESSAGES)
    .get();
  const names = new Map(people.map((p) => [p.uid, p.name]));
  return snap.docs
    .reverse()
    .map((d) => ({
      from: d.get('sender') === CHERRY ? 'Cherry' : (names.get(d.get('sender')) ?? 'Someone'),
      text: transcriptText(d.get('type') ?? 'text', (d.get('text') as string) ?? '', d.get('payload')),
    }));
}
