import { FieldValue, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { askJson, geminiKey } from '../gemini';
import { loadPeople } from '../profiles';
import { postAsCherry, readMatch, recentHistory, tryLock, unlock } from './chat';
import { finishDate } from './plan';
import { CHERRY_SYSTEM, messageSchema, reminderPrompt, stallPrompt } from './prompts';
import { tickAction } from './rules';

/** One pass over active chats: finish confirmed dates, prompt stalled chats, remind long-quiet ones. */
export async function runCherryTick(db: Firestore, apiKey: string, now = new Date()) {
  const active = await db.collection('matches').where('cherryState', '==', 'active').get();
  const acted: string[] = [];
  for (const doc of active.docs) {
    const action = tickAction(readMatch(doc), now);
    if (!action) continue;
    const match = await tryLock(db, doc.id, now);
    if (!match || !tickAction(match, now)) {
      if (match) await unlock(db, doc.id);
      continue;
    }
    try {
      if (action.kind === 'finish') {
        if (await finishDate(db, doc.id, apiKey)) acted.push(`${doc.id}:finish`);
        continue;
      }
      const people = await loadPeople(db, match.users);
      const [a, b] = people;
      const history = await recentHistory(db, doc.id, people);
      const prompt =
        action.kind === 'stall'
          ? stallPrompt(a, b, history)
          : reminderPrompt(a, b, history, people.find((p) => p.uid === action.quietUser) ?? null);
      const { message } = await askJson<{ message: string }>({ apiKey, system: CHERRY_SYSTEM, prompt, schema: messageSchema });
      const matchUpdate = action.kind === 'reminder' ? { reminderSentAt: FieldValue.serverTimestamp() } : {};
      if (await postAsCherry(db, doc.id, message.trim(), { matchUpdate })) acted.push(`${doc.id}:${action.kind}`);
    } catch (err) {
      logger.error('Cherry tick failed for chat; will retry next minute', { matchId: doc.id, err });
    } finally {
      await unlock(db, doc.id).catch(() => undefined);
    }
  }
  return acted;
}

export const cherryTick = onSchedule({ schedule: 'every 1 minutes', secrets: [geminiKey] }, async () => {
  await runCherryTick(getFirestore(), geminiKey.value());
});
