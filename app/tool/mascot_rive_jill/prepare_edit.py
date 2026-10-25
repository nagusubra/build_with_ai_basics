"""Prepare the existing Gemini helper with finite UI animations settled before send.

Usage: python prepare_edit.py pose_idea master
       python prepare_edit.py arms
       python prepare_edit.py face_smile head
Run .author_send.js through Playwright, then use the existing fetch/grab helpers.
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RAW = REPO / "design" / "mascots" / "jill_rig" / "raw"
HELPERS = HERE.with_name("gemini_web")

if __name__ == "__main__":
    name = sys.argv[1]
    command = [sys.executable, str(HELPERS / "gen.py"), str(RAW / f"{name}_prompt.txt")]
    if len(sys.argv) > 2:
        command.append(str(RAW / f"{sys.argv[2]}_v1.png"))
    subprocess.run(command, check=True)
    script = (HELPERS / "send.js").read_text(encoding="utf-8")
    script = script.replace(
        "  return { sent: true };",
        """  await page.evaluate(() => {
    for (const animation of document.getAnimations()) {
      if (Number.isFinite(animation.effect?.getComputedTiming().endTime)) animation.finish();
    }
  });
  await page.screenshot({animations: 'disabled'});
  const result = await page.evaluate(() => {
    const editor = document.querySelector('rich-textarea .ql-editor');
    if (editor?.innerText.trim()) {
      const button = document.querySelector('button[aria-label="Send message"]');
      if (!button) throw new Error('Prepared image edit has no Send button');
      button.click();
      return 'submitted after settling paused UI animations';
    }
    return 'already submitted';
  });
  await page.screenshot({animations: 'disabled'});
  return { sent: true, result };""")
    (HERE / ".author_send.js").write_text(script, encoding="utf-8")
    fetch = (HELPERS / "fetch.js").read_text(encoding="utf-8").replace(
        "    await page.waitForTimeout(2500);",
        "    await page.screenshot({animations: 'disabled'});\n    await page.waitForTimeout(2500);")
    (HERE / ".author_fetch.js").write_text(fetch, encoding="utf-8")
