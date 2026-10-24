---
name: mascot-animation
description: "Use when creating, extending, fixing or auditing BakeOut mascot Rive animations, image-model parts, layered rigs, smooth loops or animation workflows. Builds registered assets and RML with real runtime verification. Defaults to isolated animation-only work, without Flutter changes; supports Cursor, OpenCode, Copilot and manual image-generation workflows."
---

# Mascot animation: isolated authoring and verified motion

## Read only what this task needs

1. Start with the [workshop README](../../../app/tool/README.md): boundaries, audit,
   tools, editor portability, quality gates and handoff.
2. Creation: follow the [playbook](../../../docs/new-mascot-animation-playbook.md).
3. Processing/RML/setup details: consult the
   [pipeline reference](../../../docs/mascot-animation-pipeline.md).
4. Reference implementation: [Jack](../../../app/tool/mascot_rive_jack/README.md)
   and his [character bible](../../../design/mascots/jack_rig/README.md).
5. Fresh session: use the [starter prompt](../../../docs/mascot-animation-starter-prompt.md).

## 1. Preflight and scope

- Read Git status; preserve unrelated changes. Prefer a separate worktree when
  another agent edits the app. Do not share a rig or Gemini scratch directory concurrently.
- Confirm file writes, terminal execution, Python dependencies, Rive CLI/version,
  image viewing and optional model/browser access. Do not install tools blindly.
  If read-only or missing execution rights, report the exact blocker and stop at
  an audit/plan; never claim a build, generation or visual review you did not perform.
- Default to **animation-only**. Write the selected `design/mascots/<rig>/`,
  `app/tool/mascot_rive_<rig>/`, its optional launcher and relevant docs.
  Do not touch Flutter runtime code, assets, tests, platform config or pubspecs.
- Never run `app/tool/build_mascot_rive.dart` in this mode: it auto-deploys over
  the shared shipped asset. Do not modify other rigs or shared helpers without approval.
- Audit requests do not imply regenerating art. For repairs, reproduce the defect
  in current renders before editing; treat historical reviews as hypotheses.

## 2. Agree the animation before spending credits

Agree beats, poses, expressions, props, duration, looping vs one-shot behavior,
reusable segments, UI size/background and generation budget. Record them in the
rig README. For a timing-only change, reuse existing approved art.

## 3. Generate and register

- Use one approved master on flat green `#0CF50C`. Derive poses/expressions as
  edits of that master/isolated head; keep lighting, camera and proportions.
  "Pixel-identical" is a goal: measure registration and silhouette drift.
- Generate a pose, then an arms-only matte in the same chat. Prefer vector
  dots/rays/ink/sparkles over extra model calls. Do not reroll blindly.
- Inspect each PNG before accepting it. Save untouched versioned raw files and
  exact prompts/provider provenance in the rig README.
- Prefer registered whole-head expression/blink swaps when patches visibly
  mismatch glossy skin. Overlays are acceptable only after visual checks.
- Preserve green stems/leaves during keying; inspect cream/pink/dark composites.
  Ensure shoulder/neck overlap covers the full range of motion.

### Optional web generation

Use the [Gemini helper instructions](../../../app/tool/gemini_web/README.md) only
when the connected tools support them. Discover actual MCP schemas; tool names,
file-output parameters and secret configuration vary by client. Manual
authorized image upload/download is equally valid.

Keep Chrome visible. On a stalled send/fetch, inspect page state and generation
status before retrying; avoid duplicate credit spend. Respect provider quotas;
pause or ask for an approved alternative, not account cycling to bypass limits.
Never upload source code, secrets or personal app data; only authorized art/prompts.

## 4. Rig and animate

- Adapt the Jack reference into a uniquely named rig; audit all paths, pivots,
  output names, dimensions, artboard/state-machine names, capture frames and durations.
  Do not blindly copy generated outputs or hardcoded Jack assumptions.
- Use pivoted nodes, intentional draw order, sleeve overlap, anticipation,
  overshoot, offset head bob and accessory follow-through.
- Looping tracks must match endpoints; use smooth continuous motion (`flow` in
  Jack), hold for discrete face/pose changes, and hide swaps in anticipation.
  One-shot animations instead need an intentional final hold/exit.

## 5. Verify the exact result

- Run the source builder, CLI validation/compile, then real Rive captures.
  Require successful exits and zero errors/warnings. Red stderr alone is not failure.
- Require `0 < .riv size < 4,000,000` bytes. Main and each changed reusable loop:
  seam max-channel difference <= 3/255, plus continuous-motion velocity checks.
- Inspect beat centers AND blink/pose-transition frames, pivots, gaps, clipping,
  alpha edges and target-size readability. Watch three loops in a real viewer.
- Know the verifier's coverage. Jack `--quick` omits previews/size strip; neither
  mode currently enforces size or checks every segment seam. Launcher `-Verify`
  is structural CLI validation only. Add/run missing focused checks for the task.
- Do not run verifiers simultaneously on a rig: Jack temporarily rewrites `main`
  in `rive.yaml`. Confirm config restoration. Binary rebuilds may differ in bytes.
- Never substitute an old screenshot, a static WebP or browser playback for
  native Flutter compatibility testing when integration is actually requested.

## Completion and handoff

Deliver the workshop `.riv`, artboard/state-machine names, dimensions/durations,
review images, preview commands and rig README with prompts, parts, pivots, tool
versions, exact checks/results, remaining defects and next step. State what was
not tested. Verify no new Flutter runtime changes in status/diff.

Keep the brand: cherry `#E83D55`, cream `#FFF9F3`, pink `#FFF0F2`, deep cherry
`#A71938`, charcoal `#29252A`, leaf `#73984A`.

**Stop before app integration** unless explicitly approved. Follow the workshop's
integration checklist in that case. Commit/push only when requested, stage task
files explicitly, and include the repository's co-author trailer where required.
