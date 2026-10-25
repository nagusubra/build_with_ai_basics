// HACKATHON DEMO — creates (or resets) the profiles judges use from the web app's judge panel:
// Maya and Arjun, ready-made and matched with each other (Cherry opens their chat), and a
// small sample crowd for Discover that likes judges back. Running it again puts Maya and
// Arjun back to a clean slate; fresh judge accounts are left alone.
//
// Emulators:    FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST, FIREBASE_STORAGE_EMULATOR_HOST set.
// Real project: GOOGLE_OAUTH_ACCESS_TOKEN set (`npm run seed:judges` does this from your gcloud login).
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { setTimeout as sleep } from 'node:timers/promises';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

import { JUDGE_PASSWORD, crowd, everyone, readyMade } from './judge-demo.mjs';

const usingEmulators = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = process.env.GCLOUD_PROJECT ?? 'studio-1391080484-497cf';
const bucketName = `${projectId}.firebasestorage.app`;
const token = process.env.GOOGLE_OAUTH_ACCESS_TOKEN;
if (!usingEmulators && !token) {
  console.error('Set GOOGLE_OAUTH_ACCESS_TOKEN to seed the real project (npm run seed:judges does this).');
  process.exit(1);
}

// The real project uses your gcloud login: Firestore and Storage via an OAuth client, accounts via
// the Identity Toolkit REST API. The emulators use the Admin SDK directly.
let db;
let bucket;
let accountUid;
if (usingEmulators) {
  initializeApp({ projectId, storageBucket: bucketName });
  db = getFirestore();
  bucket = getStorage().bucket();
  const auth = getAuth();
  accountUid = async (email, name) => {
    const existing = await auth.getUserByEmail(email).catch(() => null);
    if (existing) return (await auth.updateUser(existing.uid, { password: JUDGE_PASSWORD, displayName: name })).uid;
    return (await auth.createUser({ email, password: JUDGE_PASSWORD, displayName: name })).uid;
  };
} else {
  const { Firestore } = await import('@google-cloud/firestore');
  const { Storage } = await import('@google-cloud/storage');
  const { OAuth2Client } = await import('google-auth-library');
  const authClient = new OAuth2Client();
  authClient.setCredentials({ access_token: token });
  db = new Firestore({ projectId, authClient });
  bucket = new Storage({ projectId, authClient }).bucket(bucketName);

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
      await call('accounts:update', { localId: existing, password: JUDGE_PASSWORD, displayName: name });
      return existing;
    }
    return (await call('accounts', { email, password: JUDGE_PASSWORD, displayName: name })).localId;
  };
}

/** Uploads the person's demo photo with a download token, so the app's getDownloadURL works. */
async function uploadPhoto(uid, id) {
  const path = `users/${uid}/photos/demo_${id}.jpg`;
  const bytes = await readFile(new URL(`./judge-photos/${id}.jpg`, import.meta.url));
  await bucket.file(path).save(bytes, {
    resumable: false,
    metadata: { contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: randomUUID() } },
  });
  return path;
}

async function ensurePerson(p, { likesBack }) {
  const uid = await accountUid(p.email, p.name);
  const photo = await uploadPhoto(uid, p.id);
  await db.doc(`users/${uid}`).set(
    {
      name: p.name,
      age: p.age,
      gender: p.gender,
      interestedIn: ['Everyone'],
      city: p.city,
      lookingFor: p.lookingFor,
      cherryAvatar: p.cherry,
      food: p.food,
      prompts: p.prompts ?? {},
      photos: [photo],
      verified: true,
      verificationSkipped: false,
      quizDone: true,
      previewSeen: true,
      onboardingComplete: true,
      tourSeen: false,
      filters: FieldValue.delete(),
      demo: true,
      demoLikesBack: likesBack,
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await db.doc(`users/${uid}/private/account`).set({ email: p.email }, { merge: true });
  return uid;
}

/** Everything a judge may have done as this ready-made person: matches, chats, likes, passes. */
async function clearActivity(uid) {
  const [matches, likesFrom, likesTo] = await Promise.all([
    db.collection('matches').where('users', 'array-contains', uid).get(),
    db.collection('likes').where('from', '==', uid).get(),
    db.collection('likes').where('to', '==', uid).get(),
  ]);
  for (const m of matches.docs) await db.recursiveDelete(m.ref);
  await Promise.all([...likesFrom.docs, ...likesTo.docs].map((d) => d.ref.delete()));
  for (const sub of ['passes', 'likedBy', 'recipes']) await db.recursiveDelete(db.collection(`users/${uid}/${sub}`));
}

const like = (from, to) => db.doc(`likes/${from}_${to}`).set({ from, to, createdAt: FieldValue.serverTimestamp() });

const uids = {};
for (const p of readyMade) uids[p.id] = await ensurePerson(p, { likesBack: false });
for (const p of crowd) uids[p.id] = await ensurePerson(p, { likesBack: true });

for (const p of readyMade) await clearActivity(uids[p.id]);
for (const p of crowd) {
  await db.recursiveDelete(db.collection(`users/${uids[p.id]}/passes`));
  await db.recursiveDelete(db.collection(`users/${uids[p.id]}/likedBy`));
}

// Maya and Arjun like each other, so the real matching function makes the match and Cherry opens it.
const [maya, arjun] = readyMade.map((p) => uids[p.id]);
await like(maya, arjun);
await like(arjun, maya);
// Someone in the crowd has already liked each of them, for the "liked you" banner.
for (const p of crowd.filter((c) => c.likes)) await like(uids[p.id], uids[p.likes]);

const matchId = [maya, arjun].sort().join('_');
let opened = false;
for (let i = 0; i < 45 && !opened; i++) {
  await sleep(1000);
  opened = !(await db.collection(`matches/${matchId}/messages`).limit(1).get()).empty;
}

console.log(`Seeded ${usingEmulators ? 'emulators' : 'REAL project'} judge demo (password: ${JUDGE_PASSWORD})`);
for (const p of everyone) console.log(`  ${p.email}${readyMade.includes(p) ? '  ← judges log in' : ''}`);
console.log(opened ? "Cherry has opened Maya and Arjun's chat." : "Maya and Arjun's match is waiting for Cherry's opening (is onLikeCreated deployed?).");
