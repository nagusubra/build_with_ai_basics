// Runs inside `npm run check:date` (auth, firestore, and functions emulators, real Gemini).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { before, test } from 'node:test';
import { setTimeout as sleep } from 'node:timers/promises';

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import { confirmDate } from '../lib/cherry/plan.js';
import { runCherryTick } from '../lib/cherry/tick.js';

const apiKey = readFileSync(new URL('../.secret.local', import.meta.url), 'utf8').match(/GEMINI_API_KEY=(.*)/)?.[1]?.trim();
initializeApp({ projectId: 'studio-1391080484-497cf' });
const db = getFirestore();

let matchId;
let one;
let two;

const matchDoc = async () => (await db.doc(`matches/${matchId}`).get()).data();
const cherry = async () =>
  (await db.collection(`matches/${matchId}/messages`).where('sender', '==', 'cherry').orderBy('createdAt').get()).docs.map((d) => d.data());
const say = (uid, text) =>
  db.collection(`matches/${matchId}/messages`).add({ sender: uid, type: 'text', text, createdAt: FieldValue.serverTimestamp() });

async function waitFor(check, label, timeoutMs = 90_000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const v = await check();
    if (v) return v;
    await sleep(1000);
  }
  throw new Error(`Timed out waiting for ${label}`);
}

const cherryCountAbove = (n) => async () => ((await cherry()).length > n ? (await cherry()).at(-1) : null);

before(async () => {
  assert.ok(apiKey, 'Put your Gemini key in functions/.secret.local as GEMINI_API_KEY=...');
  const seeded = (await db.collection('matches').where('devSample', '==', true).get()).docs[0];
  matchId = seeded.id;
  const users = seeded.get('users');
  const names = await Promise.all(users.map(async (u) => (await db.doc(`users/${u}`).get()).get('name')));
  one = users[names.indexOf('Tester One')];
  two = users[names.indexOf('Tester Two')];
  await waitFor(cherryCountAbove(0), "Cherry's opening");
});

test('"not ready" makes Cherry back off without a card', async () => {
  const before = (await cherry()).length;
  await say(one, 'Ha! Mine is a big bowl of pasta arrabbiata 🍝');
  await sleep(1500);
  await say(two, "Cherry, honestly I'm not ready to plan a date yet — I'm just enjoying chatting for now 🙂");
  const reply = await waitFor(cherryCountAbove(before), "Cherry's reply to not-ready");
  console.log(`  backed off: ${reply.text}`);
  const m = await matchDoc();
  assert.ok(m.dateDeclinedAt, 'dateDeclinedAt should be set');
  assert.notEqual(reply.type, 'dateCard');
  assert.notEqual(m.datePlan?.status, 'proposed');
});

test('asked for a date, Cherry puts up a card with a dish, a day, and a time', async () => {
  await say(two, "Okay you've won me over 😄 Cherry, we're both free this Saturday evening — can you plan a cooking date for us?");
  const card = await waitFor(async () => (await cherry()).find((m) => m.type === 'dateCard'), 'a date card', 120_000);
  console.log(`  card: ${card.text} → ${card.payload.dish} on ${card.payload.day} at ${card.payload.time} (${card.payload.dishWhy})`);
  const plan = (await matchDoc()).datePlan;
  assert.equal(plan.status, 'proposed');
  assert.equal(plan.version, card.payload.version);
  assert.deepEqual(plan.confirmedBy, {});
});

test('rejecting the dish gets alternatives or a new card, never a confirmed date', async () => {
  const before = (await cherry()).length;
  await say(two, "Hmm, I'm not really feeling that dish — Cherry, any other ideas?");
  const reply = await waitFor(cherryCountAbove(before), "Cherry's alternatives");
  console.log(`  alternatives: ${reply.text}${reply.payload ? ` → ${reply.payload.dish}` : ''}`);
  if (reply.type !== 'dateCard') {
    const count = (await cherry()).length;
    await say(one, 'The second one sounds great to me!');
    await sleep(1500);
    await say(two, "Yes! Let's do the second one, same time 😊");
    const card = await waitFor(
      async () => ((await cherry()).length > count ? (await cherry()).filter((m) => m.type === 'dateCard').at(-1) : null),
      'an updated card',
      120_000,
    );
    console.log(`  updated card: ${card.payload.dish} on ${card.payload.day} at ${card.payload.time}`);
  }
  const plan = (await matchDoc()).datePlan;
  assert.equal(plan.status, 'proposed');
  assert.ok(plan.version >= 2, 'the card should have been updated');
});

test('one confirmation is not a date; both confirmations bring recipe, song, goodbye, and Cherry leaves', async () => {
  const { version } = (await matchDoc()).datePlan;
  const first = await confirmDate(db, matchId, one, version, apiKey);
  assert.equal(first.ok && first.bothConfirmed, false);
  assert.equal((await matchDoc()).datePlan.status, 'proposed');
  assert.deepEqual(await confirmDate(db, matchId, 'mallory', version, apiKey), { ok: false, reason: 'not_member' });

  const second = await confirmDate(db, matchId, two, version, apiKey);
  assert.equal(second.ok && second.bothConfirmed, true);
  // confirmDate finishes the date itself; if a decide call held the lock, the timer does it.
  if ((await matchDoc()).cherryState !== 'left') await runCherryTick(db, apiKey);
  assert.equal((await matchDoc()).cherryState, 'left');
  assert.equal((await matchDoc()).datePlan.status, 'confirmed');

  const msgs = await cherry();
  const recipe = msgs.find((m) => m.type === 'recipe');
  const song = msgs.find((m) => m.type === 'song');
  const goodbye = msgs.at(-1);
  console.log(`  recipe: ${recipe.payload.title} (${recipe.payload.minutes} min) — ${recipe.payload.ingredients.join('; ')}`);
  console.log(`  allergy note: ${recipe.payload.allergyNote}`);
  console.log(`  song: ${song.payload.title} by ${song.payload.artist} — ${song.payload.why}`);
  console.log(`  goodbye: ${goodbye.text}`);
  const ingredients = recipe.payload.ingredients.join(' ').toLowerCase();
  assert.doesNotMatch(ingredients, /\b(chicken|beef|pork|bacon|ham|fish|salmon|tuna|shrimp|prawns?|lamb|anchov\w*)\b/, 'both are vegetarian');
  assert.doesNotMatch(ingredients, /\b(nuts?|almonds?|cashews?|walnuts?|pecans?|pistachios?|hazelnuts?|peanuts?|pine nuts?)\b/, 'Tester Two has a nut allergy');
  assert.ok(recipe.payload.allergyNote.length > 0);
  assert.equal(goodbye.type, 'cherryGoodbye');
  assert.match(goodbye.text, /bake this out/i);
});

test('after leaving, Cherry never posts again', async () => {
  const count = (await cherry()).length;
  await say(one, 'Cherry, any last tips?');
  await sleep(12_000);
  assert.deepEqual(await runCherryTick(db, apiKey, new Date(Date.now() + 3_600_000)), []);
  assert.equal((await cherry()).length, count);
});
