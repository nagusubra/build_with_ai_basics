# Workspace setup

Written October 12, 2026, after installing the skill pack into this folder.

## Tools already in use

Stay inside this set until `4-spec` chooses how the proof of concept is built:

- Node.js
- Git
- Cursor
- OpenCode

The skill installer ran through `npx`, which comes with Node. No other runtime, framework, database, or speech-to-text app was installed.

## What was installed

Command:

```text
npx skills add challengepost/learn-ai-basics --skill "*" -a cursor -a opencode -y --copy
```

`skills` npm package **1.7.2** cloned https://github.com/challengepost/learn-ai-basics and copied all six skills into:

`.agents/skills/`

That directory is the shared project location both Cursor and OpenCode read. The installer reported each skill as copied for Cursor and for OpenCode into this one folder. There are no extra copies under `.cursor/skills/` or `.opencode/skills/`.

| Skill | Files confirmed |
| --- | --- |
| `1-start` | `SKILL.md`, `templates/learner-profile-template.md` |
| `2-scope` | `SKILL.md`, `templates/scope-template.md` |
| `3-prd` | `SKILL.md`, `templates/prd-template.md`, `references/prd-guide.md` |
| `4-spec` | `SKILL.md`, `templates/spec-template.md`, `references/spec-patterns.md` |
| `5-build` | `SKILL.md`, `templates/checklist-template.md`, `references/code-tour.md` |
| `6-ship` | `SKILL.md` |

`6-ship` has no templates or references in the upstream repo. `skills-lock.json` at the repo root records the source repo and a hash for each skill.

The installer's security summary rated each skill Safe (Gen), 0 Socket alerts, and Low Risk (Snyk). Details: https://skills.sh/challengepost/learn-ai-basics

## Files added for this hackathon

- `README.md` — entry point
- `LICENSE` — MIT, so GitHub About can show an open-source license when the repo is public
- `.gitignore` — `devpost/learner-profile.md`, `.env`, `.env.*`, with `!.env.example` allowed
- `hackathon/*.md` — rules, rubric, schedule, and method
- `.agents/skills/` and `skills-lock.json` — the curriculum

`1-start` is written to add the learner-profile ignore rule itself and to keep existing gitignore lines. The rule is already present so that step can extend this file.

## What is deliberately missing

- No application source, `package.json`, or chosen framework.
- No `devpost/scope.md`, `devpost/prd.md`, `devpost/spec.md`, `devpost/checklist.md`, or `devpost/learner-profile.md`.

Those appear when you run the skills and answer them.

## Next session

Open this folder in Cursor or OpenCode and say `run 1-start`. Guide: [00-start-here.md](00-start-here.md).

Before you publish, put your name on the `LICENSE` copyright line if you want it named, and scan the repo for secrets. Creating the public GitHub repository waits for `6-ship` and your explicit go-ahead.
