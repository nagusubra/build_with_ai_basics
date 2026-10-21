// Runs inside `npm run check:recipes` (firestore emulator, real Gemini).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import { recipesFor } from '../lib/recipes.js';

const apiKey = readFileSync(new URL('../.secret.local', import.meta.url), 'utf8').match(/GEMINI_API_KEY=(.*)/)?.[1]?.trim();
initializeApp({ projectId: 'studio-1391080484-497cf' });
const db = getFirestore();
const uid = `recipes_${Date.now()}`;

const MEAT = /\b(chicken|beef|pork|bacon|ham|fish|salmon|tuna|shrimp|prawns?|lamb|anchov\w*|gelatin)\b/;
const NUTS = /\b(nuts?|almonds?|cashews?|walnuts?|pecans?|pistachios?|hazelnuts?|peanuts?|pine nuts?)\b/;

test('recipes respect a vegetarian with a nut allergy, and are cached until refreshed', async () => {
  assert.ok(apiKey, 'Put your Gemini key in functions/.secret.local as GEMINI_API_KEY=...');
  await db.doc(`users/${uid}`).set({
    name: 'Priya',
    food: {
      foodType: 'Vegetarian',
      restrictions: ['Nut allergy'],
      cuisines: ['Italian', 'Thai', 'Indian'],
      topCuisines: ['Italian', 'Thai'],
      cookingTime: 'Around 30 minutes',
    },
  });

  const first = await recipesFor(db, uid, apiKey);
  assert.ok(first.length >= 4 && first.length <= 6, `got ${first.length} recipes`);
  for (const r of first) {
    const ingredients = r.ingredients.join(' ').toLowerCase();
    console.log(`  ${r.title} (${r.cuisine}, ${r.minutes} min)`);
    assert.doesNotMatch(ingredients, MEAT, `${r.title} isn't vegetarian`);
    assert.doesNotMatch(ingredients, NUTS, `${r.title} contains nuts`);
    assert.ok(r.allergyNote.length > 0);
    assert.ok(r.steps.length > 0);
  }

  const cached = await recipesFor(db, uid, apiKey);
  assert.deepEqual(cached.map((r) => r.id).sort(), first.map((r) => r.id).sort(), 'second call should be the cached set');

  const fresh = await recipesFor(db, uid, apiKey, true);
  assert.notDeepEqual(fresh.map((r) => r.id).sort(), first.map((r) => r.id).sort(), '"New ideas" should replace the set');
  assert.equal((await db.collection(`users/${uid}/recipes`).get()).size, fresh.length);
});
