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

const likedBy = (to, from) => db.doc(`users/${to}/likedBy/${from}`).get();

test('a one-sided like tells the other person who liked them; liking back matches and clears it', async () => {
  const ivy = await person('ivy', { gender: 'Woman', cherryAvatar: 'girl', lookingFor: 'partner' });
  const jon = await person('jon', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner' });
  await like(ivy, jon);
  await settle();
  const told = await likedBy(jon, ivy);
  assert.equal(told.exists, true);
  assert.equal(told.get('from'), ivy);
  assert.equal((await likedBy(ivy, jon)).exists, false, 'the liker gets nothing');

  await like(jon, ivy);
  await settle();
  assert.equal((await matchOf(ivy, jon)).exists, true);
  assert.equal((await likedBy(jon, ivy)).exists, false, 'cleared once they match');
});

test('nobody is told about a like from someone they passed on, or who wants something else', async () => {
  const kay = await person('kay', { gender: 'Woman', cherryAvatar: 'girl', lookingFor: 'partner' });
  const leo = await person('leo', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner' });
  const max = await person('max', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'friends' });
  await db.doc(`users/${kay}/passes/${leo}`).set({ createdAt: FieldValue.serverTimestamp() });
  await like(leo, kay);
  await like(max, kay);
  await settle();
  assert.equal((await likedBy(kay, leo)).exists, false);
  assert.equal((await likedBy(kay, max)).exists, false);
});

test('a demo profile likes back, so the like becomes a match with no "liked you" notice', async () => {
  const nia = await person('nia', { gender: 'Woman', cherryAvatar: 'girl', lookingFor: 'partner' });
  const sol = await person('sol', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner', demoLikesBack: true });
  await like(nia, sol);
  await settle();
  assert.equal((await matchOf(nia, sol)).exists, true);
  assert.equal((await likedBy(sol, nia)).exists, false);
});

test('friends and partner seekers never match each other', async () => {
  const gia = await person('gia', { gender: 'Woman', cherryAvatar: 'girl', lookingFor: 'friends' });
  const hal = await person('hal', { gender: 'Man', cherryAvatar: 'boy', lookingFor: 'partner' });
  await like(gia, hal);
  await like(hal, gia);
  await settle();
  assert.equal((await matchOf(gia, hal)).exists, false);
});
