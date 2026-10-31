#!/usr/bin/env python3
"""Assemble les vignettes de `-- --capture-service DOSSIER [--video]` :
- planches de 12 images par service (4 × 3), en vue normale et en vue squelette + pivots ;
- planche comparative des trois services (mêmes phases côte à côte) ;
- démonstration des transitions du smash ;
- avec les images `video_*` : démonstration animée MP4 (vitesse normale puis ralenti ×0,25, vue normale à gauche,
  squelette + pivots à droite).
Usage : python3 tools/service_sheets.py DOSSIER"""
import glob, os, shutil, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def label_of(path):
    return os.path.basename(path).split("_", 2)[2].rsplit(".", 1)[0].replace("_", " ")


def sheet(files, cols, out, title):
    if not files:
        return
    tiles = [Image.open(f).convert("RGB") for f in files]
    w, h = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    img = Image.new("RGB", (cols * w, rows * (h + 22) + 28), (13, 23, 38))
    d = ImageDraw.Draw(img)
    d.text((8, 6), title, fill=(255, 255, 255), font=font(15))
    for i, (f, t) in enumerate(zip(files, tiles)):
        x, y = (i % cols) * w, 28 + (i // cols) * (h + 22)
        img.paste(t, (x, y + 22))
        d.text((x + 6, y + 4), label_of(f), fill=(200, 255, 220), font=font(13))
    img.save(out)


# Planche comparative : même phase du geste, trois services en lignes.
PHASES = [("lancer", {"*": "03"}), ("élan / transfert", {"*": "05"}), ("impulsion / armement", {"sol": "06", "*": "06"}),
          ("armement", {"sol": "07", "*": "08"}), ("impact", {"*": "09"}), ("suivi", {"*": "10"}),
          ("fin du suivi", {"*": "11"}), ("atterrissage / retour", {"*": "12"})]


def comparison(folder, view):
    rows = []
    for kind in ("sol", "flottant", "smash"):
        row = []
        for _, pick in PHASES:
            num = pick.get(kind, pick["*"])
            found = sorted(glob.glob(os.path.join(folder, f"{kind}_{view}_{num}_*.png")))
            row.append(found[0] if found else None)
        rows.append((kind, row))
    sample = next(f for _, r in rows for f in r if f)
    w, h = Image.open(sample).size
    left = 90
    img = Image.new("RGB", (left + len(PHASES) * w, 34 + 3 * (h + 22)), (13, 23, 38))
    d = ImageDraw.Draw(img)
    d.text((8, 8), f"Comparaison des trois services - vue {view}", fill=(255, 255, 255), font=font(16))
    for r, (kind, files) in enumerate(rows):
        y = 34 + r * (h + 22)
        d.text((8, y + 22 + h // 2 - 10), kind, fill=(255, 210, 120), font=font(18))
        for c, f in enumerate(files):
            x = left + c * w
            if f:
                img.paste(Image.open(f).convert("RGB"), (x, y + 22))
                d.text((x + 6, y + 4), label_of(f), fill=(200, 255, 220), font=font(13))
    img.save(os.path.join(folder, f"planche_comparative_{view}.png"))


def video(folder):
    kinds = [k for k in ("sol", "flottant", "smash") if glob.glob(os.path.join(folder, f"video_{k}_normal_*.png"))]
    if not kinds or not shutil.which("ffmpeg"):
        return
    tmp = tempfile.mkdtemp()
    n = 0

    def put(img):
        nonlocal n
        img.save(os.path.join(tmp, f"f{n:05d}.png"))
        n += 1

    for kind in kinds:
        normal = sorted(glob.glob(os.path.join(folder, f"video_{kind}_normal_*.png")))
        debug = sorted(glob.glob(os.path.join(folder, f"video_{kind}_debug_*.png")))
        pairs = list(zip(normal, debug))
        w, h = Image.open(normal[0]).size
        s = 2

        def frame(a, b, caption):
            img = Image.new("RGB", (2 * w * s, h * s + 40), (13, 23, 38))
            img.paste(Image.open(a).convert("RGB").resize((w * s, h * s)), (0, 40))
            img.paste(Image.open(b).convert("RGB").resize((w * s, h * s)), (w * s, 40))
            ImageDraw.Draw(img).text((12, 8), caption, fill=(255, 255, 255), font=font(20))
            return img

        # Sortie à 30 i/s ; la simulation tourne à 120 ticks/s : vitesse normale = 1 tick sur 4, ralenti ×0,25 = chaque tick.
        for a, b in pairs[::4]:
            put(frame(a, b, f"Service {kind} - vitesse normale"))
        for _ in range(8):
            put(frame(*pairs[-1], f"Service {kind} - vitesse normale"))
        for a, b in pairs:
            put(frame(a, b, f"Service {kind} - ralenti x0,25"))
        for _ in range(12):
            put(frame(*pairs[-1], f"Service {kind} - ralenti x0,25"))
    out = os.path.join(folder, "demo_services.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "30", "-i", os.path.join(tmp, "f%05d.png"),
                    "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p",
                    "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", out], check=True)
    shutil.rmtree(tmp)


def main(folder):
    for kind in ("sol", "flottant", "smash"):
        for view in ("normal", "debug"):
            files = sorted(glob.glob(os.path.join(folder, f"{kind}_{view}_*.png")))
            sheet(files, 4, os.path.join(folder, f"planche_{kind}_{view}.png"), f"Service {kind} - vue {view}")
    for view in ("normal", "debug"):
        files = sorted(glob.glob(os.path.join(folder, f"transitions_smash_{view}_*.png")))
        sheet(files, 6, os.path.join(folder, f"planche_transitions_{view}.png"), f"Transitions du smash - vue {view}")
        if glob.glob(os.path.join(folder, f"sol_{view}_*.png")):
            comparison(folder, view)
    video(folder)


if __name__ == "__main__":
    main(sys.argv[1])
