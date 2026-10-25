import { FieldValue, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

export interface Matchable {
  uid: string;
  gender?: string;
  cherryAvatar?: string;
  lookingFor?: string;
}

/** Same match id whichever order the two people are given in, so a match can only exist once. */
export const matchIdFor = (a: string, b: string) => [a, b].sort().join('_');

/**
 * Which cherry each person sees (`prd.md > Look and Feel`): their own (boy for men, girl for
 * women, chosen at sign-up for everyone else) — except in a same-gender match, where each is random.
 */
export function assignCherries(a: Matchable, b: Matchable, coin: () => boolean): Record<string, 'boy' | 'girl'> {
  const pick = (p: Matchable): 'boy' | 'girl' => {
    if (a.gender && a.gender === b.gender) return coin() ? 'boy' : 'girl';
    if (p.cherryAvatar === 'boy' || p.cherryAvatar === 'girl') return p.cherryAvatar;
    return coin() ? 'boy' : 'girl';
  };
  return { [a.uid]: pick(a), [b.uid]: pick(b) };
}

/** When a like is answered by a like back, creates the match once. Returns the match id or null. */
export async function matchIfMutual(db: Firestore, from: string, to: string, coin = () => Math.random() < 0.5) {
  if (!from || !to || from === to) return null;
  const reverse = await db.doc(`likes/${to}_${from}`).get();
  if (!reverse.exists) return null;

  const [fromDoc, toDoc] = await Promise.all([db.doc(`users/${from}`).get(), db.doc(`users/${to}`).get()]);
  const a = { uid: from, ...(fromDoc.data() as Omit<Matchable, 'uid'>) };
  const b = { uid: to, ...(toDoc.data() as Omit<Matchable, 'uid'>) };
  if (!a.lookingFor || a.lookingFor !== b.lookingFor) return null;

  const id = matchIdFor(from, to);
  const ref = db.doc(`matches/${id}`);
  const created = await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return false;
    tx.create(ref, {
      users: [from, to].sort(),
      seenBy: [],
      cherryState: 'active',
      cherryFor: assignCherries(a, b, coin),
      humanMessagesSinceCherry: 0,
      createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (created) logger.info('New match', { id });
  return created ? id : null;
}

/**
 * A like either completes a match, or — when it's one-sided — tells the other person who liked
 * them (`prd.md > Added at Final Review`), at `users/{to}/likedBy/{from}`, readable only by them.
 * Not sent if they already passed on the liker or are looking for something different.
 */
export async function handleLike(db: Firestore, from: string, to: string, coin = () => Math.random() < 0.5) {
  if (!from || !to || from === to) return { matchId: null, told: false };
  const matchId = await matchIfMutual(db, from, to, coin);
  const [reverse, passed, fromDoc, toDoc] = await Promise.all([
    db.doc(`likes/${to}_${from}`).get(),
    db.doc(`users/${to}/passes/${from}`).get(),
    db.doc(`users/${from}`).get(),
    db.doc(`users/${to}`).get(),
  ]);
  if (reverse.exists) {
    await Promise.all([
      db.doc(`users/${to}/likedBy/${from}`).delete(),
      db.doc(`users/${from}/likedBy/${to}`).delete(),
    ]);
    return { matchId, told: false };
  }
  const sameGoal = !!fromDoc.get('lookingFor') && fromDoc.get('lookingFor') === toDoc.get('lookingFor');
  if (passed.exists || !sameGoal || !toDoc.exists) return { matchId: null, told: false };
  // Hackathon demo profiles (functions/scripts/seed-judges.mjs) like back, so a judge gets a real match.
  if (toDoc.get('demoLikesBack') === true) {
    await db.doc(`likes/${to}_${from}`).set({ from: to, to: from, createdAt: FieldValue.serverTimestamp() });
    return { matchId: null, told: false };
  }
  await db.doc(`users/${to}/likedBy/${from}`).set({ from, createdAt: FieldValue.serverTimestamp() });
  return { matchId: null, told: true };
}

export const onLikeCreated = onDocumentCreated('likes/{likeId}', async (event) => {
  const data = event.data?.data();
  if (!data) return;
  await handleLike(getFirestore(), data.from, data.to);
});
