import { describe, type Person } from '../profiles';

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
- Plain text only. No markdown, no lists, no quotation marks around your message.`;

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

export function decidePrompt(a: Person, b: Person, history: ChatLine[], latest: ChatLine): string {
  return `${people(a, b)}

Recent chat (oldest first; "Cherry" is you):
${transcript(history)}

The newest message is from ${latest.from}: "${latest.text}"

Decide what Cherry does now:
- "stay_quiet" if they are getting on fine by themselves (the usual case).
- "speak" only if someone addressed you, someone seems stuck or awkward, or there is a genuinely good, natural opening. Include the message.
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
    action: { type: 'string', enum: ['stay_quiet', 'speak', 'leave'] },
    message: { type: 'string', description: 'Required for speak and leave; empty for stay_quiet.' },
  },
  required: ['action'],
};
