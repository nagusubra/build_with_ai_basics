"""Write .playwright-mcp/send.js: new Gemini chat, attach images, send prompt, wait, stash result in window.__out.

usage: python gen.py prompt.txt img1.png [img2.png ...]
"""
import base64, json, sys, pathlib

prompt = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8-sig").strip()
imgs = []
for p in sys.argv[2:]:
    b = pathlib.Path(p).read_bytes()
    mime = "image/png" if p.lower().endswith(".png") else "image/jpeg"
    imgs.append({"name": pathlib.Path(p).name, "mime": mime, "b64": base64.b64encode(b).decode()})

js = r"""
async (page) => {
  try { await page.bringToFront(); } catch (e) {}
  const IMGS = __IMGS__;
  const PROMPT = __PROMPT__;
  if (IMGS.length) { await page.goto('https://gemini.google.com/app'); }
  await page.waitForSelector('rich-textarea .ql-editor', { timeout: 30000 });
  await page.waitForTimeout(1500);
  const before = await page.evaluate(() => document.querySelectorAll('model-response img').length);
  await page.evaluate(async ({ IMGS }) => {
    const ed = document.querySelector('rich-textarea .ql-editor');
    ed.focus();
    for (const im of IMGS) {
      const bin = atob(im.b64); const arr = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
      const file = new File([arr], im.name, { type: im.mime });
      const dt = new DataTransfer(); dt.items.add(file);
      ed.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
      await new Promise(r => setTimeout(r, 1200));
    }
  }, { IMGS });
  // wait for uploads to finish
  for (let i = 0; i < 40; i++) {
    const n = await page.evaluate(() => document.querySelectorAll('uploader-file-preview, .file-preview-container img, [data-test-id="image-preview"]').length);
    const busy = await page.evaluate(() => !!document.querySelector('.loading-indicator, mat-progress-spinner, [role="progressbar"]'));
    if (n >= IMGS.length && !busy) break;
    await page.waitForTimeout(500);
  }
  await page.waitForTimeout(1500);
  await page.evaluate((PROMPT) => {
    const ed = document.querySelector('rich-textarea .ql-editor');
    ed.focus();
    document.execCommand('insertText', false, PROMPT);
  }, PROMPT);
  await page.waitForTimeout(800);
  await page.waitForTimeout(2500);
  { const ed = page.locator('rich-textarea .ql-editor'); await ed.click({ force: true }); await page.keyboard.press('Control+End'); await ed.press('Enter'); }
  await page.waitForTimeout(2000);
  await page.evaluate((b) => { window.__before = b; window.__out = null; }, before);
  return { sent: true };
}

"""
js = js.replace("__IMGS__", json.dumps(imgs)).replace("__PROMPT__", json.dumps(prompt))
FETCH = r"""
async (page) => {
  try { await page.bringToFront(); } catch (e) {}
  const before = await page.evaluate(() => window.__before || 0);
  const q = await page.evaluate(() => document.querySelectorAll('user-query').length);
  if (!q) { const ed = page.locator('rich-textarea .ql-editor'); await ed.click({ force: true }); await page.keyboard.press('Control+End'); await ed.press('Enter'); }
  let src = null;
  const t0 = Date.now();
  while (Date.now() - t0 < 45000) {
    await page.waitForTimeout(2500);
    src = await page.evaluate((before) => {
      const ims = [...document.querySelectorAll('model-response img')].filter(i => i.complete && i.naturalWidth >= 400);
      if (ims.length <= 0) return null;
      const all = document.querySelectorAll('model-response img').length;
      if (all <= before) return null;
      return ims[ims.length - 1].src;
    }, before);
    if (src) break;
  }
  if (!src) {
    const txt = await page.evaluate(() => { const r = [...document.querySelectorAll('model-response')].pop(); return r ? r.innerText.slice(0, 600) : 'no response'; });
    return { ok: false, txt };
  }
  await page.waitForTimeout(1500);
  let dataUrl = null, how = '';
  if (src.startsWith('blob:') || src.startsWith('data:')) {
    dataUrl = await page.evaluate((src) => {
      const im = [...document.querySelectorAll('model-response img')].filter(i => i.src === src).pop();
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
pathlib.Path(__file__).with_name("fetch.js").write_text(FETCH.strip(), encoding="utf-8")
out = pathlib.Path(__file__).with_name("send.js")
out.write_text(js.strip(), encoding="utf-8")
print("wrote", out, len(js))
