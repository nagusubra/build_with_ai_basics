// Runs inside `npm run check:cherry` (auth, firestore, and functions emulators, real Gemini).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { before, test } from 'node:test';
import { setTimeout as sleep } from 'node:timers/promises';

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import { runCherryTick } from '../lib/cherry/tick.js';

const apiKey = readFileSync(new URL('../.secret.local', import.meta.url), 'utf8').match(/GEMINI_API_KEY=(.*)/)?.[1]?.trim();
initializeApp({ projectId: 'studio-1391080484-497cf' });
const db = getFirestore();

let matchId;
let users;
const minutesAfter = (date, min) => new Date(date.getTime() + min * 60_000);

const cherryMessages = async () =>
  (await db.collection(`matches/${matchId}/messages`).where('sender', '==', 'cherry').orderBy('createdAt').get()).docs.map((d) => d.data());

async function waitFor(check, { timeoutMs = 90_000, label }) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const value = await check();
    if (value) return value;
    await sleep(1000);
  }
  throw new Error(`Timed out waiting for ${label}`);
}

const say = (uid, text) =>
  db.collection(`matches/${matchId}/messages`).add({ sender: uid, type: 'text', text, createdAt: FieldValue.serverTimestamp() });

before(async () => {
  assert.ok(apiKey, 'Put your Gemini key in functions/.secret.local as GEMINI_API_KEY=...');
  const seeded = await db.collection('matches').where('devSample', '==', true).get();
  assert.equal(seeded.size, 1, 'expected the dev seed match');
  matchId = seeded.docs[0].id;
  users = seeded.docs[0].get('users');
});

test('Cherry opens the chat once, naming something they really share', async () => {
  const [opening] = await waitFor(async () => {
    const msgs = await cherryMessages();
    return msgs.length ? msgs : null;
  }, { label: "Cherry's opening" });
  console.log(`  opening: ${opening.text}`);
  assert.equal((await cherryMessages()).length, 1);
  assert.match(opening.text, /italian|pasta|vegetarian|lo-?fi|mexican|hour/i, 'opening should mention a real shared detail');
});

test('Cherry stays quiet while they chat happily', async () => {
  const [one, two] = users;
  const lines = [
    [one, "Ha, me obviously — my pasta has a fan club 😄"],
    [two, 'Bold claim! I make fresh pasta from scratch most Sundays'],
    [one, "Okay you might win this one. What's your go-to sauce?"],
    [two, 'Brown butter and sage, simple but so good. What about you?'],
  ];
  for (const [uid, text] of lines) {
    await say(uid, text);
    await sleep(1500);
  }
  await sleep(25_000);
  const msgs = await cherryMessages();
  assert.equal(msgs.length, 1, `Cherry spoke during a flowing chat: ${msgs.slice(1).map((m) => m.text).join(' | ')}`);
});

test('after a stall Cherry prompts once, later reminds once, then waits', async () => {
  const lastHuman = (await db.doc(`matches/${matchId}`).get()).get('lastHumanMessageAt').toDate();

  assert.deepEqual(await runCherryTick(db, apiKey, minutesAfter(lastHuman, 3)), [`${matchId}:stall`]);
  assert.deepEqual(await runCherryTick(db, apiKey, minutesAfter(lastHuman, 5)), []);
  assert.deepEqual(await runCherryTick(db, apiKey, minutesAfter(lastHuman, 11)), [`${matchId}:reminder`]);
  assert.deepEqual(await runCherryTick(db, apiKey, minutesAfter(lastHuman, 30)), []);

  const msgs = await cherryMessages();
  console.log(`  stall prompt: ${msgs[1].text}\n  reminder: ${msgs[2].text}`);
  assert.equal(msgs.length, 3);
});

test('asked to leave, Cherry says goodbye and never posts again', async () => {
  const [one, two] = users;
  await say(two, 'Thanks Cherry, you can go now 🙂');
  await waitFor(async () => (await db.doc(`matches/${matchId}`).get()).get('cherryState') === 'left', { label: 'Cherry leaving' });
  const goodbye = (await cherryMessages()).at(-1);
  assert.equal(goodbye.type, 'cherryGoodbye');
  console.log(`  goodbye: ${goodbye.text}`);

  const countAfterLeaving = (await cherryMessages()).length;
  await say(one, 'Cherry? Are you still there?');
  await sleep(12_000);
  const later = (await db.doc(`matches/${matchId}`).get()).get('lastHumanMessageAt').toDate();
  assert.deepEqual(await runCherryTick(db, apiKey, minutesAfter(later, 60)), []);
  assert.equal((await cherryMessages()).length, countAfterLeaving);
});
