# Video notes

Recording of the October 1, 2026 live build session, with Joe Holmes:

https://www.youtube.com/watch?v=sooC4QGFUUs

These are the teaching points to reuse when you brainstorm. They are notes, not a transcript.

## The problem with "just build it"

Joe opens with a comic: someone asks a computer to research the app most likely to make them rich, then build it alone. The failure he focuses on is that the human never contributed a decision. With so many people prompting the same way, the result converges on the model's average taste.

His contrasting demo is a todo app. One prompt ("make an awesome to-do list, make no mistakes, begin immediately") produced **Tally**: a polished, generic list with a green accent and a "sync across devices" feature nobody asked for. A second pass asked the model to interview him about style, features, uniqueness, and architecture, then build from those answers. That version was **Boogie Woogie**, named and designed from Piet Mondrian. Same kind of app. The difference was whose decisions were in it.

## Three practices

1. **Flipped interaction.** You are the person being interviewed. The agent asks, you answer, and those answers become the product. In the usual chat, you ask and the model dispenses an answer. Flipping that is the habit this hackathon is built on.
2. **Write the interview down.** A new chat does not remember the last one. After the interview, the agent writes organized planning documents. The next session reads `devpost/` and recovers the decisions, the motive, and where things live. In this hackathon those documents are scope, PRD, spec, and then a checklist.
3. **Build in small reviewed slices.** The spec becomes a checklist. After a slice, you run it, look, and change what is wrong. The agent checks items off as they are actually done.

## Cognitive debt

Technical debt is sloppy code you know about. Cognitive debt is code the agent wrote that you cannot explain. The next bug leaves you staring at something you have never understood, and the next chat has to reconstruct the project from files alone. Planning documents and slice reviews are how this curriculum reduces that debt. They do not erase it.

## How the interviews differ

- **Scope** turns a spark, or a set of interests, into one proof-of-concept-sized idea.
- **PRD** is a non-technical description of behavior: what a screen does, what a click feels like, where a path goes. Joe's point about unknown unknowns: the interview surfaces decisions you did not know you had skipped, such as what happens on logout.
- **Spec** is how the code is assembled: language, framework, data flow, storage. The skills ask your level first. Beginners get explanations. People who already build this way get a peer conversation.

## Two build speeds

- **Learn mode** stops at each phase and shows how that slice is built.
- **Fast mode** stops only a few times to check that nothing is broken or looks wrong.

## Speech-to-text

Joe answered the interview out loud and pasted the transcript back. He cites roughly **40 words per minute** typing and **130 words per minute** speaking, and says talking surfaces ideas that typing does not. The skill pack expects the same: speech-to-text helps, and it is optional. Use a tool you already have. This setup does not add one.

## What he asked people to do next

Register, install the skill pack inside the project folder, and start even if the idea is unfinished. The first skill asks how developed the idea is and what you are interested in. Live sessions are for brainstorming and getting unstuck. His close: the model will keep getting better at coding; the part it does not have is your particular interests, ideas, and taste. The project stands out when those are actually in the decisions.
