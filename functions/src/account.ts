import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

type Bucket = ReturnType<ReturnType<typeof getStorage>['bucket']>;

/**
 * "Once deleted, everything is deleted" (`prd.md > My Profile: Preview, Edit, Delete`):
 * profile and its subcollections, photos, likes either way, every match with its messages,
 * then the login itself — last, so a failure part-way can be retried while still signed in.
 */
export async function deleteEverything(db: Firestore, bucket: Bucket, auth: Auth, uid: string) {
  const matches = await db.collection('matches').where('users', 'array-contains', uid).get();
  for (const m of matches.docs) await db.recursiveDelete(m.ref);

  const [likesFrom, likesTo] = await Promise.all([
    db.collection('likes').where('from', '==', uid).get(),
    db.collection('likes').where('to', '==', uid).get(),
  ]);
  const batch = db.batch();
  [...likesFrom.docs, ...likesTo.docs].forEach((d) => batch.delete(d.ref));
  await batch.commit();

  await bucket.deleteFiles({ prefix: `users/${uid}/` });
  await db.recursiveDelete(db.doc(`users/${uid}`));
  await auth.deleteUser(uid).catch((err: { code?: string }) => {
    if (err.code !== 'auth/user-not-found') throw err;
  });
  return { matches: matches.size, likes: likesFrom.size + likesTo.size };
}

export const deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  try {
    const removed = await deleteEverything(getFirestore(), getStorage().bucket(), getAuth(), uid);
    logger.info('Account deleted', { uid, ...removed });
    return { ok: true };
  } catch (err) {
    logger.error('Account deletion failed', { uid, err });
    throw new HttpsError('internal', "Couldn't delete everything just now — please try again.");
  }
});
