import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { askJson, geminiKey } from '../gemini';
import { commonGround, loadPeople } from '../profiles';
import { postAsCherry, tryLock, unlock } from './chat';
import { CHERRY_SYSTEM, messageSchema, openingPrompt } from './prompts';

/** Cherry's welcome in a brand-new match (`prd.md > Opening the Chat`). */
export async function openChat(db: Firestore, matchId: string, apiKey: string, now = new Date()): Promise<boolean> {
  const match = await tryLock(db, matchId, now);
  if (!match) return false;
  try {
    const existing = await db.collection(`matches/${matchId}/messages`).limit(1).get();
    if (!existing.empty) return false;
    const [a, b] = await loadPeople(db, match.users);
    const { message } = await askJson<{ message: string }>({
      apiKey,
      system: CHERRY_SYSTEM,
      prompt: openingPrompt(a, b, commonGround(a.food, b.food)),
      schema: messageSchema,
    });
    return await postAsCherry(db, matchId, message.trim());
  } catch (err) {
    logger.error('Cherry opening failed; staying quiet', { matchId, err });
    return false;
  } finally {
    await unlock(db, matchId);
  }
}

export const cherryOpening = onDocumentCreated({ document: 'matches/{matchId}', secrets: [geminiKey] }, async (event) => {
  await openChat(getFirestore(), event.params.matchId, geminiKey.value());
});
