"""Build send.js/fetch.js that paste images + a prompt into a web chat UI through Playwright MCP.

usage:
  python gen.py --provider gemini prompt.txt [img1.png ...]
  python gen.py --provider chatgpt prompt.txt photo.png
  python gen.py --url https://example.com/chat --selector 'div[contenteditable="true"]' prompt.txt

With images it opens the provider's new-chat URL and pastes them; without images it posts a
follow-up in the current chat. --no-send leaves the draft in the composer for a dry run.
"""
import argparse, base64, json, pathlib

PROVIDERS = {
    "gemini": {
        "url": "https://gemini.google.com/app",
        "input": "rich-textarea .ql-editor",
    },
    "chatgpt": {
        "url": "https://chatgpt.com/",
        "input": "#prompt-textarea, div.ProseMirror[contenteditable='true']",
    },
    "grok": {
        "url": "https://grok.com/",
        "input": "div.ProseMirror[contenteditable='true']",
    },
    "copilot": {
        "url": "https://copilot.cloud.microsoft/chat",
        "input": "[contenteditable='true'][aria-label*='Copilot'], textarea",
    },
    "claude": {
        "url": "https://claude.ai/new",
        "input": "div.ProseMirror[contenteditable='true']",
    },
    "deepseek": {
        "url": "https://chat.deepseek.com/",
        "input": "textarea",
    },
}

SEND = r"""
async (page) => {
  try { await page.bringToFront(); } catch (e) {}
  const IMGS = __IMGS__;
  const PROMPT = __PROMPT__;
  const URL = __URL__;
  const INPUT = __INPUT__;
  const DO_SEND = __SEND__;

  if (IMGS.length && URL) await page.goto(URL, { waitUntil: 'domcontentloaded' });
  const ed = page.locator(INPUT).first();
  await ed.waitFor({ state: 'visible', timeout: 30000 });
  await ed.click({ force: true });
  await page.waitForTimeout(500);

  if (IMGS.length) {
    await page.evaluate(async ({ IMGS, INPUT }) => {
      const el = document.querySelector(INPUT);
      el.focus();
      for (const im of IMGS) {
        const bin = atob(im.b64);
        const arr = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
        const file = new File([arr], im.name, { type: im.mime });
        const dt = new DataTransfer();
        dt.items.add(file);
        el.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
        await new Promise(r => setTimeout(r, 1400));
      }
    }, { IMGS, INPUT });
    await page.waitForTimeout(2500);
  }

  await ed.click({ force: true });
  await page.waitForTimeout(200);
  await page.keyboard.insertText(PROMPT);
  let typed = 0;
  for (let i = 0; i < 20; i++) {
    typed = await page.evaluate((INPUT) => {
      const el = document.querySelector(INPUT);
      return ((el && (el.innerText || el.value)) || '').trim().length;
    }, INPUT);
    if (typed) break;
    await page.waitForTimeout(250);
  }
  if (!typed) {
    await page.evaluate(({ INPUT, PROMPT }) => {
      const el = document.querySelector(INPUT);
      el.focus();
      document.execCommand('insertText', false, PROMPT);
    }, { INPUT, PROMPT });
  }

  if (!DO_SEND) return { sent: false, typed, draft: true, url: page.url() };

  await ed.click({ force: true });
  await page.waitForTimeout(200);
  await page.keyboard.press('Control+End');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1800);
  await page.evaluate(() => {
    const root = document.querySelector('main') || document.body;
    window.__before = [...root.querySelectorAll('img')].map(i => i.src);
    window.__out = null;
  });
  return { sent: true, typed, url: page.url() };
}
"""

FETCH = r"""
async (page) => {
  try { await page.bringToFront(); } catch (e) {}
  const before = await page.evaluate(() => window.__before || []);
  let src = null;
  const t0 = Date.now();
  while (Date.now() - t0 < 45000) {
    await page.waitForTimeout(2500);
    src = await page.evaluate((before) => {
      const root = document.querySelector('main') || document.body;
      const ims = [...root.querySelectorAll('img')].filter(i => i.complete && i.naturalWidth >= 400 && !before.includes(i.src));
      return ims.length ? ims[ims.length - 1].src : null;
    }, before);
    if (src) break;
  }
  if (!src) {
    const txt = await page.evaluate(() => {
      const r = [...document.querySelectorAll('[data-message-author-role="assistant"], model-response')].pop() || document.querySelector('main') || document.body;
      return (r.innerText || '').slice(-600);
    });
    return { ok: false, txt };
  }
  await page.waitForTimeout(1500);
  let dataUrl = null, how = '';
  if (src.startsWith('blob:') || src.startsWith('data:')) {
    dataUrl = await page.evaluate((src) => {
      const im = [...document.querySelectorAll('img')].filter(i => i.src === src).pop();
      const c = document.createElement('canvas'); c.width = im.naturalWidth; c.height = im.naturalHeight;
      c.getContext('2d').drawImage(im, 0, 0); return c.toDataURL('image/png');
    }, src);
    how = 'canvas';
  } else {
    const p2 = await page.context().newPage();
    try {
      await p2.goto(src);
      await p2.waitForTimeout(1200);
      dataUrl = await p2.evaluate(() => {
        const im = document.images[0];
        const c = document.createElement('canvas'); c.width = im.naturalWidth; c.height = im.naturalHeight;
        c.getContext('2d').drawImage(im, 0, 0); return c.toDataURL('image/png');
      });
      how = 'tab';
    } catch (e) { how = 'tab-fail ' + e.message; }
    await p2.close();
  }
  if (!dataUrl) return { ok: false, how, src: src.slice(0, 80) };
  await page.evaluate((d) => { window.__out = d; }, dataUrl);
  return { ok: true, how, len: dataUrl.length, url: page.url() };
}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("prompt")
    ap.add_argument("images", nargs="*")
    ap.add_argument("--provider", default="gemini", choices=sorted(PROVIDERS))
    ap.add_argument("--url", help="override the provider's new-chat URL")
    ap.add_argument("--selector", help="override the provider's composer CSS selector")
    ap.add_argument("--no-send", action="store_true", help="type/paste but leave the draft unsent")
    a = ap.parse_args()

    preset = PROVIDERS[a.provider]
    url = a.url if a.url else preset["url"]
    selector = a.selector if a.selector else preset["input"]

    prompt = pathlib.Path(a.prompt).read_text(encoding="utf-8-sig").strip()
    imgs = []
    for p in a.images:
        b = pathlib.Path(p).read_bytes()
        mime = "image/png" if p.lower().endswith(".png") else "image/jpeg"
        imgs.append({"name": pathlib.Path(p).name, "mime": mime, "b64": base64.b64encode(b).decode()})

    here = pathlib.Path(__file__).parent
    js = (SEND.strip()
          .replace("__IMGS__", json.dumps(imgs))
          .replace("__PROMPT__", json.dumps(prompt))
          .replace("__URL__", json.dumps(url))
          .replace("__INPUT__", json.dumps(selector))
          .replace("__SEND__", "false" if a.no_send else "true"))
    (here / "send.js").write_text(js, encoding="utf-8")
    (here / "fetch.js").write_text(FETCH.strip(), encoding="utf-8")
    print(f"{a.provider}: wrote send.js ({len(js)} B) and fetch.js; {len(imgs)} image(s)")


if __name__ == "__main__":
    main()
