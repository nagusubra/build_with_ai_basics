# Gemini web automation

Small helpers that let an agent (or you) drive **gemini.google.com** in your own logged-in Chrome through
the **Playwright MCP** server (`--extension` mode, Playwright MCP Bridge extension). No API key is needed;
generations use your Gemini account's normal image credits.

Setup and the full workflow are in
[`docs/mascot-animation-pipeline.md`](../../../docs/mascot-animation-pipeline.md#4-generating-assets-with-gemini).

For another provider (ChatGPT, Grok, Copilot, Claude, DeepSeek) use
[`../llm_web/`](../llm_web/README.md) instead: same send/fetch/grab loop, provider chosen with
`--provider` or `--url` + `--selector`. This directory stays Gemini-only.

For editor portability, secret handling and animation-only boundaries, start with
the [workshop README](../README.md#6-editor-portability-and-mcp). These helpers are
optional; manual authorized upload/download works too. Their scratch filenames are
shared: do not run concurrent generations from this directory.

## One image, end to end

```powershell
Set-Content -Encoding utf8 app\tool\gemini_web\p.txt "Keep this exact image pixel-identical ... on a flat pure green background (#0CF50C), 1:1 square, no shadow."
python app\tool\gemini_web\gen.py app\tool\gemini_web\p.txt design\mascots\jack_rig\master.png   # new chat + attachment
# (no image arguments = follow-up message in the current chat)
```

Then, through the MCP tools:

These are the original bridge's tool names and file-output arguments. Discover
the actual tool schemas in your client; do not assume `filename` or
`browser_run_code_unsafe` exists in another Playwright MCP implementation.

1. `browser_run_code_unsafe` with `filename: app\tool\gemini_web\send.js`, which pastes the images, types the prompt and sends.
2. `browser_run_code_unsafe` with `filename: app\tool\gemini_web\fetch.js`, which waits up to 45 s and stores the newest image in
   `window.__out`. If `{ok:false}`, inspect the page/response before retrying;
   it may re-press Send, so avoid duplicate paid generations.
3. `browser_evaluate` with `function: () => window.__out` and `filename: app\tool\gemini_web\dump.txt`.

Finally:

```powershell
python app\tool\gemini_web\grab.py app\tool\gemini_web\dump.txt design\mascots\<rig>\raw\<part>_v1.png
```

**Look at the PNG before using it.**

## Notes

- Keep the Chrome window **visible**: Gemini doesn't send from a hidden window. Both scripts call
  `page.bringToFront()`.
- `send.js`, `fetch.js`, prompt `.txt` files and dumps are generated and git-ignored.
- These scripts target Gemini's DOM (`rich-textarea .ql-editor`, `model-response img`). If Google changes the
  UI, update the selectors in `gen.py`.
- When credits run out, pause or ask for an approved alternative provider. Respect
  quotas; do not cycle accounts to evade limits. For ChatGPT or another model, use
  [`../llm_web/`](../llm_web/README.md); these scripts only target Gemini.
- Never commit the Playwright extension token.
