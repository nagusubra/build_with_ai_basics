---
name: mascot-animation
description: Create a new BakeOut mascot animation from scratch. Generates each body part, pose, expression and prop with an image model (Gemini via the Playwright MCP extension), keys and registers them onto one master, rigs them in code-generated Rive RML, and verifies with real Rive renders. Use when asked to make, extend or fix a layered mascot Rive animation (Jack, Jill or a new character).
---

# mascot-animation: piece-by-piece AI mascot animation

Follow `docs/new-mascot-animation-playbook.md` step by step. Use `docs/mascot-animation-pipeline.md` as
the reference for tools, MCP setup, keying, rig structure and RML details. The working example to copy is
`app/tool/mascot_rive_jack/` + `design/mascots/jack_rig/`.

## Non-negotiables

1. **Storyboard first.** Agree the beats, poses, expressions, props, length and target UI size with the
   user before generating images.
2. **One master.** Every pose, part and expression is an *edit* of the master (or of the isolated head)
   that says "keep this exact image pixel-identical, only change X", on flat green `#0CF50C`. Never mix
   fresh generations into one rig.
3. **Look at every image** you generate and every render you build (`view` the PNG). Re-prompt in the same
   chat with the specific defect instead of rerolling. Record every prompt in the rig README.
4. **Spend credits carefully.** Use vector shapes for small props, and reuse the matte trick (pose + "now
   keep only the arms"). When Gemini runs out, switch accounts or use ChatGPT.
5. **Seamless loops.** Every track ends where it starts (`keyed()` asserts this), continuous motion uses
   `flow`, and pose swaps hide inside a squash.
6. **Verify with the real runtime**: `verify_<rig>.py` (rive verify, seam check, `review.png`,
   `chat_size.png`, `preview.webp`) plus the live browser preview (`app/tool/preview_mascot_<rig>.ps1`).
7. **Keep secrets out of git.** The Playwright extension token, generated `send.js`/`fetch.js` and prompt
   dumps are never committed.

## Gemini loop (Playwright MCP, `app/tool/gemini_web/`)

1. Write the prompt to `app\tool\gemini_web\p.txt`, then run `python app\tool\gemini_web\gen.py app\tool\gemini_web\p.txt [images...]`.
   With images it opens a new chat; with none it sends a follow-up.
2. `browser_run_code_unsafe` with filename `app\tool\gemini_web\send.js`.
3. `browser_run_code_unsafe` with filename `app\tool\gemini_web\fetch.js`. Repeat while it returns `{ok:false}`.
4. `browser_evaluate` with `() => window.__out` and filename `app\tool\gemini_web\dump.txt`.
5. `python app\tool\gemini_web\grab.py app\tool\gemini_web\dump.txt design\mascots\<rig>\raw\<part>_vN.png`, then view it.

If nothing sends, the Chrome window is hidden. Ask the user to keep it visible.

## Done means

- `rive --verify` reports 0 errors and 0 warnings, the loop seam diff is ≤ 3, and the `.riv` is under 4 MB.
- The review sheet, chat-size strip and live preview look clean, cute and on brand (cherry `#E83D55`, cream
  `#FFF9F3`, pink `#FFF0F2`, deep cherry `#A71938`, charcoal `#29252A`, leaf `#73984A`).
- The rig README lists the look, prompts, parts, pivots and artboards.
- Everything is committed with the Copilot co-author trailer and pushed. Unrelated dirty files are left
  alone unless the user says otherwise.
