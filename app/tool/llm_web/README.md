# Web chat automation (Gemini, ChatGPT, other LLMs)

Pastes a prompt plus reference images into whichever web chat you are signed in to, through the
**Playwright MCP** server (`--extension` mode, Playwright MCP Bridge extension). No API keys, no
uploads: it drives your real Chrome tab.

Use this instead of [`../gemini_web/`](../gemini_web/README.md) when Gemini is out of credits or is
the wrong model. Try providers in this order:

1. **Gemini** – strongest at "edit this exact image, change only X".
2. **ChatGPT** – best all-round fallback.
3. **Grok**, **Copilot**, then **Claude** / **DeepSeek** once signed in.
4. Anything else with `--url` + `--selector`.

## One image, end to end

```powershell
Set-Content -Encoding utf8 app\tool\llm_web\p.txt "Keep this exact image pixel-identical ... on a flat pure green background (#0CF50C), 1:1 square, no shadow."
python app\tool\llm_web\gen.py --provider chatgpt app\tool\llm_web\p.txt design\mascots\jack_rig\master.png
```

Then, through the MCP tools:

1. `browser_run_code_unsafe` with `filename: app\tool\llm_web\send.js` — opens a new chat, pastes the
   images, types the prompt and sends.
2. `browser_run_code_unsafe` with `filename: app\tool\llm_web\fetch.js` — waits up to 45 s for a new
   large image and stores it as a PNG data URL in `window.__out`. Rerun while it returns `{ok:false}`.
3. `browser_evaluate` with `function: () => window.__out` and `filename: app\tool\llm_web\dump.txt`.

```powershell
python app\tool\llm_web\grab.py app\tool\llm_web\dump.txt design\mascots\<rig>\raw\<part>_v1.png
```

**Look at the PNG before using it.**

Dry run (paste + type, do not send):

```powershell
python app\tool\llm_web\gen.py --provider grok --no-send p.txt master.png
```

## Other providers

Providers live in the `PROVIDERS` table at the top of `gen.py`: a new-chat URL and a composer CSS
selector. Verified signed-in and working: Gemini, ChatGPT, Grok, Copilot. Claude and DeepSeek need a
login first. For anything else:

```powershell
python app\tool\llm_web\gen.py --url https://example.com/chat --selector 'div[contenteditable="true"]' p.txt
```

## Notes

- Keep the Chrome window **visible**; the scripts call `page.bringToFront()`.
- `send.js`, `fetch.js`, prompt `.txt` files and dumps are generated and git-ignored.
- Images are attached with a synthetic `paste` carrying a `DataTransfer`; text goes in with
  `keyboard.insertText`, falling back to `execCommand('insertText')`.
- `fetch.js` treats "an `<img>` at least 400 px wide that was not on the page after sending" as the
  answer, so it does not have to know each provider's message markup. If a provider keeps old images
  on screen or lazy-loads thumbnails, regenerate against a fresh chat.
- Never commit the Playwright extension token.
