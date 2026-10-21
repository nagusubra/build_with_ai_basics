import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { askJson, geminiKey } from '../gemini';
import { loadPeople } from '../profiles';
import { cherryLeaves, postAsCherry, readMatch, tryLock, unlock } from './chat';
import { DISMISSED_GOODBYE } from './decide';
import { confirmPlan, type ConfirmResult } from './planState';
import { CHERRY_SYSTEM, dateExtrasPrompt, dateExtrasSchema } from './prompts';
import { cherryHasLeft } from './rules';

export const DATE_GOODBYE = "It's a date! 🎉 Now it's on you two how you bake this out further! 🍒";

interface DateExtras {
  recipe: { title: string; minutes: number; ingredients: string[]; steps: string[]; allergyNote: string };
  song: { title: string; artist: string; why: string };
}

/**
 * After both confirm: recipe, then song, then goodbye, then Cherry is gone.
 * Caller holds the chat lock. Safe to retry: it only posts what isn't there yet.
 */
export async function finishDate(db: Firestore, matchId: string, apiKey: string): Promise<boolean> {
  const ref = db.doc(`matches/${matchId}`);
  const match = readMatch(await ref.get());
  if (cherryHasLeft(match) || match.datePlan?.status !== 'confirmed') return false;

  const posted = await ref.collection('messages').where('sender', '==', 'cherry').where('type', 'in', ['recipe', 'song']).get();
  const has = (type: string) => posted.docs.some((d) => d.get('type') === type && d.get('payload.planVersion') === match.datePlan!.version);

  if (!has('recipe') || !has('song')) {
    const [a, b] = await loadPeople(db, match.users);
    const extras = await askJson<DateExtras>({
      apiKey,
      system: CHERRY_SYSTEM,
      prompt: dateExtrasPrompt(a, b, match.datePlan),
      schema: dateExtrasSchema,
    });
    const version = match.datePlan.version;
    if (!has('recipe')) {
      await postAsCherry(db, matchId, `Here's your recipe for ${match.datePlan.dish} 👩‍🍳`, {
        type: 'recipe',
        payload: { ...extras.recipe, planVersion: version },
      });
    }
    if (!has('song')) {
      await postAsCherry(db, matchId, `And something to cook to 🎶`, { type: 'song', payload: { ...extras.song, planVersion: version } });
    }
  }
  await cherryLeaves(db, matchId, DATE_GOODBYE);
  return true;
}

/** One person taps Confirm on card `version`; when both have, Cherry wraps up and leaves. */
export async function confirmDate(db: Firestore, matchId: string, uid: string, version: number, apiKey: string) {
  const ref = db.doc(`matches/${matchId}`);
  const result: ConfirmResult = await db.runTransaction(async (tx) => {
    const match = readMatch(await tx.get(ref));
    if (cherryHasLeft(match)) return { ok: false, reason: 'already_confirmed' } as const;
    const outcome = confirmPlan(match.datePlan!, match.users, uid, version);
    if (outcome.ok) tx.update(ref, { datePlan: outcome.plan });
    return outcome;
  });
  if (!result.ok || !result.bothConfirmed) return result;

  // Usually free; if a decide call holds it, the every-minute timer finishes the date instead.
  if (await tryLock(db, matchId, new Date())) {
    try {
      await finishDate(db, matchId, apiKey);
    } catch (err) {
      logger.error('Finishing the date failed; the timer will retry', { matchId, err });
    } finally {
      await unlock(db, matchId).catch(() => undefined);
    }
  }
  return result;
}

export const confirmDatePlan = onCall<{ matchId?: string; version?: number }>({ secrets: [geminiKey] }, async (request) => {
  const uid = request.auth?.uid;
  const { matchId, version } = request.data ?? {};
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (!matchId || typeof version !== 'number') throw new HttpsError('invalid-argument', 'matchId and version are required.');
  const result = await confirmDate(getFirestore(), matchId, uid, version, geminiKey.value());
  if (!result.ok && result.reason === 'not_member') throw new HttpsError('permission-denied', 'Not your chat.');
  return result.ok ? { ok: true, bothConfirmed: result.bothConfirmed } : { ok: false, reason: result.reason };
});

/** Either member can ask Cherry to leave at any time (`prd.md > Cherry Leaves`). */
export const dismissCherry = onCall<{ matchId?: string }>(async (request) => {
  const uid = request.auth?.uid;
  const matchId = request.data?.matchId;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (!matchId) throw new HttpsError('invalid-argument', 'matchId is required.');

  const db = getFirestore();
  const match = readMatch(await db.doc(`matches/${matchId}`).get());
  if (!match.users.includes(uid)) throw new HttpsError('permission-denied', 'Not your chat.');
  if (!cherryHasLeft(match)) await cherryLeaves(db, matchId, DISMISSED_GOODBYE);
  return { ok: true };
});
