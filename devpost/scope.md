---
doc: scope
status: approved
---

# BakeOut

A Flutter dating app where people match over how they cook and eat, and a cherry-shaped AI wingman takes a new match from "hi" to a planned virtual cooking date — then leaves them to it.

## The Unique Kernel
After a match, the AI wingman steps in as a middle person, breaks the ice, and keeps pushing until the two people have a virtual cooking date set: a fixed time, a dish they both confirmed, the recipe, and a song. Then it leaves the chat forever with "now it's on you two how you bake this out further."

No dating app the team researched does anything close to this.

## Who It's For
An introvert who isn't a small-talk person and who loves food. On today's dating apps they find it hard to get a match, and even after matching, "so hard to think of even one reply." Today they swipe, stall on the first message, and the match goes nowhere.

The team is building this for themselves first: in the past 2–3 days, 23 of the 25 people they shared the idea with said they want to try it.

## The Core Loop
They set up a profile built around their cooking and eating habits rather than a normal dating profile, and verify with a picture so everyone they meet is a real person. They see someone, swipe right, and match. Instead of an empty chat, their cherry wingman appears and starts the conversation for both of them, helps them get to know each other, and steers toward a date. The wingman picks a dish based on both people's food choices, confirms it with them, shares the recipe in the chat, suggests a song, and locks in a time. Then it says goodbye and leaves, and the two people keep talking on their own.

They come back because every new match gets a wingman-led path to a real shared experience instead of a dead chat.

## Inspiration & Identity
- **Mascot:** the wingman is a cherry — a male cherry on the guy's side and a female cherry on the girl's side.
- **Feel:** a good, comfortable interface that makes someone who finds dating apps overwhelming feel at ease instantly. Fun, warm, food-led.
- **Tone:** playful food language, e.g. "bake this out."
- **Insight behind it:** eating habits reflect a person at a much deeper level than random talk; people with similar eating habits tend to mingle more, even as friends.

## Why This Matters to the Learner
Vinamra is an introvert who isn't into small talk and finds current dating apps too hard: "despite all the development the core of dating apps never really upgraded." Both he and Subu love cooking. They want to "build something I wish should have existed."

## What "Working" Looks Like
Two real people on two phones. Each sets up a food-centered profile and passes picture verification, they see each other, swipe right, and match instantly. The cherry wingman appears in a shared chat on both sides, starts the conversation, helps them get to know each other, then sets up the date: picks a dish from their choices, confirms it with both, posts the recipe, suggests a song, and fixes a time. It signs off — "now it's on you two how you bake this out further" — and leaves. The two keep chatting without it.

**The "oh, that's cool" beat:** the cherry wingman turning a fresh match into a confirmed cooking date, then stepping out of the chat.

The demo video wraps this in a short opening skit (two people tired of dating apps, bored while cooking, nudged by a WhatsApp-style message to try BakeOut) and a closing behind-the-scenes look. Those are video content, handled in `6-ship`, not app features.

## The POC Boundary
- Quick food-centered profile setup (cooking and eating habits).
- Picture verification during profile setup, so there are no fake people or profiles. Added after the first draft: "it should not be very hard as there are a lot of libraries and things available." It's a real build, not simulated. The wingman stays the priority.
- The two users see each other, swipe right, and match. A couple of profiles is enough; no matching at scale.
- After the match, the wingman joins a live chat between the two real users and breaks the ice.
- The wingman guides them to a date: time, a dish both confirm, the recipe in chat, a song suggestion.
- The wingman signs off and permanently leaves; the two users continue chatting.
- A polished, comfortable UI with the cherry mascot — the interface is part of what the demo sells.

## Open Questions for Later Phases
- **Picture verification:** what exactly counts as "verified" (`3-prd`), and whether it runs on the phone or through an outside service, plus how face data is handled (`4-spec`).
- **Wingman behavior:** what it asks to help them get to know each other, and how it decides it's time to move to the date (`3-prd`).

## Later
- Food filters for search (vegan, vegetarian, baking, and so on), alongside normal dating filters. The team may revisit these once the core path works.
- Real matching across many users.
- The virtual cooking date itself (for example, an in-app video call).
- Playing music in-app, rather than suggesting a song.

## Explicitly Cut
None so far.
