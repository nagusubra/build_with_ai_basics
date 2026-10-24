# Starter prompt: an isolated BakeOut animation

Paste the block below into a write-capable agent in Cursor, OpenCode, Copilot or
another editor, with the **repository root** open. Replace the bracketed values.
You do not need the previous chat or a running Flutter app.

```text
Create a new BakeOut mascot animation in ANIMATION-ONLY mode.

Rig ID: [unique_lowercase_name]
Character: [Jack / Jill / both / new character]
Reference/master: [existing repo image path, or ask me to choose]
Target placement and size: [e.g. chat header, 120 px]
Background: [e.g. cream #FFF9F3; also check pink and dark]
Story beats: [e.g. thinks -> gets idea -> writes -> smiles]
Duration and playback: [e.g. 8 seconds, seamless loop]
Reusable segments: [e.g. Think, Idea, Write, Smile, each looping]
Style: cute, bubbly, polished soft-3D BakeOut cherry mascot; preserve the brand.
Image-generation budget: [maximum new generations; ask if unspecified]

First read AGENTS.md and app/tool/README.md, then load
.agents/skills/mascot-animation/SKILL.md if supported. Otherwise read it explicitly.
Follow docs/new-mascot-animation-playbook.md and consult
docs/mascot-animation-pipeline.md for technical details.

Start with git status and a capability check: file writes, terminal execution,
Python/NumPy/Pillow, Rive CLI, image viewing, and optional browser/image generation.
Use a separate worktree if another session is changing the app. Do not assume you
can access a previous editor's history, MCP connection, login or tools.
If you are read-only or cannot build/view images, explain the exact blocker and
what permission/tool is needed; do not claim to have completed an animation.

Show me a short storyboard, proposed parts/expressions, timings and generation
budget for approval BEFORE generating images. Ask only for missing decisions.
Prefer reusing approved art for timing-only work. For new art, make one master
and derive registered edits from it. Inspect each result; don't assume the
model honored "pixel-identical". Record prompts and raw versions in the rig README.

Allowed writes by default:
- design/mascots/[Rig ID]/
- app/tool/mascot_rive_[Rig ID]/
- a dedicated preview launcher and directly relevant animation docs

Do NOT edit app/lib, app/assets, Flutter tests/integration tests, platform files,
pubspecs or lockfiles. Do NOT run app/tool/build_mascot_rive.dart: it auto-copies
over a shipped asset. Do NOT modify existing rigs or deploy this rig to Flutter.
If a shared helper/skill needs changing, explain why and ask before expanding scope.

Use the Jack workshop as a reference, not a blind folder copy. Update all
rig-specific paths, pivots, names, output names, artboard durations, verifier
frames and preview settings. Keep output inside this rig's build folder.
Discover actual MCP tool schemas instead of assuming VS Code tool names work
in this editor. Manual authorized image upload/download is fine. Keep secrets
local, respect provider limits and don't generate repeatedly on a stalled page.

Build and verify with the real Rive runtime. Require zero errors/warnings,
a nonempty .riv under 4,000,000 bytes, and seam max-channel difference <= 3/255
for the main loop AND changed reusable looping artboards. Check motion continuity,
transition/blink frames, transparent edges on light/dark, shoulder/neck overlap
and readability at the target size. Open the renders and watch at least 3 loops.
Report any checks your tools could not perform; do not substitute source inspection
or an old screenshot for runtime evidence.

Deliver the workshop .riv, artboard/state-machine names, dimensions/durations,
review images, a usable standalone preview, reproduction commands, prompts and
a handoff section in the rig README. Confirm the diff contains no new Flutter
runtime changes. Stop at animation approval; integration is a separate request.
Do not commit or push unless I ask. Never stage unrelated files.
```

## Short version for an existing rig

```text
Use the mascot-animation skill and app/tool/README.md in animation-only mode.
Rig: [path]. Change only: [specific motion/visual defect].
Reproduce the defect in current Rive renders first. Preserve all unrelated art,
timing and Flutter files. Ask before generating new images or changing shared
helpers. Rebuild, inspect transition frames and target-size playback, check every
changed loop seam, and record exact results and remaining blockers. Do not deploy.
```

## Separate integration request (only after approving the animation)

```text
I approve [workshop .riv path + revision] for Flutter integration at [screen].
Keep other mascot assets unchanged. First explain the asset/poster, pose mapping,
renderer and fallback changes required. Then integrate this accepted revision,
run focused tests and analyze, and verify the target native runtime plus web,
reduced-motion and load-failure fallbacks. Hot reload/restart a connected app.
If device access is unavailable, report the unverified checks explicitly.
```

For a comprehensive workflow map and the dated isolation audit, see the
[animation workshop README](../app/tool/README.md).
