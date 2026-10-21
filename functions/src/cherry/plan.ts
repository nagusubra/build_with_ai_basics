import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { cherryLeaves, readMatch } from './chat';
import { DISMISSED_GOODBYE } from './decide';
import { cherryHasLeft } from './rules';

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
