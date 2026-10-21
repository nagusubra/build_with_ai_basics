// DEV ONLY — plays "Tester Two" against the emulators for the chat check: when Tester One
// sends "ping <token>", reply "pong <token>". Exits after one reply, or after 15 minutes
// (a first iOS build can take several).
import { initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import {
  addDoc,
  collection,
  connectFirestoreEmulator,
  getFirestore,
  onSnapshot,
  query,
  serverTimestamp,
  where,
} from 'firebase/firestore';

const app = initializeApp({ projectId: 'studio-1391080484-497cf', apiKey: 'emulator-only' });
const auth = getAuth(app);
const db = getFirestore(app);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
connectFirestoreEmulator(db, '127.0.0.1', 8080);

const { user } = await signInWithEmailAndPassword(auth, 'tester.two@bakeout.test', 'bakeout-dev');
const matchesQuery = query(collection(db, 'matches'), where('users', 'array-contains', user.uid));

const timeout = setTimeout(() => {
  console.error('replier: no ping within 15 minutes');
  process.exit(1);
}, 900_000);

const stopMatches = onSnapshot(matchesQuery, (matches) => {
  for (const match of matches.docs) {
    const messages = collection(db, `matches/${match.id}/messages`);
    onSnapshot(messages, async (snap) => {
      for (const change of snap.docChanges()) {
        const m = change.doc.data();
        if (change.type !== 'added' || m.sender === user.uid || !m.text?.startsWith('ping ')) continue;
        const token = m.text.slice('ping '.length);
        await addDoc(messages, { sender: user.uid, type: 'text', text: `pong ${token}`, createdAt: serverTimestamp() });
        console.log(`replier: answered ${token}`);
        clearTimeout(timeout);
        stopMatches();
        setTimeout(() => process.exit(0), 500);
      }
    });
  }
});
