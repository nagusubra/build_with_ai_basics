import { FieldValue, Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { askJson, geminiKey } from '../gemini';
import { loadPeople } from '../profiles';
import { CHERRY, cherryLeaves, postAsCherry, readMatch, recentHistory, unlock } from './chat';
import { asksForDate, mayProposeDate, planIsComplete, proposePlan, type PlanDetails } from './planState';
import { CHERRY_SYSTEM, decidePrompt, decideSchema, planContext } from './prompts';
import { asksCherryToLeave, cherryHasLeft, lockIsFree, lockUntil, mayConsiderSpeaking } from './rules';

export const DISMISSED_GOODBYE = "Got it — I'll give you two some space. Now it's on you two how you bake this out further! 🍒";

interface HumanMessage {
  sender: string;
  text: string;
  createdAt?: Date;
}

interface Decision {
  action: 'stay_quiet' | 'speak' | 'propose_date' | 'update_plan' | 'back_off' | 'leave';
  message?: string;
  plan?: Partial<PlanDetails>;
}

/**
 * Books the human message on the match, then — only if Cherry may consider speaking and
 * nobody holds the lock — asks Gemini what Cherry does, and carries it out within the rules.
 */
export async function onHumanMessage(db: Firestore, matchId: string, msg: HumanMessage, apiKey: string, now = new Date()) {
  if (msg.sender === CHERRY) return 'ignored';
  const ref = db.doc(`matches/${matchId}`);

  const verdict = await db.runTransaction(async (tx) => {
    const match = readMatch(await tx.get(ref));
    if (cherryHasLeft(match)) return 'gone' as const;
    const booked = { ...match, humanMessagesSinceCherry: (match.humanMessagesSinceCherry ?? 0) + 1 };
    const update: Record<string, unknown> = {
      lastHumanMessageAt: Timestamp.fromDate(msg.createdAt ?? now),
      lastHumanBy: msg.sender,
      lastMessageBy: msg.sender,
      humanMessagesSinceCherry: FieldValue.increment(1),
      humanMessagesSinceDecline: FieldValue.increment(1),
    };
    const consider =
      asksCherryToLeave(msg.text) ||
      mayConsiderSpeaking(booked, msg.text) ||
      asksForDate(msg.text) ||
      match.datePlan?.status === 'proposed';
    const take = consider && lockIsFree(match, now);
    if (take) update.cherryBusyUntil = Timestamp.fromDate(lockUntil(now));
    tx.update(ref, update);
    return take ? ('think' as const) : ('quiet' as const);
  });
  if (verdict !== 'think') return verdict;

  try {
    if (asksCherryToLeave(msg.text)) {
      await cherryLeaves(db, matchId, DISMISSED_GOODBYE);
      return 'left';
    }
    const match = readMatch(await ref.get());
    const plan = match.datePlan!;
    const proposeAllowed = mayProposeDate(match, msg.text);
    const people = await loadPeople(db, match.users);
    const [a, b] = people;
    const history = await recentHistory(db, matchId, people);
    const latestFrom = people.find((p) => p.uid === msg.sender)?.name ?? 'Someone';
    const decision = await askJson<Decision>({
      apiKey,
      system: CHERRY_SYSTEM,
      prompt: decidePrompt(a, b, history, { from: latestFrom, text: msg.text }, planContext(plan, people, proposeAllowed)),
      schema: decideSchema,
    });
    const text = decision.message?.trim() ?? '';

    switch (decision.action) {
      case 'leave':
        await cherryLeaves(db, matchId, text || DISMISSED_GOODBYE);
        return 'left';
      case 'propose_date':
      case 'update_plan': {
        const isUpdate = decision.action === 'update_plan';
        if (plan.status === 'confirmed' || !planIsComplete(decision.plan)) return 'quiet';
        if (!isUpdate && (plan.status === 'proposed' || !proposeAllowed)) return 'quiet';
        if (isUpdate && plan.status !== 'proposed') return 'quiet';
        const next = proposePlan(plan, decision.plan);
        await postAsCherry(db, matchId, text, {
          type: 'dateCard',
          payload: { dish: next.dish, dishWhy: next.dishWhy ?? '', day: next.day, time: next.time, version: next.version },
          matchUpdate: { datePlan: next },
        });
        return isUpdate ? 'updated_plan' : 'proposed_date';
      }
      case 'back_off':
        if (text) {
          await postAsCherry(db, matchId, text, {
            matchUpdate: { dateDeclinedAt: FieldValue.serverTimestamp(), humanMessagesSinceDecline: 0 },
          });
        } else {
          await ref.update({ dateDeclinedAt: FieldValue.serverTimestamp(), humanMessagesSinceDecline: 0 });
        }
        return 'backed_off';
      case 'speak':
        if (!text) return 'quiet';
        await postAsCherry(db, matchId, text);
        return 'spoke';
      default:
        return 'quiet';
    }
  } catch (err) {
    logger.error('Cherry decide failed; staying quiet', { matchId, err });
    return 'quiet';
  } finally {
    await unlock(db, matchId).catch(() => undefined);
  }
}

export const cherryDecide = onDocumentCreated(
  { document: 'matches/{matchId}/messages/{messageId}', secrets: [geminiKey] },
  async (event) => {
    const data = event.data?.data();
    if (!data || data.sender === CHERRY || data.type !== 'text') return;
    const createdAt = data.createdAt instanceof Timestamp ? data.createdAt.toDate() : undefined;
    await onHumanMessage(getFirestore(), event.params.matchId, { sender: data.sender, text: data.text ?? '', createdAt }, geminiKey.value());
  },
);
