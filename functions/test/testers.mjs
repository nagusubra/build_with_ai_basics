// Finds the seeded testers and the match the real matching function made for them.
import { getAuth } from 'firebase-admin/auth';
import { setTimeout as sleep } from 'node:timers/promises';

export async function testerMatch(db) {
  const auth = getAuth();
  const one = (await auth.getUserByEmail('tester.one@bakeout.test')).uid;
  const two = (await auth.getUserByEmail('tester.two@bakeout.test')).uid;
  const matchId = [one, two].sort().join('_');
  for (let i = 0; i < 60; i++) {
    if ((await db.doc(`matches/${matchId}`).get()).exists) return { matchId, one, two, users: [one, two].sort() };
    await sleep(1000);
  }
  throw new Error('The testers never matched — is onLikeCreated running?');
}
