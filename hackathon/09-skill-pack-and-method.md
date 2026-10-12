# Skill pack and method

Source: https://github.com/challengepost/learn-ai-basics and the installed skills in `.agents/skills/`.

The organizer email calls the method **Orient → Plan → Build → Ship**. The skill pack is that method in six steps. The agent interviews you. You supply the ideas and the decisions. The agent organizes them into files so a new chat can continue without remembering the old one.

Install command, already run in this folder:

```text
npx skills add challengepost/learn-ai-basics --skill "*" -a cursor -a opencode -y --copy
```

The hackathon's generic command is `npx skills add challengepost/learn-ai-basics --all -y`. This repo targeted Cursor and OpenCode and copied the files so Windows did not need symlinks.

## The six skills

| Skill | What happens | Output |
| --- | --- | --- |
| `1-start` | Orient. Check the folder, explain the path, interview you about the idea and your experience. | `devpost/learner-profile.md` |
| `2-scope` | Find or sharpen the idea, name its kernel, define done, keep it proof-of-concept sized. | `devpost/scope.md` |
| `3-prd` | Product interview: screens, layout, visual style, behavior, edge cases, and a firm now/later line. No code talk. | `devpost/prd.md` |
| `4-spec` | Technical plan: clarify an unknown, compare options, agree how it will be built. | `devpost/spec.md` |
| `5-build` | Build in verified slices, review, revise, then a short learning wrap-up. | `devpost/checklist.md`, the app, `devpost/app-map.html` |
| `6-ship` | Demo video, public repository, and submission answers you write. | Video, public repo, your Devpost submission |

Invoke a skill by name (`run 1-start`, then `2-scope`, and so on). Starting a fresh conversation between skills is expected. There is no separate progress file. `devpost/` is the state.

## How progress is recorded

- `scope.md`, `prd.md`, `spec.md`, and `checklist.md` use frontmatter `status: draft` or `status: approved`.
- A draft is saved as soon as one exists. Status flips to `approved` when you clearly approve the plan on screen. "Looks good" counts. Silence does not. A second sign-off is not required.
- `learner-profile.md` stores experience, pacing, and optional learning context. It is gitignored. It is personal context, not a submission artifact. Ignoring it does not make the AI chat private.
- Scope, PRD, and spec usually aim for four or five meaningful exchanges, then draft. You can keep exploring.
- The PRD includes one or two design questions so the look does not default to a generic AI style.
- Optional HTML companions may exist for scope, PRD, and spec. The build checklist stays Markdown.

Every skill starts by reading `devpost/`, saying where you are, and routing you to the unfinished step. Template files and empty placeholders do not count as progress.

## Build modes

Chosen at build time and remembered if you resume:

- **Learn mode.** A hands-on check and a short code orientation after every slice.
- **Fast mode.** Still verifies, with fewer pauses: useful early feedback and a final review. Extra checkpoints only when they help.
- A tiny one-slice build can combine those reviews.

## Learning wrap-up

Name one thing you want to practice or understand, if you have one. After the final review, a few minutes connect a real moment in the project to a practice you can reuse. Newcomers follow one action through two or three code locations, with an optional tiny edit. People who already work plan-first can revisit a real uncertainty, a verified change, or a planning decision. You also get a compact app map with code pointers. A short reflection is optional. It is not a quiz.

## Shipping rules inside `6-ship`

- The demo video and the public repository are both required. Deployment and peer feedback are optional.
- You write the project name, description, other form fields, and exit-survey answers.
- The agent can ask questions and fix spelling and grammar. It does not draft or rewrite your public copy, including any optional Discord post.

## Pacing

Onboarding asks about coding experience and about plan-first experience separately. Newcomers get guided, one-question-at-a-time support. If you already plan before you build, you can ask for concise explanations or for two or three related questions at a time. Those preferences carry forward.

Speech-to-text fits this format. The live session notes explain why: [10-video-notes.md](10-video-notes.md).
