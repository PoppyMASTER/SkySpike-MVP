#!/usr/bin/env python3
"""Assemble les vignettes de `-- --capture-fx DOSSIER` (J4.1 SJ2) :
- planche_effets_services.png : les quatre frappes (sol, flottant, smash réussi, smash raté), effets activés ;
- planche_effets_on_off.png : chaque frappe avec effets activés puis désactivés.
Usage : python3 tools/fx_sheets.py DOSSIER"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
KINDS = [("sol", "Service au sol"), ("flottant", "Service flottant"), ("smash", "Smash réussi"), ("smash_rate", "Smash raté (q 0,43)")]
OFFSETS = [0, 4, 12, 24]
SCALE = 0.62


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def tile(folder, kind, mode, off):
    path = os.path.join(folder, f"fx_{kind}_{mode}_{off:02d}.png")
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert("RGB")
    return im.resize((int(im.width * SCALE), int(im.height * SCALE)))


def sheet(folder, rows, out, title):
    sample = next(t for r in rows for t in r[1] if t is not None)
    w, h = sample.size
    left = 220
    img = Image.new("RGB", (left + len(OFFSETS) * w, 60 + len(rows) * (h + 8)), (13, 23, 38))
    d = ImageDraw.Draw(img)
    d.text((10, 8), title, fill=(255, 255, 255), font=font(18))
    for c, off in enumerate(OFFSETS):
        d.text((left + c * w + 8, 36), "impact" if off == 0 else f"+{off} ticks ({off / 120:.2f} s)", fill=(200, 255, 220), font=font(14))
    for r, (name, tiles) in enumerate(rows):
        y = 60 + r * (h + 8)
        d.text((10, y + h // 2 - 10), name, fill=(255, 210, 120), font=font(15))
        for c, t in enumerate(tiles):
            if t is not None:
                img.paste(t, (left + c * w, y))
    img.save(out)


def main(folder):
    rows = [(label, [tile(folder, k, "on", o) for o in OFFSETS]) for k, label in KINDS]
    sheet(folder, rows, os.path.join(folder, "planche_effets_services.png"), "Effets de service (activés) : même scénario, quatre frappes réelles")
    rows = []
    for k, label in KINDS:
        rows.append((label + " : ON", [tile(folder, k, "on", o) for o in OFFSETS]))
        rows.append((label + " : OFF", [tile(folder, k, "off", o) for o in OFFSETS]))
    sheet(folder, rows, os.path.join(folder, "planche_effets_on_off.png"), "Effets activés / désactivés")


if __name__ == "__main__":
    main(sys.argv[1])
