// DEV ONLY — creates two labelled test accounts and a match between them so the chat
// and Cherry can be built before Discover exists. Removed in slice 6.
//
// Emulators:  FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST set (emulators:exec does this).
// Real project: needs Google application-default credentials and DEV_PASSWORD set.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const usingEmulators = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const password = process.env.DEV_PASSWORD ?? (usingEmulators ? 'bakeout-dev' : undefined);
if (!password) {
  console.error('Set DEV_PASSWORD to seed the real project (never commit it).');
  process.exit(1);
}

export const testers = [
  { email: 'tester.one@bakeout.test', name: 'Tester One' },
  { email: 'tester.two@bakeout.test', name: 'Tester Two' },
];

initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'studio-1391080484-497cf' });
const auth = getAuth();
const db = getFirestore();

async function ensureUser({ email, name }) {
  const user = await auth.getUserByEmail(email).catch(() => auth.createUser({ email, password, displayName: name }));
  await db.doc(`users/${user.uid}`).set({ name, devSample: true, createdAt: FieldValue.serverTimestamp() }, { merge: true });
  await db.doc(`users/${user.uid}/private/account`).set({ email }, { merge: true });
  return user.uid;
}

const uids = [];
for (const tester of testers) uids.push(await ensureUser(tester));
uids.sort();
const matchId = uids.join('_');

await db.doc(`matches/${matchId}`).set(
  {
    users: uids,
    seenBy: [],
    cherryState: 'active',
    devSample: true,
    createdAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);

console.log(`Seeded ${usingEmulators ? 'emulators' : 'REAL project'}: match ${matchId}`);
for (const t of testers) console.log(`  ${t.email}`);
