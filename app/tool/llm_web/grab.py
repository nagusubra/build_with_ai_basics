"""Decode the data URL dumped by browser_evaluate(filename=dump.txt) into a PNG.

usage: python grab.py dump.txt out.png
"""
import base64, re, sys, pathlib

txt = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
m = re.search(r"data:image/(?:png|jpeg|webp);base64,([A-Za-z0-9+/=\\n]+)", txt)
if not m:
    sys.exit("no data url in " + sys.argv[1])
b64 = m.group(1).replace("\\n", "")
out = pathlib.Path(sys.argv[2])
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(base64.b64decode(b64))
from PIL import Image
im = Image.open(out)
print(out, im.size, im.mode)
pathlib.Path(sys.argv[1]).unlink()
