import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { confirmPlan, mayProposeDate, noPlan, planIsComplete, proposePlan, NOT_READY_COOLDOWN } from '../lib/cherry/planState.js';
import { asksCherryToLeave, mayConsiderSpeaking, mentionsCherry, tickAction } from '../lib/cherry/rules.js';
import { commonGround } from '../lib/profiles.js';

const t0 = new Date('2026-10-21T10:00:00Z');
const at = (min) => new Date(t0.getTime() + min * 60_000);
const users = ['ana', 'ben'];

describe('when Cherry may consider speaking', () => {
  test('stays out of a flowing conversation right after it spoke', () => {
    assert.equal(mayConsiderSpeaking({ users, humanMessagesSinceCherry: 1 }, 'haha same'), false);
    assert.equal(mayConsiderSpeaking({ users, humanMessagesSinceCherry: 2 }, 'what do you cook?'), false);
  });

  test('may consider once a few human messages have passed', () => {
    assert.equal(mayConsiderSpeaking({ users, humanMessagesSinceCherry: 3 }, 'ok'), true);
  });

  test('always listens when addressed by name', () => {
    assert.equal(mayConsiderSpeaking({ users, humanMessagesSinceCherry: 1 }, 'Cherry, any ideas?'), true);
  });

  test('never once it has left', () => {
    assert.equal(mayConsiderSpeaking({ users, cherryState: 'left', humanMessagesSinceCherry: 9 }, 'Cherry?'), false);
  });

  test('recognises its name only as a word', () => {
    assert.equal(mentionsCherry('cherry pie'), true);
    assert.equal(mentionsCherry('cherrypicked'), false);
  });

  test('recognises clear requests to leave', () => {
    assert.equal(asksCherryToLeave('Thanks Cherry, you can go now'), true);
    assert.equal(asksCherryToLeave('cherry give us some space pls'), true);
    assert.equal(asksCherryToLeave('I love cherry tomatoes'), false);
    assert.equal(asksCherryToLeave('we should leave early'), false);
  });
});

describe('the timer', () => {
  const base = { users, cherryState: 'active', createdAt: t0 };

  test('does nothing while the chat is fresh', () => {
    assert.equal(tickAction({ ...base, lastHumanMessageAt: at(0), lastHumanBy: 'ana', lastCherryMessageAt: at(-1) }, at(1)), null);
  });

  test('offers one prompt after a stall', () => {
    const m = { ...base, lastHumanMessageAt: at(0), lastHumanBy: 'ana', lastCherryMessageAt: at(-1) };
    assert.deepEqual(tickAction(m, at(2)), { kind: 'stall' });
  });

  test('never prompts twice in a row for the same stall', () => {
    const m = { ...base, lastHumanMessageAt: at(0), lastHumanBy: 'ana', lastCherryMessageAt: at(2) };
    assert.equal(tickAction(m, at(5)), null);
  });

  test('sends one reminder to whoever has not replied, then waits', () => {
    const m = { ...base, lastHumanMessageAt: at(0), lastHumanBy: 'ana', lastCherryMessageAt: at(2) };
    assert.deepEqual(tickAction(m, at(10)), { kind: 'reminder', quietUser: 'ben' });
    assert.equal(tickAction({ ...m, reminderSentAt: at(10), lastCherryMessageAt: at(10) }, at(60)), null);
  });

  test('reminds both when nobody answered the opening', () => {
    const m = { ...base, lastCherryMessageAt: at(0) };
    assert.equal(tickAction(m, at(5)), null);
    assert.deepEqual(tickAction(m, at(10)), { kind: 'reminder', quietUser: null });
  });

  test('a new human message resets the cycle', () => {
    const m = { ...base, lastHumanMessageAt: at(30), lastHumanBy: 'ben', lastCherryMessageAt: at(10), reminderSentAt: at(10) };
    assert.deepEqual(tickAction(m, at(32)), { kind: 'stall' });
  });

  test('does nothing once Cherry has left', () => {
    assert.equal(tickAction({ ...base, cherryState: 'left', lastHumanMessageAt: at(0), lastHumanBy: 'ana' }, at(60)), null);
  });
});

describe('the date plan', () => {
  const details = { dish: 'Mushroom risotto', dishWhy: 'veggie and nut-free', day: 'Saturday', time: '7:00 pm' };

  test('a card needs a dish, a day, and a time', () => {
    assert.equal(planIsComplete(details), true);
    assert.equal(planIsComplete({ dish: 'Risotto', day: 'Saturday' }), false);
    assert.equal(planIsComplete({ dish: ' ', day: 'Saturday', time: '7pm' }), false);
  });

  test('it is confirmed only once both have confirmed the current card', () => {
    const card = proposePlan(noPlan(), details);
    const first = confirmPlan(card, users, 'ana', card.version);
    assert.equal(first.ok && first.bothConfirmed, false);
    assert.equal(first.plan.status, 'proposed');
    const second = confirmPlan(first.plan, users, 'ben', card.version);
    assert.equal(second.ok && second.bothConfirmed, true);
    assert.equal(second.plan.status, 'confirmed');
  });

  test('changing the card clears every confirmation', () => {
    const card = proposePlan(noPlan(), details);
    const half = confirmPlan(card, users, 'ana', card.version).plan;
    const changed = proposePlan(half, { ...details, time: '8:00 pm' });
    assert.deepEqual(changed.confirmedBy, {});
    assert.equal(changed.version, card.version + 1);
  });

  test('a tap on an outdated card does not count', () => {
    const first = proposePlan(noPlan(), details);
    const second = proposePlan(first, { ...details, dish: 'Veggie tacos' });
    assert.deepEqual(confirmPlan(second, users, 'ana', first.version), { ok: false, reason: 'outdated_card' });
  });

  test('outsiders and missing cards are refused', () => {
    const card = proposePlan(noPlan(), details);
    assert.deepEqual(confirmPlan(card, users, 'mallory', card.version), { ok: false, reason: 'not_member' });
    assert.deepEqual(confirmPlan(noPlan(), users, 'ana', 0), { ok: false, reason: 'no_plan' });
  });

  test('after "not ready", no new card until they have chatted a while, unless they ask', () => {
    const declined = { dateDeclinedAt: t0, humanMessagesSinceDecline: 2 };
    assert.equal(mayProposeDate(declined, 'haha yeah'), false);
    assert.equal(mayProposeDate(declined, 'ok actually, when are you free?'), true);
    assert.equal(mayProposeDate({ ...declined, humanMessagesSinceDecline: NOT_READY_COOLDOWN }, 'haha yeah'), true);
  });

  test('never a new card once the date is confirmed', () => {
    assert.equal(mayProposeDate({ datePlan: { status: 'confirmed', version: 1, confirmedBy: {} } }, 'plan a date!'), false);
  });

  test('the timer finishes a confirmed date before anything else', () => {
    const m = { users, cherryState: 'active', createdAt: t0, datePlan: { status: 'confirmed', version: 1, confirmedBy: {} } };
    assert.deepEqual(tickAction(m, at(0)), { kind: 'finish' });
  });
});

describe('matching', () => {
  test('match ids are the same whichever way round', async () => {
    const { matchIdFor } = await import('../lib/matching.js');
    assert.equal(matchIdFor('b', 'a'), matchIdFor('a', 'b'));
    assert.equal(matchIdFor('a', 'b'), 'a_b');
  });

  test('each person keeps their own cherry across genders', async () => {
    const { assignCherries } = await import('../lib/matching.js');
    const got = assignCherries({ uid: 'a', gender: 'Man', cherryAvatar: 'boy' }, { uid: 'b', gender: 'Woman', cherryAvatar: 'girl' }, () => true);
    assert.deepEqual(got, { a: 'boy', b: 'girl' });
  });

  test('same-gender matches get a coin flip for each person', async () => {
    const { assignCherries } = await import('../lib/matching.js');
    const flips = [true, false];
    const got = assignCherries({ uid: 'a', gender: 'Woman', cherryAvatar: 'girl' }, { uid: 'b', gender: 'Woman', cherryAvatar: 'girl' }, () => flips.shift());
    assert.deepEqual(got, { a: 'boy', b: 'girl' });
  });
});

describe('common ground', () => {
  test('finds real overlaps, most specific first', () => {
    const a = { topCuisines: ['Italian', 'Indian', 'Thai'], cuisines: ['Italian', 'Indian', 'Thai', 'Mexican'], foodType: 'Vegetarian', idealDate: 'Trying a new recipe' };
    const b = { topCuisines: ['italian', 'Japanese', 'Korean'], cuisines: ['Italian', 'Mexican'], foodType: 'Vegetarian', idealDate: 'Baking something sweet' };
    const got = commonGround(a, b);
    assert.match(got[0], /italian food in their top three/);
    assert.ok(got.some((g) => /mexican/.test(g)));
    assert.ok(got.some((g) => /Vegetarian/.test(g)));
    assert.ok(!got.some((g) => /ideal cooking date/.test(g)));
  });

  test('returns nothing when there is nothing shared', () => {
    assert.deepEqual(commonGround({ cuisines: ['Thai'] }, { cuisines: ['French'] }), []);
  });
});
