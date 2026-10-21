// One-off: writes app/assets/recipes/library.json — BakeOut's bundled recipe library.
// Gemini drafts recipes cuisine by cuisine; keyword rules then double-check every diet and
// allergen tag (they can only make a recipe *more* restricted, never less). Run from functions/:
//   node scripts/build-recipe-library.mjs
import { readFileSync, writeFileSync } from 'node:fs';

import { GoogleGenAI, ThinkingLevel } from '@google/genai';

const apiKey = readFileSync(new URL('../.secret.local', import.meta.url), 'utf8').match(/GEMINI_API_KEY=(.*)/)?.[1]?.trim();
if (!apiKey) throw new Error('GEMINI_API_KEY missing from functions/.secret.local');
const ai = new GoogleGenAI({ apiKey });

const CUISINES = [
  'Indian', 'Italian', 'Chinese', 'Japanese', 'Mexican', 'Thai', 'Mediterranean', 'Korean',
  'French', 'Middle Eastern', 'American', 'British',
];
const DIETS = ['vegan', 'vegetarian', 'pescatarian', 'meat'];
const ALLERGENS = ['nuts', 'gluten', 'dairy', 'egg', 'shellfish', 'fish', 'soy', 'pork', 'alcohol', 'onion_garlic'];

const schema = {
  type: 'object',
  properties: {
    recipes: {
      type: 'array',
      minItems: 3,
      maxItems: 4,
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          emoji: { type: 'string', description: 'One food emoji for the dish.' },
          minutes: { type: 'integer' },
          blurb: { type: 'string', description: 'One warm, playful line, max 14 words.' },
          diet: { type: 'string', enum: DIETS, description: 'The most permissive diet that can eat it as written.' },
          allergens: { type: 'array', items: { type: 'string', enum: ALLERGENS } },
          ingredients: { type: 'array', items: { type: 'string' } },
          steps: { type: 'array', items: { type: 'string' } },
        },
        required: ['title', 'emoji', 'minutes', 'blurb', 'diet', 'allergens', 'ingredients', 'steps'],
      },
    },
  },
  required: ['recipes'],
};

const prompt = (cuisine) => `Write 4 well-loved, reliable home recipes from ${cuisine} cuisine for two people.
Mix: one vegan, one vegetarian, one with fish or seafood OR a second vegetarian, one with meat. Mix quick (≤20 min) and relaxed (45–90 min).
Tag honestly: "diet" is the most permissive diet that can eat it exactly as written (vegan < vegetarian < pescatarian < meat).
"allergens" lists every one of ${ALLERGENS.join(', ')} the recipe contains ("onion_garlic" for onion or garlic; "alcohol" for wine, beer, mirin etc.; "gluten" includes wheat pasta, bread, flour, soy sauce).
Ingredients with quantities for two; 4–8 short clear steps; no markdown.`;

// Keyword safety net: a recipe can only be made more restricted here.
const has = (text, words) => words.some((w) => new RegExp(`\\b${w}`, 'i').test(text));
const MEAT = ['chicken', 'beef', 'pork', 'bacon', 'ham', 'lamb', 'mutton', 'turkey', 'duck', 'sausage', 'chorizo', 'pancetta', 'prosciutto', 'gelatin'];
const FISH = ['fish', 'salmon', 'tuna', 'cod', 'haddock', 'anchov', 'sardine', 'mackerel', 'fish sauce', 'dashi', 'bonito'];
const SHELLFISH = ['shrimp', 'prawn', 'crab', 'lobster', 'mussel', 'clam', 'scallop', 'oyster', 'squid'];
const ANIMAL = ['egg', 'butter', 'cheese', 'milk', 'cream', 'yogurt', 'yoghurt', 'ghee', 'paneer', 'honey', 'parmesan', 'mozzarella', 'ricotta', 'feta', 'halloumi'];
const RULES = {
  nuts: ['almond', 'cashew', 'walnut', 'pecan', 'pistachio', 'hazelnut', 'peanut', 'pine nut', 'nuts?\\b'],
  gluten: ['flour', 'bread', 'pasta', 'spaghetti', 'noodle', 'tortilla', 'soy sauce', 'naan', 'pita', 'couscous', 'breadcrumb', 'panko', 'barley', 'wheat', 'udon', 'ramen', 'gnocchi', 'pastry', 'bun'],
  dairy: ['butter', 'cheese', 'milk', 'cream', 'yogurt', 'yoghurt', 'ghee', 'paneer', 'parmesan', 'mozzarella', 'ricotta', 'feta', 'halloumi'],
  egg: ['egg'],
  shellfish: SHELLFISH,
  fish: FISH,
  soy: ['soy', 'tofu', 'tempeh', 'edamame', 'miso'],
  pork: ['pork', 'bacon', 'ham', 'pancetta', 'prosciutto', 'chorizo', 'sausage'],
  alcohol: ['wine', 'beer', 'mirin', 'sake', 'rum', 'brandy', 'vodka', 'sherry'],
  onion_garlic: ['onion', 'garlic', 'shallot', 'leek', 'spring onion', 'scallion', 'chive'],
};
const rank = { vegan: 0, vegetarian: 1, pescatarian: 2, meat: 3 };

function verify(r) {
  const text = r.ingredients.join(' ').toLowerCase();
  let diet = r.diet;
  const bump = (to) => {
    if (rank[to] > rank[diet]) diet = to;
  };
  if (has(text, MEAT)) bump('meat');
  if (has(text, [...FISH, ...SHELLFISH])) bump('pescatarian');
  if (has(text, ANIMAL)) bump('vegetarian');
  const allergens = new Set(r.allergens);
  for (const [tag, words] of Object.entries(RULES)) if (has(text, words)) allergens.add(tag);
  return { ...r, diet, allergens: [...allergens].sort() };
}

const library = [];
for (const cuisine of CUISINES) {
  const res = await ai.models.generateContent({
    model: 'gemini-3.8-flash',
    contents: prompt(cuisine),
    config: { responseMimeType: 'application/json', responseJsonSchema: schema, thinkingConfig: { thinkingLevel: ThinkingLevel.LOW } },
  });
  const { recipes } = JSON.parse(res.text);
  for (const r of recipes) {
    const id = `${cuisine}-${r.title}`.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    library.push({ id, cuisine, ...verify(r) });
  }
  console.log(`${cuisine}: ${recipes.map((r) => r.title).join(' · ')}`);
}

const out = new URL('../../app/assets/recipes/library.json', import.meta.url);
writeFileSync(out, JSON.stringify({ generated: new Date().toISOString().slice(0, 10), recipes: library }, null, 2) + '\n');
const byDiet = Object.fromEntries(DIETS.map((d) => [d, library.filter((r) => r.diet === d).length]));
console.log(`\n${library.length} recipes →`, byDiet);
