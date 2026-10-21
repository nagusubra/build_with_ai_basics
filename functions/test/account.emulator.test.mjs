// Runs inside `npm run check:account` (auth, firestore, storage emulators).
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

import { deleteEverything } from '../lib/account.js';

initializeApp({ projectId: 'studio-1391080484-497cf', storageBucket: 'studio-1391080484-497cf.firebasestorage.app' });
const db = getFirestore();
const auth = getAuth();
const bucket = getStorage().bucket();

test('deleting an account removes everything belonging to it, and nothing of anyone else', async () => {
  const leaving = (await auth.createUser({ email: `leaving.${Date.now()}@bakeout.test`, password: 'bakeout-dev' })).uid;
  const staying = (await auth.createUser({ email: `staying.${Date.now()}@bakeout.test`, password: 'bakeout-dev' })).uid;
  const third = `third_${Date.now()}`;
  const matchId = [leaving, staying].sort().join('_');

  await db.doc(`users/${leaving}`).set({ name: 'Leaving', photos: [`users/${leaving}/photos/1.jpg`] });
  await db.doc(`users/${leaving}/private/account`).set({ email: 'x' });
  await db.doc(`users/${leaving}/passes/${third}`).set({ at: 1 });
  await db.doc(`users/${leaving}/recipes/r1`).set({ title: 'Soup' });
  await db.doc(`users/${staying}`).set({ name: 'Staying' });
  await db.doc(`likes/${leaving}_${staying}`).set({ from: leaving, to: staying });
  await db.doc(`likes/${staying}_${leaving}`).set({ from: staying, to: leaving });
  await db.doc(`likes/${staying}_${third}`).set({ from: staying, to: third });
  await db.doc(`matches/${matchId}`).set({ users: [leaving, staying].sort() });
  await db.doc(`matches/${matchId}/messages/m1`).set({ sender: leaving, text: 'hi' });
  await bucket.file(`users/${leaving}/photos/1.jpg`).save(Buffer.from([0xff, 0xd8]), { contentType: 'image/jpeg' });
  await bucket.file(`users/${staying}/photos/1.jpg`).save(Buffer.from([0xff, 0xd8]), { contentType: 'image/jpeg' });

  const removed = await deleteEverything(db, bucket, auth, leaving);
  assert.deepEqual(removed, { matches: 1, likes: 2 });

  assert.equal((await db.doc(`users/${leaving}`).get()).exists, false);
  for (const sub of ['private', 'passes', 'recipes']) {
    assert.equal((await db.collection(`users/${leaving}/${sub}`).get()).size, 0, `${sub} left behind`);
  }
  assert.equal((await db.doc(`matches/${matchId}`).get()).exists, false);
  assert.equal((await db.collection(`matches/${matchId}/messages`).get()).size, 0);
  assert.equal((await db.collection('likes').where('from', '==', leaving).get()).size, 0);
  assert.equal((await db.collection('likes').where('to', '==', leaving).get()).size, 0);
  const [files] = await bucket.getFiles({ prefix: `users/${leaving}/` });
  assert.equal(files.length, 0);
  await assert.rejects(auth.getUser(leaving), /no user record/i);

  assert.equal((await db.doc(`users/${staying}`).get()).exists, true, "the other person's profile stays");
  assert.equal((await db.doc(`likes/${staying}_${third}`).get()).exists, true, "unrelated likes stay");
  const [theirFiles] = await bucket.getFiles({ prefix: `users/${staying}/` });
  assert.equal(theirFiles.length, 1, "the other person's photos stay");
  await auth.getUser(staying);
});
