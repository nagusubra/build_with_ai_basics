import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { addDoc, collection, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { deleteObject, getBytes, ref, uploadBytes } from 'firebase/storage';

const MATCH = 'alice_bob';
let env;

const text = (sender, body = 'hi!') => ({ sender, type: 'text', text: body, createdAt: serverTimestamp() });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bakeout-rules',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
    storage: { rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { name: 'Alice' });
    await setDoc(doc(db, 'users/alice/private/account'), { email: 'alice@example.com' });
    await setDoc(doc(db, `matches/${MATCH}`), { users: ['alice', 'bob'], seenBy: [], cherryState: 'active' });
    await setDoc(doc(db, `matches/${MATCH}/messages/m1`), { sender: 'cherry', type: 'text', text: 'Hello!' });
  });
});

after(async () => {
  await env.cleanup();
});

describe('matches and messages', () => {
  test('a member can read the match and its messages', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertSucceeds(getDoc(doc(db, `matches/${MATCH}`)));
    await assertSucceeds(getDocs(collection(db, `matches/${MATCH}/messages`)));
  });

  test('a non-member cannot read the match or its messages', async () => {
    const db = env.authenticatedContext('mallory').firestore();
    await assertFails(getDoc(doc(db, `matches/${MATCH}`)));
    await assertFails(getDocs(collection(db, `matches/${MATCH}/messages`)));
  });

  test('a member can send a text message as themselves', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertSucceeds(addDoc(collection(db, `matches/${MATCH}/messages`), text('alice')));
  });

  test('a member cannot send a message as someone else, or as Cherry', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(addDoc(collection(db, `matches/${MATCH}/messages`), text('bob')));
    await assertFails(addDoc(collection(db, `matches/${MATCH}/messages`), text('cherry')));
  });

  test('a member cannot post special cards or empty text', async () => {
    const db = env.authenticatedContext('alice').firestore();
    const messages = collection(db, `matches/${MATCH}/messages`);
    await assertFails(addDoc(messages, { ...text('alice'), type: 'dateCard' }));
    await assertFails(addDoc(messages, text('alice', '')));
  });

  test('a non-member cannot post into the chat', async () => {
    const db = env.authenticatedContext('mallory').firestore();
    await assertFails(addDoc(collection(db, `matches/${MATCH}/messages`), text('mallory')));
  });

  test('a member can mark the match seen, but change nothing else', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertSucceeds(updateDoc(doc(db, `matches/${MATCH}`), { seenBy: ['alice'] }));
    await assertFails(updateDoc(doc(db, `matches/${MATCH}`), { cherryState: 'left' }));
    await assertFails(updateDoc(doc(db, `matches/${MATCH}`), { seenBy: ['alice', 'bob'] }));
  });

  test('nobody can create a match from the app', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'matches/alice_mallory'), { users: ['alice', 'mallory'] }));
  });
});

describe('likes and passes', () => {
  const like = (from, to) => ({ from, to, createdAt: serverTimestamp() });

  test('you can like someone as yourself, at the right id', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertSucceeds(setDoc(doc(db, 'likes/alice_bob'), like('alice', 'bob')));
  });

  test('you cannot like as someone else, like yourself, or use a mismatched id', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'likes/bob_carol'), like('bob', 'carol')));
    await assertFails(setDoc(doc(db, 'likes/alice_alice'), like('alice', 'alice')));
    await assertFails(setDoc(doc(db, 'likes/alice_carol'), like('alice', 'bob')));
  });

  test('nobody can see who liked them', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'likes/alice_bob'), { from: 'alice', to: 'bob' }));
    await assertSucceeds(getDoc(doc(env.authenticatedContext('alice').firestore(), 'likes/alice_bob')));
    await assertFails(getDoc(doc(env.authenticatedContext('bob').firestore(), 'likes/alice_bob')));
  });

  test('passes are private to the person who passed', async () => {
    await assertSucceeds(setDoc(doc(env.authenticatedContext('alice').firestore(), 'users/alice/passes/bob'), { createdAt: serverTimestamp() }));
    await assertFails(getDoc(doc(env.authenticatedContext('bob').firestore(), 'users/alice/passes/bob')));
  });

  test('recipes are written only by Cloud Functions', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'users/alice/recipes/r1'), { title: 'Fake' }));
    await assertSucceeds(getDocs(collection(db, 'users/alice/recipes')));
  });
});

describe('profile photos', () => {
  const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
  const image = { contentType: 'image/jpeg' };

  test('the owner can upload and delete their own photos', async () => {
    const storage = env.authenticatedContext('alice').storage();
    await assertSucceeds(uploadBytes(ref(storage, 'users/alice/photos/1.jpg'), jpeg, image));
    await assertSucceeds(deleteObject(ref(storage, 'users/alice/photos/1.jpg')));
  });

  test("nobody can upload into someone else's photos", async () => {
    const storage = env.authenticatedContext('bob').storage();
    await assertFails(uploadBytes(ref(storage, 'users/alice/photos/1.jpg'), jpeg, image));
  });

  test('only images are accepted', async () => {
    const storage = env.authenticatedContext('alice').storage();
    await assertFails(uploadBytes(ref(storage, 'users/alice/photos/notes.txt'), new Uint8Array([1]), { contentType: 'text/plain' }));
  });

  test('signed-in people can view photos; signed-out visitors cannot', async () => {
    await assertSucceeds(uploadBytes(ref(env.authenticatedContext('alice').storage(), 'users/alice/photos/2.jpg'), jpeg, image));
    await assertSucceeds(getBytes(ref(env.authenticatedContext('bob').storage(), 'users/alice/photos/2.jpg')));
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), 'users/alice/photos/2.jpg')));
  });

  test('nothing else in storage is writable', async () => {
    const storage = env.authenticatedContext('alice').storage();
    await assertFails(uploadBytes(ref(storage, 'selfies/alice.jpg'), jpeg, image));
  });
});

describe('profiles', () => {
  test('signed-in people can read profiles; only the owner can write theirs', async () => {
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    await assertSucceeds(getDoc(doc(bob, 'users/alice')));
    await assertSucceeds(setDoc(doc(alice, 'users/alice'), { name: 'Alice B' }));
    await assertFails(setDoc(doc(bob, 'users/alice'), { name: 'Hacked' }));
  });

  test('private details are owner-only', async () => {
    const bob = env.authenticatedContext('bob').firestore();
    await assertFails(getDoc(doc(bob, 'users/alice/private/account')));
  });

  test('signed-out visitors can read nothing', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'users/alice')));
  });
});
