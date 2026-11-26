"""Empaqueta el addon para subirlo a CurseForge: release/WarlockGod-<versión>.zip

Uso: python -I build_zip.py
El zip lleva dentro la carpeta WarlockGod/, que es lo que CurseForge instala en AddOns.
"""
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
addon = root / "WarlockGod"
toc = (addon / "WarlockGod.toc").read_text(encoding="utf-8")
version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)

out = root / "release" / f"WarlockGod-{version}.zip"
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(addon.rglob("*")):
        if f.is_file() and f.name != "desktop.ini":
            z.write(f, f.relative_to(root).as_posix())
print(out)
for info in zipfile.ZipFile(out).infolist():
    print(f"  {info.file_size:>8}  {info.filename}")
