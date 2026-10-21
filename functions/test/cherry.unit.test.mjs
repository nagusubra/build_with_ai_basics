import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

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
