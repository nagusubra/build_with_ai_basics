// Runs inside `npm run check:matching` (auth, firestore, functions emulators).
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { setTimeout as sleep } from 'node:timers/promises';

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

initializeApp({ projectId: 'studio-1391080484-497cf' });
const db = getFirestore();
const run = Date.now();

async function person(name, fields) {
  const uid = `${name}_${run}`;
  await db.doc(`users/${uid}`).set({ name, onboardingComplete: true, verified: true, ...fields });
  return uid;
}
const like = (from, to) => db.doc(`likes/${from}_${to}`).set({ from, to, createdAt: FieldValue.serverTimestamp() });
const matchOf = (a, b) => db.doc(`matches/${[a, b].sort().join('_')}`).get();

async function settle() {
  await sleep(4000);
}

test('a one-sided like creates no match', async () => {
  const ana = await person('ana', { gender: 'Woman', cherryAvatar: 'girl', lookingFor: 'partner' });
  const ben = await person('ben', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner' });
  await like(ana, ben);
  await settle();
  assert.equal((await matchOf(ana, ben)).exists, false);
});

test('a mutual like creates exactly one match, each person with their own cherry', async () => {
  const cara = await person('cara', { gender: 'Woman', cherryAvatar: 'girl', lookingFor: 'partner' });
  const dev = await person('dev', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner' });
  await like(cara, dev);
  await like(dev, cara);
  await settle();
  const match = await matchOf(cara, dev);
  assert.equal(match.exists, true);
  assert.deepEqual(match.get('users'), [cara, dev].sort());
  assert.deepEqual(match.get('cherryFor'), { [cara]: 'girl', [dev]: 'boy' });
  assert.equal(match.get('cherryState'), 'active');
  const matches = await db.collection('matches').where('users', 'array-contains', cara).get();
  assert.equal(matches.size, 1);
});

test('a same-gender match gets a cherry for each person', async () => {
  const eli = await person('eli', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner' });
  const finn = await person('finn', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner' });
  await like(eli, finn);
  await like(finn, eli);
  await settle();
  const cherries = Object.values((await matchOf(eli, finn)).get('cherryFor'));
  assert.equal(cherries.length, 2);
  assert.ok(cherries.every((c) => c === 'boy' || c === 'girl'));
});

test('friends and partner seekers never match each other', async () => {
  const gia = await person('gia', { gender: 'Woman', cherryAvatar: 'girl', lookingFor: 'friends' });
  const hal = await person('hal', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner' });
  await like(gia, hal);
  await like(hal, gia);
  await settle();
  assert.equal((await matchOf(gia, hal)).exists, false);
});
