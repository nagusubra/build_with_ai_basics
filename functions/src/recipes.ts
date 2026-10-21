import { FieldValue, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { askJson, geminiKey } from './gemini';
import { describe, loadPeople, type Person } from './profiles';

export interface Recipe {
  title: string;
  cuisine: string;
  minutes: number;
  blurb: string;
  ingredients: string[];
  steps: string[];
  allergyNote: string;
}

const RECIPES_SYSTEM = `You are Cherry 🍒, the friendly cooking companion inside BakeOut, a food-first dating app.
You write short, reliable home recipes. Plain text in every field; no markdown.`;

function recipesPrompt(p: Person, seen: string[]): string {
  return `${describe(p)}

Write 6 recipes ${p.name} would enjoy cooking while waiting for new people to meet.${
    seen.length ? `\n- They asked for new ideas. Do NOT repeat or lightly reword any of these: ${seen.join('; ')}.` : ''
  }
- Every recipe MUST respect their food type and every dietary restriction or allergy listed above. Never include an ingredient they can't eat.
- Lean towards their favourite cuisines, with one or two fun surprises.
- Fit their happy cooking time.
- Mix it up: different cuisines and techniques, at least one easy one.
- blurb: one warm line on why ${p.name} will like it.
- allergyNote: one sentence reminding them to check packaged ingredients against their own allergies.`;
}

const recipesSchema = {
  type: 'object',
  properties: {
    recipes: {
      type: 'array',
      minItems: 4,
      maxItems: 6,
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          cuisine: { type: 'string' },
          minutes: { type: 'integer' },
          blurb: { type: 'string' },
          ingredients: { type: 'array', items: { type: 'string' } },
          steps: { type: 'array', items: { type: 'string' } },
          allergyNote: { type: 'string' },
        },
        required: ['title', 'cuisine', 'minutes', 'blurb', 'ingredients', 'steps', 'allergyNote'],
      },
    },
  },
  required: ['recipes'],
};

/** Cached recipes for this person, or a fresh set when asked or when there are none yet. */
export async function recipesFor(db: Firestore, uid: string, apiKey: string, refresh = false): Promise<Array<Recipe & { id: string }>> {
  const col = db.collection(`users/${uid}/recipes`);
  if (!refresh) {
    const cached = await col.orderBy('createdAt').get();
    if (!cached.empty) return cached.docs.map((d) => ({ id: d.id, ...(d.data() as Recipe) }));
  }

  const [person] = await loadPeople(db, [uid]);
  const old = await col.get();
  const seen = old.docs.map((d) => d.get('title') as string).filter(Boolean);
  const { recipes } = await askJson<{ recipes: Recipe[] }>({
    apiKey,
    system: RECIPES_SYSTEM,
    prompt: recipesPrompt(person, seen),
    schema: recipesSchema,
  });

  const batch = db.batch();
  old.docs.forEach((d) => batch.delete(d.ref));
  const saved = recipes.map((r, i) => {
    const ref = col.doc();
    batch.set(ref, { ...r, createdAt: FieldValue.serverTimestamp(), order: i });
    return { id: ref.id, ...r };
  });
  await batch.commit();
  return saved;
}

export const getMyRecipes = onCall<{ refresh?: boolean }>({ secrets: [geminiKey] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  try {
    return { recipes: await recipesFor(getFirestore(), uid, geminiKey.value(), request.data?.refresh === true) };
  } catch {
    throw new HttpsError('unavailable', "Couldn't cook up recipes just now — please try again.");
  }
});
