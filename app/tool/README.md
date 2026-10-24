# Animation workshop: build without changing Flutter

This is the entry point for making BakeOut mascot animations in **any editor**.
Animation authoring and app integration are separate tasks. By default, deliver a
reviewed animation in its workshop folder and **stop before changing the app**.

- Start a session with the [copy/paste starter prompt](../../docs/mascot-animation-starter-prompt.md).
- Follow the [creation playbook](../../docs/new-mascot-animation-playbook.md).
- Consult the [technical pipeline](../../docs/mascot-animation-pipeline.md) for image processing and RML.
- Compatible agents can load the [mascot-animation skill](../../.agents/skills/mascot-animation/SKILL.md).

## 1. The isolation boundary

```text
design/mascots/<rig>/raw/             original image-model outputs
             master.png + README.md  approved character, prompts, decisions
             parts/ + rig metadata   registered parts and pivots
                         |
app/tool/mascot_rive_<rig>/           Python builder, verifier, runtime layers
                         |
                 scene.rml + rive.yaml
                         |
                 Rive CLI -> build/  .riv + review images + previews
                         |
                 standalone preview / user approval
------------------------- STOP: animation-only task ends here -----------------
                 explicit, separately approved app integration
                         |
app/assets/mascots/                  shipped .riv and static poster
app/lib/                            pose mapping, widget and screen wiring
```

The Flutter asset manifest includes `assets/mascots/` and `assets/mascots/rive/`,
**not** this workshop or `design/`. The Python builders and Rive CLI do not need a
Flutter build, Firebase, an emulator, Dart, or an app hot reload.

### Allowed changes for an animation-only task

- Its **own** `design/mascots/<rig>/` and `app/tool/mascot_rive_<rig>/`.
- Its own optional preview launcher in this folder.
- Directly relevant animation docs; shared helper/skill changes only if requested.

Do not edit or copy files into `app/lib/`, `app/assets/`, `app/test/`,
`app/integration_test/`, platform folders, pubspecs or lockfiles. Do not modify
another rig's master, generated parts, scenes or shipped assets. Read existing app
code only to understand the future interface.

These are workflow rules, **not a sandbox**. An agent with shell access can still
cross the boundary. Check the diff and use the worktree isolation below.

## 2. Audit: what is isolated today?

Audited 2026-10-24 at base commit `834b0c0`. This is a workflow audit, not an assertion
that every historical visual defect is fixed.

| Surface | Observed behavior | Decision |
|---|---|---|
| [Jack builder](mascot_rive_jack/build_jack.py) | Reads Jack raw art; writes Jack design parts/metadata, workshop layers, RML and config only | Recommended template; no app deployment |
| [Jack verifier](mascot_rive_jack/verify_jack.py) | Compiles/captures under its `build/`; temporarily switches `rive.yaml` for segment captures and restores it in `finally` | Isolated from Flutter; run one verifier per rig at a time |
| [Duo builder](mascot_rive_duo/build_proof.py) and [verifier](mascot_rive_duo/verify_proof.py) | Write their workshop layers, RML, config and captures | Isolated, but preserve as an existing production reference |
| [Jack launcher](preview_mascot_jack.ps1) | Default serves the workshop on loopback; other modes invoke the Rive CLI | Does not deploy; stop the foreground server with Ctrl+C |
| [Duo launcher](preview_mascot_duo.ps1) / [legacy launcher](preview_mascot.ps1) | Preview/build within workshop projects | Do not confuse preview with publishing to Flutter |
| [Legacy Dart builder](build_mascot_rive.dart) | **Automatically overwrites** `app/assets/mascots/rive/cherry_mascots.riv`; `--only` can replace the shared file with a subset | **Not animation-only. Do not run for new isolated work.** No new no-copy flag is implied |
| [Gemini helpers](gemini_web/README.md) | Write ignored scripts/dumps next to themselves; `grab.py` saves to the caller's destination | Choose a new rig destination; shared scratch names are not concurrency-safe |
| [Flutter manifest](../pubspec.yaml) | Only shipped asset folders are bundled | Workshop output is not automatically included |
| [Flutter widget](../lib/widgets/mascot_rive.dart) | Multi-asset loaders exist; web, disabled/reduced motion and failures use posters | New artboards still need explicit pose/screen integration; Jack is not currently wired in |
| Prior docs/skill | Shipping was part of every task; Gemini MCP tool names were assumed universal | Updated to opt-in integration, portable tool discovery and explicit blockers |

### Verification performed during this audit

- Ran Jack's source builder and `verify_jack.py --quick` with Rive CLI **1.7.0**,
  Python **3.12.5**, NumPy **2.5.3**, Pillow **12.0.0**.
- Rive: **0 errors, 0 warnings**; compiled output **912,034 bytes**;
  full-loop maximum per-channel seam difference **0**.
- SHA-256 before/after: **205 tracked, non-documentation app files outside
  `app/tool/` unchanged**, including shipped assets and Dart code.
- Opened the freshly rendered Jack review and existing Duo review. No artwork or
  motion was changed. This audit did not re-run Duo's full frame capture, record
  three live loops, or certify every segment seam.
- The regenerated workshop `.riv` differed from its committed bytes; only that
  audit-generated binary change was discarded. Do not assume byte-identical
  rebuilds or use binary equality as a motion-quality test.

### Known limitations to keep visible

1. Jack's quick verifier checks the main seam and samples segments at frames 0/40.
   It **does not** enforce the size budget, test every segment's seam, generate the
   small-size strip, or perform a full frame-diff analysis. The full verifier adds
   previews and the strip, but not those extra assertions. Check size separately;
   test each reusable segment's seam when authoring/changing it.
2. `-Verify` on the PowerShell launcher means **CLI structural validation only**;
   it is not equivalent to running the Python verifier.
3. The browser preview fetches `@rive-app/canvas@2` from unpkg. It needs network
   access and floats within major version 2; it is not a pinned offline toolchain.
   Record the resolved version for release QA, or use the native CLI preview.
4. The launcher uses `%USERPROFILE%\.rive\bin\rive.exe` for its CLI modes.
   The Python verifier also supports `rive` on PATH. Use the direct CLI on other
   machines; no portability claim is made for the Windows launcher itself.
5. Gemini selectors and synthetic paste are website-dependent. Sending a prompt
   is not proof of successful generation; validate attachment, response and saved
   PNG. Manual web upload/download is a supported fallback.
6. Existing captures may include the CLI's dark background. They do not prove
   transparent poster export or acceptable edges on light backgrounds.
7. No end-to-end editor-switch test was performed. Portability below is grounded
   in official documentation; local tools, permissions and login still need checking.

## 3. Organization and naming for every new rig

Use a unique lowercase identifier, for example `jack_recipe_tip`:

| Location | Keep here |
|---|---|
| `design/mascots/<rig>/` | Character README, approved `master.png`, untouched versioned `raw/`, generated `parts/`, pivots/registration metadata |
| `app/tool/mascot_rive_<rig>/` | Builder, verifier, processing helpers, `assets/`, `scene.rml`, `rive.yaml`, README, optional live preview |
| `app/tool/mascot_rive_<rig>/build/` | Compiled `.riv`, selected review/size strips and previews; ignore temporary captures |
| `docs/` | Shared workflow/reference docs, not per-generation scratch |
| `.agents/skills/mascot-animation/` | One canonical skill, not editor-specific copies |

Adapt Jack rather than moving or renaming established rig folders. Do not blindly
copy its `build/`, `assets/`, generated scene, raw art or identifiers into a new rig.
Audit `RIG`, `RAW`, `PARTS`, `ASSETS`, `BUILD`, output name, artboard/state-machine
names, pivots, dimensions, timings, verifier beats and preview URL. Its processing
helper is reusable, but its builder and verifier are character-specific.

In the new rig's ignore file, ignore `__pycache__/` and scratch captures, explicitly
allowing the final `.riv` and selected review artifacts. Commit source, authorized
raw art, prompts, layers and metadata required to rebuild. Do not commit login
state, tokens, dumps or arbitrary browser downloads.

## 4. Working safely with parallel app development

Prefer a separate Git worktree. From a clean repository root, choose a new sibling
directory and unused branch name:

```powershell
git worktree add -b animation/jack-recipe-tip ..\bakeout-animation-jack-recipe-tip HEAD
```

Open that sibling directory as the editor workspace. It shares Git objects but not
the app team's working files. Do not launch a second agent on the same rig or the
shared Gemini scratch directory. A worktree avoids file collisions, not mistakes
on merge: review changed paths before merging.

At session start and finish:

```powershell
git status --short
git diff --name-only HEAD -- app
git diff --check
```

In animation-only mode, changed app paths must be workshop files or relevant docs,
not runtime code/assets/config. `git status` also catches new untracked files,
which `git diff` omits. If the starting tree is dirty, record its existing paths
and preserve them; never use `git add -A` or revert another session's changes.

## 5. Tools: required, optional and editor-specific

| Capability | Required for | Alternatives / restrictions |
|---|---|---|
| File edits and terminal execution | Build/repair | Enable an agent mode with write/execute permissions. Read-only agents can audit only; report the limitation, don't claim completion |
| Python + NumPy + Pillow | Image processing and verification | Use a local environment; install only if missing. No Flutter dependencies needed |
| Rive CLI | Compile, validate, real captures, native preview | Record `rive --version`; consult `rive --help` / `rive schema` rather than inventing RML properties |
| Image model | New art/expressions | Authorized Gemini/ChatGPT UI or another approved image service; not required for timing-only edits |
| Playwright MCP + logged-in Chrome | Optional automated web generation | Manual upload/download works. Match the client's actual tools; no MCP is required to build saved art |
| Browser or native Rive viewer | Playback review | Web preview uses JS/WASM; native preview avoids its CDN dependency |
| Flutter SDK/device | **Only app integration** | Not part of standalone authoring |

For an existing Jack rebuild, from the repo root:

```powershell
python --version
python -m pip show numpy pillow
& "$env:USERPROFILE\.rive\bin\rive.exe" --version
python app\tool\mascot_rive_jack\build_jack.py
if ($LASTEXITCODE -ne 0) { throw "Source build failed" }
python app\tool\mascot_rive_jack\verify_jack.py --quick
if ($LASTEXITCODE -ne 0) { throw "Runtime verification failed" }
```

For final animation QA, run the verifier **without** `--quick`, inspect its PNGs,
and watch at least three loops in the native or browser preview:

```powershell
python app\tool\mascot_rive_jack\verify_jack.py
.\app\tool\preview_mascot_jack.ps1
# Alternative: .\app\tool\preview_mascot_jack.ps1 -Native
```

The foreground server binds to `127.0.0.1`; Ctrl+C stops it. A browser tab left
open after shutdown will not work until the server is restarted. Use a different
`-Port` if occupied; never terminate an unidentified process.

Exit code **and** diagnostics matter. Rive writes normal logs to stderr.
PowerShell's red log text alone does not imply failure; require a successful exit
and zero errors/warnings. Do not ignore a nonzero exit just because a file exists.

## 6. Editor portability and MCP

Official docs checked 2026-10-24:

| Client | Instructions / skill | Setup |
|---|---|---|
| Cursor | Root `AGENTS.md`; `.agents/skills/mascot-animation/SKILL.md` | Agent mode with terminal/image viewing; confirm skill discovery |
| OpenCode | Root `AGENTS.md`; the same `.agents/skills/` location | Use a write-capable agent; Plan/read-only mode cannot finish a build |
| Copilot / VS Code | Root `AGENTS.md` where supported; the same `.agents/skills/` location | Open repo root; check customization discovery and workspace permissions |
| Other tools / older clients | Explicitly attach the starter prompt, workshop README and skill | Do not assume automatic skill or instruction discovery |

No `.opencode` session history or editor-specific MCP config is required to rebuild.
The portable context is the files in Git, not a previous agent's chat memory.
Do not duplicate the skill into each editor's folder; copies drift.

MCP is a protocol, not a guarantee of identical configuration or tool signatures.
The existing pipeline's `servers`/`inputs` JSON example is **VS Code-specific**.
Configure the equivalent local stdio server in the destination client's MCP settings:

- Executable: `npx` (Node/npm required for this optional route).
- Arguments: `@playwright/mcp@<tested-version>`, `--extension`.
- Environment: `PLAYWRIGHT_MCP_EXTENSION_TOKEN` from that client's secret input or
  a locally supplied environment, never a committed literal.

The pipeline's `@latest` example is convenient for initial setup, not reproducible
version pinning. Record your working package version and browser/extension version
in the rig README. Do not blindly copy VS Code `${input:...}` syntax to another client.
Choose any local server ID (for example `playwright`); it is a label, not the token.

Discover the connected tools first. `browser_run_code_unsafe` and file-output
arguments are specific to the bridge used originally, not universal requirements
of Playwright MCP. If the client only offers a code-string runner, read the local
generated script and submit it using that tool's documented schema. If it cannot
save a data URL response directly, use an approved local download or manual save;
do not paste a megabyte image into chat or invent a `filename` argument.

Only upload authorized character images/prompts, not source code, credentials or
personal user data. Keep the browser visible for the existing Gemini scripts.
If sending/fetching stalls, inspect the actual page and response before retrying;
do not create duplicate paid generations. Respect provider limits. Pause or ask
for an approved alternative provider rather than cycling accounts to evade quotas.

## 7. Quality and completion gates

Before declaring an **animation** finished:

1. Approved storyboard, size, duration and asset budget; no image generation before approval.
2. Single master; preserve camera/lighting, register every edit and measure alignment.
   "Pixel-identical" is a prompt goal, not a model guarantee.
3. Review full heads/expressions first. Prefer a registered whole-head swap when
   eye patches expose smudges or shading mismatches; overlays require evidence
   that they preserve face lighting and silhouette.
4. Check alpha edges on cream, pink and dark backgrounds; green stems/leaves must
   survive keying. Include neck/sleeve overlap so no gaps appear at maximum rotation.
5. Rive validates with zero errors/warnings; nonempty `.riv` **under 4,000,000 bytes**.
   Check the file size explicitly if the chosen verifier doesn't enforce it.
6. Main loop **and each changed reusable looping artboard**: maximum channel
   difference at the seam <= 3/255; check velocity continuity for continuous motion.
   A matching first/last image alone does not prove smoothness.
7. Inspect expression/blink and pose-transition frames, not only beat centers;
   compare at actual UI size and watch three loops for pops, frozen holds and clipping.
8. Deliver `.riv`, artboard/state-machine names, dimensions/duration, review images,
   preview instructions, static-poster plan and exact validation results.
9. Review the Git diff: no new Flutter runtime changes or deployment. Record any
   unperformed checks honestly. Commit/push only when requested, staging task files explicitly.

The older pasted visual review is useful as a defect checklist, not proof about
the current rig. Reproduce a defect in current renders before changing art.

## 8. Explicitly approved app integration (separate task)

Only after animation approval: copy the accepted `.riv` and matching transparent
poster into the shipped asset folders, add the required `MascotPose`/screen mapping,
and use `AnimatedMascot` with `animationAsset`/`posterAsset`. Preserve the existing
loader selection and failure logging. Do not replace the shared seven-pose file
to install a standalone rig.

An unchanged-path replacement can avoid Dart edits **only** if artboard names,
default state machine, dimensions/layout behavior and runtime features remain
compatible. It still changes shipped app behavior and requires integration QA.
A genuinely new animation is not automatically selectable by Flutter today.

Run focused Flutter tests and analyze, hot reload/restart a connected app when
available, and test on the intended native renderer. Confirm web/static fallback,
reduced motion, missing/failed asset and startup behavior. A browser preview alone
does not certify the Flutter native renderer. See the
[app integration reference](../../docs/mascot-animation-pipeline.md#8-flutter-integration)
and [app README](../README.md#mascot-motion).

## 9. Save a handoff for switching agents

Put this in the rig README before stopping:

```text
Rig / branch / base commit:
Approved scope, target size/background, beats and duration:
Master and raw part versions; prompts and provider provenance:
Tool versions; build and preview commands:
Output .riv and artboard/state-machine names:
Checks run (commands + results); checks NOT run:
Current defects / rejected variants / next step:
Allowed edit paths; Flutter integration approved? NO by default:
```

Do not copy tokens or private browser session state into the handoff.

## 10. Primary references

These informed the workflow/skill updates; they are not requirements to install
another editor or replace the working toolchain.

- [Agent Skills specification](https://agentskills.io/specification): portable frontmatter and progressive disclosure.
- [Cursor skills](https://cursor.com/docs/skills) and [rules](https://cursor.com/docs/rules): shared skills directory and `AGENTS.md`.
- [OpenCode skills](https://opencode.ai/docs/skills/) and [rules](https://opencode.ai/docs/rules/): shared discovery and instruction scope.
- [VS Code skills](https://code.visualstudio.com/docs/agent-customization/agent-skills): supported paths and discovery limitations.
- [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp): extension mode, client setup and available tools.
- [Rive CLI](https://rive.app/docs/cli/overview), [commands](https://rive.app/docs/cli/reference/commands) and [RML](https://rive.app/docs/runtimes/advanced-topic/rml): compile/validate/render workflow.
- [Rive web parameters](https://rive.app/docs/runtimes/web/rive-parameters): `stateMachine` (singular), load callbacks and runtime options.
