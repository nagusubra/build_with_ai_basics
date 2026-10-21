// DEV ONLY — creates two labelled, fully onboarded test accounts with SAMPLE food profiles
// (marked devSample). `--match` also has them like each other so the real matching runs.
//
// Emulators:  FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST set (emulators:exec does this).
// Real project: DEV_PASSWORD and GOOGLE_OAUTH_ACCESS_TOKEN (e.g. from `gcloud auth print-access-token`)
// set; see `npm run seed:real`, which keeps the password in the git-ignored .dev-testers.local.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const usingEmulators = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const password = process.env.DEV_PASSWORD ?? (usingEmulators ? 'bakeout-dev' : undefined);
if (!password) {
  console.error('Set DEV_PASSWORD to seed the real project (never commit it).');
  process.exit(1);
}

// SAMPLE food profiles. Marked devSample in Firestore.
export const testers = [
  {
    email: 'tester.one@bakeout.test',
    name: 'Tester One',
    gender: 'Man',
    cherry: 'boy',
    food: {
      cookingRelationship: 'I cook when I have time',
      foodType: 'Vegetarian',
      restrictions: [],
      cuisines: ['Italian', 'Indian', 'Mexican', 'Thai'],
      topCuisines: ['Italian', 'Indian', 'Thai'],
      signatureDish: 'Paneer butter masala',
      comfortFood: 'Rajma chawal',
      adventure: 8,
      idealDate: 'Trying a completely new recipe',
      cookingPersonality: ['The experimental chef'],
      cookingTime: 'Around an hour',
      musicGenres: ['Bollywood', 'Lo-fi'],
    },
  },
  {
    email: 'tester.two@bakeout.test',
    name: 'Tester Two',
    gender: 'Woman',
    cherry: 'girl',
    food: {
      cookingRelationship: 'I love cooking and do it almost every day',
      foodType: 'Vegetarian',
      restrictions: ['Nut allergy'],
      cuisines: ['Italian', 'Japanese', 'Mexican', 'Korean'],
      topCuisines: ['Italian', 'Japanese', 'Korean'],
      signatureDish: 'Fresh pasta from scratch',
      comfortFood: 'Ramen',
      adventure: 6,
      idealDate: 'Baking something sweet',
      cookingPersonality: ['The perfectionist'],
      cookingTime: 'Around an hour',
      musicGenres: ['Indie', 'Lo-fi'],
    },
  },
];

const projectId = process.env.GCLOUD_PROJECT ?? 'studio-1391080484-497cf';
const token = process.env.GOOGLE_OAUTH_ACCESS_TOKEN;
if (!usingEmulators && !token) {
  console.error('Set GOOGLE_OAUTH_ACCESS_TOKEN to seed the real project (npm run seed:real does this).');
  process.exit(1);
}

// The real project uses your gcloud login: Firestore via an OAuth client, accounts via the
// Identity Toolkit REST API. The emulators use the Admin SDK directly.
let db;
let accountUid;
if (usingEmulators) {
  initializeApp({ projectId });
  db = getFirestore();
  const auth = getAuth();
  accountUid = async (email, name) =>
    (await auth.getUserByEmail(email).catch(() => auth.createUser({ email, password, displayName: name }))).uid;
} else {
  const { Firestore } = await import('@google-cloud/firestore');
  const { OAuth2Client } = await import('google-auth-library');
  const authClient = new OAuth2Client();
  authClient.setCredentials({ access_token: token });
  db = new Firestore({ projectId, authClient });

  const base = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}`;
  const headers = { Authorization: `Bearer ${token}`, 'x-goog-user-project': projectId, 'Content-Type': 'application/json' };
  const call = async (path, body) => {
    const res = await fetch(`${base}/${path}`, { method: 'POST', headers, body: JSON.stringify(body) });
    const json = await res.json();
    if (!res.ok) throw new Error(`${path}: ${json.error?.message ?? res.status}`);
    return json;
  };
  accountUid = async (email, name) => {
    const found = await call('accounts:lookup', { email: [email] });
    const existing = found.users?.[0]?.localId;
    if (existing) {
      await call('accounts:update', { localId: existing, password, displayName: name });
      return existing;
    }
    return (await call('accounts', { email, password, displayName: name })).localId;
  };
}

async function ensureUser({ email, name, gender, cherry, food }) {
  const user = { uid: await accountUid(email, name) };
  await db.doc(`users/${user.uid}`).set(
    {
      name,
      age: 26,
      gender,
      interestedIn: ['Everyone'],
      city: 'Edinburgh, UK',
      lookingFor: 'partner',
      filters: FieldValue.delete(),
      cherryAvatar: cherry,
      food,
      quizDone: true,
      verified: true,
      previewSeen: true,
      onboardingComplete: true,
      devSample: true,
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await db.doc(`users/${user.uid}/private/account`).set({ email }, { merge: true });
  return { uid: user.uid, cherry };
}

const seeded = [];
for (const tester of testers) seeded.push(await ensureUser(tester));
const [one, two] = seeded.map((s) => s.uid);
const matchId = [one, two].sort().join('_');

// Clean slate: no old match, likes, or passes between the testers.
await db.recursiveDelete(db.doc(`matches/${matchId}`));
for (const [a, b] of [[one, two], [two, one]]) {
  await db.doc(`likes/${a}_${b}`).delete();
  await db.doc(`users/${a}/passes/${b}`).delete();
}

// --match: the testers like each other, so the real matching function (onLikeCreated) creates
// the match and Cherry opens it. Used by the emulator checks; on the real project, like in the app.
if (process.argv.includes('--match')) {
  await db.doc(`likes/${one}_${two}`).set({ from: one, to: two, createdAt: FieldValue.serverTimestamp() });
  await db.doc(`likes/${two}_${one}`).set({ from: two, to: one, createdAt: FieldValue.serverTimestamp() });
}

console.log(`Seeded ${usingEmulators ? 'emulators' : 'REAL project'} testers${process.argv.includes('--match') ? ' (liking each other)' : ''}`);
for (const t of testers) console.log(`  ${t.email}`);
