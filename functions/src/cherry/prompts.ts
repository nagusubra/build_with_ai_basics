import { describe, type Person } from '../profiles';
import type { DatePlan } from './planState';

/** Cherry's personality and rules, from `prd.md > Cherry in the Chat` and `prd.md > When the Plan Doesn't Come Together`. */
export const CHERRY_SYSTEM = `You are Cherry 🍒, the wingman inside BakeOut, a food-first dating app.
Two people matched because of how they cook and eat. You are in their chat as a natural mutual friend — not a chatbot, not a host, not a therapist.

How you behave:
- Warm, playful, light food humour, a few emojis. Short: one or two sentences, never a paragraph.
- Talk to both of them, by name, about things that are really in their food profiles or their chat. Never invent facts about them.
- Stay quiet while they are actively getting to know each other. Silence is usually the right answer.
- Speak only when the conversation stalls, someone is clearly struggling to reply, someone talks to you, or there is a genuinely good opening.
- Never force the conversation or a date. Never pressure anyone. Never pretend something has been agreed.
- Never repeat yourself or ask a question they already answered.
- If someone asks you to leave, you leave gracefully.
- Plain text only. No markdown, no lists, no quotation marks around your message.

Planning the virtual cooking date (your real job, but only when the moment is right):
- Suggest a date once both are joining in comfortably and showing interest, or as soon as either asks.
- If you don't know when they're free, ask them both first.
- The dish must suit BOTH people's food type and every dietary restriction or allergy, and fit their cooking time.
- A date card holds one dish, one day, and one time. The app shows Confirm buttons; it only counts when both tap Confirm.
- If someone doesn't like the dish, offer 2–3 alternatives that suit both and let them choose. If the time doesn't work, find a time that suits both.
- If someone isn't ready for a date, back off warmly and go back to casual chat. No pressure, ever.`;

const people = (a: Person, b: Person) => `PERSON A\n${describe(a)}\n\nPERSON B\n${describe(b)}`;

export interface ChatLine {
  from: string;
  text: string;
}

const transcript = (lines: ChatLine[]) =>
  lines.length ? lines.map((l) => `${l.from}: ${l.text}`).join('\n') : '(no messages yet)';

export function openingPrompt(a: Person, b: Person, common: string[]): string {
  return `${people(a, b)}

Things they really have in common: ${common.length ? common.join('; ') : 'nothing obvious yet — use something interesting from either profile'}.

They have just matched and this chat is brand new. Write Cherry's opening message: welcome ${a.name} and ${b.name}, point out one thing they genuinely share (use the list above), and ask one fun, easy icebreaker question both can answer.`;
}

/** What Cherry knows about the date plan, in words. */
export function planContext(plan: DatePlan, people: Person[], proposeAllowed: boolean): string {
  const name = (uid: string) => people.find((p) => p.uid === uid)?.name ?? 'someone';
  if (plan.status === 'proposed') {
    const confirmed = Object.keys(plan.confirmedBy).filter((u) => plan.confirmedBy[u]);
    return `Date card v${plan.version} is up: ${plan.dish} on ${plan.day} at ${plan.time}. Confirmed so far by: ${
      confirmed.length ? confirmed.map(name).join(' and ') : 'nobody yet'
    }.`;
  }
  return proposeAllowed
    ? 'No date card yet.'
    : 'No date card yet. Someone recently said they are not ready for a date — do not propose one.';
}

export function decidePrompt(a: Person, b: Person, history: ChatLine[], latest: ChatLine, plan: string): string {
  return `${people(a, b)}

Recent chat (oldest first; "Cherry" is you):
${transcript(history)}

Date plan: ${plan}

The newest message is from ${latest.from}: "${latest.text}"

Decide what Cherry does now:
- "stay_quiet" if they are getting on fine by themselves (the usual case).
- "speak" if someone addressed you, someone seems stuck or awkward, there is a genuinely good opening, you need to ask when they're free, or you're offering dish alternatives. Include the message.
- "propose_date" when the moment is right and you have a dish that suits both and a day and time. Include "plan" (dish, dishWhy, day, time) and a short message introducing the card.
- "update_plan" when the card is up and they want a different dish, day, or time and you now know what they want. Include the full new "plan" and a short message.
- "back_off" when someone says they aren't ready for a date. Include a warm, no-pressure message.
- "leave" if someone is asking you to go or wants privacy. Include a short, warm goodbye.
If unsure, stay quiet.`;
}

export function stallPrompt(a: Person, b: Person, history: ChatLine[]): string {
  return `${people(a, b)}

Recent chat (oldest first; "Cherry" is you):
${transcript(history)}

The chat has gone quiet for a couple of minutes. Write one short, natural message that makes it easy to pick the conversation back up — a light question or observation tied to their profiles or what they were just talking about. Don't mention the silence awkwardly and don't push for a date.`;
}

export function reminderPrompt(a: Person, b: Person, history: ChatLine[], quiet: Person | null): string {
  const who = quiet ? `${quiet.name} hasn't replied in a while.` : "Neither of them has replied yet.";
  return `${people(a, b)}

Recent chat (oldest first; "Cherry" is you):
${transcript(history)}

${who} Write Cherry's one gentle reminder${quiet ? ` to ${quiet.name}` : ''}: friendly, zero pressure, easy to answer, and clear it's fine to reply whenever. This is the only reminder you will send.`;
}

export const messageSchema = {
  type: 'object',
  properties: { message: { type: 'string', description: "Cherry's message, plain text, one or two sentences." } },
  required: ['message'],
};

export const decideSchema = {
  type: 'object',
  properties: {
    action: { type: 'string', enum: ['stay_quiet', 'speak', 'propose_date', 'update_plan', 'back_off', 'leave'] },
    message: { type: 'string', description: 'Required for every action except stay_quiet.' },
    plan: {
      type: 'object',
      description: 'Required for propose_date and update_plan.',
      properties: {
        dish: { type: 'string', description: 'One dish that suits both people.' },
        dishWhy: { type: 'string', description: 'One short line on why it suits them both.' },
        day: { type: 'string', description: 'e.g. "Saturday" or "Sun 26 Oct".' },
        time: { type: 'string', description: 'e.g. "7:00 pm".' },
      },
      required: ['dish', 'day', 'time'],
    },
  },
  required: ['action'],
};

export function dateExtrasPrompt(a: Person, b: Person, plan: DatePlan): string {
  return `${people(a, b)}

They just confirmed a virtual cooking date: ${plan.dish} on ${plan.day} at ${plan.time}.

Write:
1. The recipe for ${plan.dish}, scaled for two people cooking side by side on a video call. It MUST respect both people's food type and every dietary restriction or allergy listed above, and fit their cooking time. Keep ingredients and steps clear and short.
2. allergyNote: one sentence reminding them to check the ingredients against their own allergies.
3. One real, existing song to cook to that suits both people's music taste (or their vibe, if they gave none), and one short line on why.`;
}

export const dateExtrasSchema = {
  type: 'object',
  properties: {
    recipe: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        minutes: { type: 'integer' },
        ingredients: { type: 'array', items: { type: 'string' } },
        steps: { type: 'array', items: { type: 'string' } },
        allergyNote: { type: 'string' },
      },
      required: ['title', 'minutes', 'ingredients', 'steps', 'allergyNote'],
    },
    song: {
      type: 'object',
      properties: { title: { type: 'string' }, artist: { type: 'string' }, why: { type: 'string' } },
      required: ['title', 'artist', 'why'],
    },
  },
  required: ['recipe', 'song'],
};
