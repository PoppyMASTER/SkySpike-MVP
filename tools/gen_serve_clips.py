#!/usr/bin/env python3
"""Génère les clips JSON des services (J4.1 SJ1) et, en option, un aperçu cinématique.

Usage (depuis la racine du projet) :
  python3 tools/gen_serve_clips.py                 # réécrit data/animations/clips/serve_*.json, land_*.json
  python3 tools/gen_serve_clips.py --preview DIR   # + planches PNG des poses-clés (FK identique au rig)

Les poses sont écrites en angles ABSOLUS (repère du monde, pratique pour penser le geste) puis converties en
angles relatifs au parent, comme les attend le rig commun de 17 os (scripts/animation/rig_def.gd) :
  0 = os qui pend vers le bas, négatif = vers l'AVANT, positif = vers l'ARRIÈRE, ±π = vers le haut.
  Torse / cou / tête : 0 = droit, positif = penché vers l'avant.
Jambes au sol : IK à deux os, pieds plantés (le point d'appui au sol ne bouge jamais d'une pose à l'autre).
Valeurs purement VISUELLES : aucune n'est lue par la simulation.
"""
import json, math, os, sys

# --- gabarit standard (rig_def.gd)
T, S, ANK = 0.45, 0.44, 0.07
TORSO, NECK, HEAD = 0.52, 0.08, 0.24
UA, FA, HAND = 0.30, 0.26, 0.09
FF, FB = 0.20, 0.07
DROP, DX = 0.05, 0.02
FL, FR = 0.16, -0.14      # appuis au sol (x de la cheville pied à plat) : gauche devant, droite derrière


def wrap(a):
    return math.atan2(math.sin(a), math.cos(a))


def rot(a, v):
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


# ------------------------------------------------------------------ jambes
def _ik(side, ax, ay, foot_abs):
    """Cheville en (ax, ay) dans le repère du bassin (y vers le bas) ; genou vers l'avant."""
    hip = -DX if side == "l" else DX
    ax -= hip
    D = min(math.hypot(ax, ay), T + S - 1e-4)
    psi = math.atan2(-ax, ay)
    alpha = math.acos(max(-1.0, min(1.0, (T * T + D * D - S * S) / (2 * T * D))))
    t1 = psi - alpha
    kx, ky = -T * math.sin(t1), T * math.cos(t1)
    ts = math.atan2(-(ax - kx), ay - ky)
    return {f"thigh_{side}": t1, f"shin_{side}": ts - t1, f"foot_{side}": foot_abs - ts}


def _ankle(H, f, phi):
    """Position de la cheville pour un pied dont l'appui au sol est fixe.
    phi > 0 : talon levé (pivot sur la pointe) ; phi < 0 : pointe levée (pivot sur le talon)."""
    if phi > 0:
        toe = (f + FF, H)
        o = rot(phi, (FF, ANK))
        return toe[0] - o[0], toe[1] - o[1]
    if phi < 0:
        heel = (f - FB, H)
        o = rot(phi, (-FB, ANK))
        return heel[0] - o[0], heel[1] - o[1]
    return f, H - ANK


def stance(H, phl=0.0, phr=0.0, fl=FL, fr=FR):
    """Deux pieds au sol. H = hauteur des hanches (m). Le pied gauche est devant, le droit derrière."""
    p = {}
    p.update(_ik("l", *_ankle(H, fl, phl), phl))
    p.update(_ik("r", *_ankle(H, fr, phr), phr))
    return p


def air(tl, kl, fl_, tr, kr, fr_):
    """Jambes en l'air : cuisse (absolu), genou (relatif, + = jambe repliée vers l'arrière), pied (relatif)."""
    return {"thigh_l": tl, "shin_l": kl, "foot_l": fl_, "thigh_r": tr, "shin_r": kr, "foot_r": fr_}


# ------------------------------------------------------------------ haut du corps
def upper(torso, head, ual, fal, uar, far):
    """Angles ABSOLUS : torse, tête, bras gauche (haut, avant-bras), bras droit = bras frappeur."""
    neck = head * 0.4 - torso * 0.4
    return {
        "torso": torso, "neck": neck - 0.0, "head": head - torso - neck,
        "upper_arm_l": ual - torso, "forearm_l": fal - ual, "hand_l": 0.0,
        "upper_arm_r": uar - torso, "forearm_r": far - uar, "hand_r": 0.0,
    }


def pose(up, legs):
    p = dict(up)
    p.update(legs)
    return {k: round(wrap(v), 4) for k, v in p.items()}


# ------------------------------------------------------------------ clips
CLIPS = {}


def clip(cid, action, dur, domain, keys, events, **kw):
    c = {"schema_version": 1, "id": cid, "action": action, "duration_s": dur, "loop": False, "time_domain": domain,
         "pose_mode": "absolute", "default_interpolation": "spline"}
    c.update(kw)
    c["events"] = [{"t": t, "type": "contact_marker" if n == "impact" else "visual_marker", "name": n} for t, n in events]
    c["keyframes"] = [{"t": t, "pose": p} for t, p in keys]
    CLIPS[cid] = c
    return c


# Attente : debout, genoux souples, ballon tenu devant à deux mains.
HOLD = pose(upper(0.08, 0.0, -0.55, -1.55, -0.35, -1.45), stance(0.91))
# Préparation (charge) : posture fléchie modérée, buste penché, ballon ramené vers la hanche.
PREP = pose(upper(0.30, 0.10, -0.35, -1.25, -0.15, -1.15), stance(0.80))
clip("serve_prep_v1", "serve_prep", 1.0, "charge", [(0.0, HOLD), (1.0, PREP)], [], move_legs="run", blend_in_s=0.08)

# Lancer : bref appui (marqueur squash pour le saut), bras gauche qui lance, bras droit qui s'arme
# (« arc tendu » : coude en arrière au-dessus de l'épaule, main en arrière, bien visible hors de la silhouette ;
# bras guide orienté vers le ballon ; le coude reste fléchi, jamais en hyper-extension : limites du rig commun).
TOSS_SQ = pose(upper(0.22, 0.05, -0.9, -1.6, 0.3, -0.6), stance(0.84))
TOSS_REL = pose(upper(-0.02, -0.25, -2.75, -2.85, 1.45, 0.45), stance(0.90))
COCK = pose(upper(-0.18, -0.40, -2.5, -2.65, 2.2, 0.7), stance(0.89))
clip("serve_toss_v1", "serve_toss", 0.5, "seconds", [(0.0, TOSS_SQ), (0.18, TOSS_REL), (0.5, COCK)],
     [(0.0, "squash"), (0.08, "squash_end"), (0.18, "release"), (0.5, "cock")],
     move_legs="run", air_legs="jump", blend_in_s=0.05)

# Saut (état SERVE_JUMP, temps depuis l'impulsion) : compression très brève puis extension immédiate,
# buste qui s'ouvre, coude frappeur qui recule et se replie (main derrière la nuque), jambes qui se replient.
J_SQ = pose(upper(0.25, -0.20, -2.45, -2.6, 1.9, 0.6), stance(0.74))
J_EXT = pose(upper(-0.12, -0.38, -2.55, -2.7, 2.05, 0.65), air(-0.08, 0.05, 0.75, 0.06, 0.08, 0.8))
J_OPEN = pose(upper(-0.32, -0.42, -2.5, -2.65, 2.35, 0.7), air(-0.40, 0.80, 0.45, 0.15, 1.0, 0.55))
clip("serve_jump_v1", "serve_jump", 0.24, "seconds", [(0.0, J_SQ), (0.06, J_EXT), (0.24, J_OPEN)],
     [(0.0, "squash"), (0.06, "extension"), (0.24, "cock")], blend_in_s=0.03)

# --- service au sol (sobre) : poids sur la jambe arrière (pointe avant levée) -> jambe avant (talon arrière levé) ;
# coude armé derrière l'épaule puis bras qui se tend vers le haut et l'avant, geste mesuré.
G_COCK = pose(upper(-0.20, -0.38, -2.45, -2.6, 2.05, 0.55), stance(0.88, phl=-0.22))
G_LOAD = pose(upper(-0.14, -0.32, -2.1, -2.45, 2.3, 0.7), stance(0.88, phl=-0.10))
G_ACC = pose(upper(0.08, -0.22, -1.2, -1.9, 3.05, 1.55), stance(0.88, phr=0.15))
G_IMP = pose(upper(0.24, -0.12, -0.55, -1.55, -2.80, -2.95), stance(0.89, phr=0.35))
G_FOL = pose(upper(0.38, 0.05, 0.25, -0.7, -0.85, -1.25), stance(0.87, phr=0.55))
G_END = pose(upper(0.18, 0.0, 0.1, -0.35, -0.35, -0.75), stance(0.89, phr=0.30))
clip("serve_ground_v1", "serve_ground", 0.75, "window",
     [(0.0, COCK), (0.06, G_COCK), (0.13, G_LOAD), (0.19, G_ACC), (0.24, G_IMP), (0.35, G_FOL), (0.75, G_END)],
     [(0.0, "cock"), (0.24, "impact"), (0.35, "follow")], window_start="cock", blend_in_s=0.06)

# --- flottant : saut compact (jambes groupées), coude armé derrière l'épaule, frappe courte et sèche :
# le coude monte et le bras se tend d'un coup ; le bras s'ARRÊTE devant (suivi limité,
# différence nette avec le smash qui fouette et traverse jusqu'à la hanche).
F_LEGS_A = air(-0.30, 0.55, 0.45, 0.10, 0.75, 0.5)
F_LEGS_B = air(-0.20, 0.35, 0.40, 0.0, 0.45, 0.45)
F_COCK = pose(upper(-0.18, -0.40, -2.5, -2.65, 2.05, 0.55), F_LEGS_A)
F_LOAD = pose(upper(-0.16, -0.36, -2.25, -2.55, 2.3, 0.7), F_LEGS_A)
F_ACC = pose(upper(0.0, -0.22, -1.3, -2.0, 3.0, 2.05), F_LEGS_B)
F_IMP = pose(upper(0.12, -0.12, -0.6, -1.6, -2.75, -2.82), F_LEGS_B)
F_STOP = pose(upper(0.16, -0.08, -0.4, -1.4, -2.05, -2.15), F_LEGS_B)
F_END = pose(upper(0.10, -0.05, -0.3, -1.1, -1.7, -1.95), air(-0.25, 0.30, 0.35, 0.05, 0.35, 0.4))
clip("serve_float_v1", "serve_float", 0.55, "window",
     [(0.0, J_OPEN), (0.05, F_COCK), (0.09, F_LOAD), (0.15, F_ACC), (0.20, F_IMP), (0.27, F_STOP), (0.55, F_END)],
     [(0.0, "cock"), (0.20, "impact"), (0.27, "follow")], window_start="cock", blend_in_s=0.04)

# --- smash : buste grand ouvert, coude très haut derrière (repris du saut, sans retour en arrière), accélération en
# fouetté (la main traîne derrière le coude),
# frappe haute, buste qui se referme fort, jambes qui passent devant, bras qui traverse jusqu'à la hanche.
S_COCK = pose(upper(-0.50, -0.45, -2.45, -2.6, 2.35, 0.65), air(-0.45, 0.95, 0.45, 0.18, 1.15, 0.55))
S_LOAD = pose(upper(-0.52, -0.45, -2.2, -2.5, 2.45, 0.7), air(-0.45, 1.0, 0.45, 0.25, 1.25, 0.55))
S_ACC = pose(upper(-0.05, -0.25, -1.0, -1.8, -2.90, 1.78), air(-0.45, 0.80, 0.4, 0.15, 1.0, 0.5))
S_IMP = pose(upper(0.38, -0.08, -0.25, -1.35, -2.82, -2.92), air(-0.55, 0.55, 0.35, -0.25, 0.65, 0.45))
S_THRU = pose(upper(0.72, 0.15, 0.45, -0.4, -1.05, -1.55), air(-0.70, 0.75, 0.3, -0.45, 0.80, 0.4))
S_FOL = pose(upper(0.62, 0.12, 0.55, -0.2, -0.25, -0.75), air(-0.55, 0.80, 0.25, -0.30, 0.85, 0.35))
S_END = pose(upper(0.35, 0.05, 0.2, -0.5, -0.15, -0.55), air(-0.40, 0.55, 0.2, -0.20, 0.60, 0.25))
clip("serve_smash_v1", "serve_smash", 0.9, "window",
     [(0.0, J_OPEN), (0.05, S_COCK), (0.10, S_LOAD), (0.175, S_ACC), (0.25, S_IMP), (0.33, S_THRU), (0.52, S_FOL),
      (0.9, S_END)],
     [(0.0, "cock"), (0.25, "impact"), (0.33, "follow")], window_start="cock", blend_in_s=0.04)

# --- atterrissages : amorti (genoux qui cèdent, bras qui stabilisent devant/bas) puis retour à une posture neutre
# debout. Jamais de bras rejetés en arrière ni de flexion profonde finale (ce serait une nouvelle préparation de saut).
NEUTRAL = pose(upper(0.06, 0.0, -0.15, -0.45, -0.1, -0.4), stance(0.92, fl=0.12, fr=-0.12))
L_F0 = pose(upper(0.20, 0.05, -0.55, -1.2, -1.2, -1.6), stance(0.84, fl=0.12, fr=-0.12))
L_F1 = pose(upper(0.24, 0.05, -0.45, -1.05, -0.7, -1.2), stance(0.80, fl=0.12, fr=-0.12))
L_F2 = pose(upper(0.12, 0.02, -0.25, -0.65, -0.25, -0.65), stance(0.89, fl=0.12, fr=-0.12))
clip("land_float_v1", "land_float", 0.3, "length", [(0.0, L_F0), (0.08, L_F1), (0.2, L_F2), (0.3, NEUTRAL)], [],
     blend_in_s=0.04)
L_S0 = pose(upper(0.40, 0.10, -0.4, -1.1, -0.35, -0.85), stance(0.80, fl=0.12, fr=-0.12))
L_S1 = pose(upper(0.42, 0.10, -0.6, -1.3, -0.5, -1.1), stance(0.72, fl=0.12, fr=-0.12))
L_S2 = pose(upper(0.20, 0.04, -0.3, -0.8, -0.3, -0.75), stance(0.86, fl=0.12, fr=-0.12))
clip("land_smash_v1", "land_smash", 0.3, "length", [(0.0, L_S0), (0.09, L_S1), (0.22, L_S2), (0.3, NEUTRAL)], [],
     blend_in_s=0.04)


# ------------------------------------------------------------------ aperçu (FK identique à RigDef)
PARENTS = {"torso": None, "neck": "torso", "head": "neck", "upper_arm_l": "torso", "forearm_l": "upper_arm_l",
           "hand_l": "forearm_l", "upper_arm_r": "torso", "forearm_r": "upper_arm_r", "hand_r": "forearm_r",
           "thigh_l": None, "shin_l": "thigh_l", "foot_l": "shin_l", "thigh_r": None, "shin_r": "thigh_r",
           "foot_r": "shin_r"}
OFF = {"torso": (0, 0), "neck": (0, -TORSO), "head": (0, -NECK), "upper_arm_l": (-DX, -TORSO + DROP),
       "forearm_l": (0, UA), "hand_l": (0, FA), "upper_arm_r": (DX, -TORSO + DROP), "forearm_r": (0, UA),
       "hand_r": (0, FA), "thigh_l": (-DX, 0), "shin_l": (0, T), "foot_l": (0, S), "thigh_r": (DX, 0),
       "shin_r": (0, T), "foot_r": (0, S)}
TIP = {"torso": (0, -TORSO), "neck": (0, -NECK), "head": (0, -HEAD), "upper_arm_l": (0, UA), "forearm_l": (0, FA),
       "hand_l": (0, HAND), "upper_arm_r": (0, UA), "forearm_r": (0, FA), "hand_r": (0, HAND), "thigh_l": (0, T),
       "shin_l": (0, S), "foot_l": (FF, ANK), "thigh_r": (0, T), "shin_r": (0, S), "foot_r": (FF, ANK)}


def fk(p):
    g = {}
    for b in PARENTS:
        a = p.get(b, 0.0)
        par = PARENTS[b]
        if par is None:
            g[b] = (a, OFF[b])
        else:
            pa, po = g[par]
            o = rot(pa, OFF[b])
            g[b] = (pa + a, (po[0] + o[0], po[1] + o[1]))
    seg = {}
    for b, (a, o) in g.items():
        tip = rot(a, TIP[b])
        seg[b] = (o, (o[0] + tip[0], o[1] + tip[1]))
    a, o = g["foot_l"]
    heel_l = rot(a, (-FB, ANK))
    a2, o2 = g["foot_r"]
    heel_r = rot(a2, (-FB, ANK))
    pts = [seg["foot_l"][1], (o[0] + heel_l[0], o[1] + heel_l[1]), seg["foot_r"][1], (o2[0] + heel_r[0], o2[1] + heel_r[1])]
    sole = max(p_[1] for p_ in pts)
    return seg, sole, pts


def _tangent(l, r, hl, hr):
    if l * r <= 0:
        return 0.0
    return 3 * (hl + hr) / ((2 * hr + hl) / l + (hr + 2 * hl) / r)


def sample(c, t):
    """Même interpolation que AnimationClip (« spline » : Hermite monotone sur angles déroulés)."""
    keys = c["keyframes"]
    T_ = [k["t"] for k in keys]
    P = [k["pose"] for k in keys]
    if t <= T_[0]:
        return P[0]
    if t >= T_[-1]:
        return P[-1]
    i = max(j for j in range(len(T_) - 1) if T_[j] <= t)
    h = T_[i + 1] - T_[i]
    u = (t - T_[i]) / h
    out = {}
    for b in set().union(*P[max(i - 1, 0):i + 3]):
        p0 = P[i].get(b, 0.0)
        p1 = p0 + wrap(P[i + 1].get(b, 0.0) - p0)
        m0 = m1 = 0.0
        if i > 0:
            pm = p0 - wrap(p0 - P[i - 1].get(b, 0.0))
            m0 = _tangent((p0 - pm) / (T_[i] - T_[i - 1]), (p1 - p0) / h, T_[i] - T_[i - 1], h)
        if i + 2 < len(P):
            p2 = p1 + wrap(P[i + 2].get(b, 0.0) - P[i + 1].get(b, 0.0))
            m1 = _tangent((p1 - p0) / h, (p2 - p1) / (T_[i + 2] - T_[i + 1]), h, T_[i + 2] - T_[i + 1])
        u2, u3 = u * u, u * u * u
        out[b] = (2 * u3 - 3 * u2 + 1) * p0 + (u3 - 2 * u2 + u) * h * m0 + (-2 * u3 + 3 * u2) * p1 + (u3 - u2) * h * m1
    return out


def draw(img, p, cx, base, k, air_h=0.0, label=""):
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    seg, sole, pts = fk(p)
    dy = -sole - air_h
    P = lambda v: (cx + v[0] * k, base + (v[1] + dy) * k)
    d.line([(cx - 0.6 * k, base), (cx + 0.6 * k, base)], fill=(90, 110, 140), width=2)
    far = (120, 140, 170)
    near = (230, 235, 245)
    for b in ["thigh_l", "shin_l", "foot_l", "upper_arm_l", "forearm_l", "hand_l"]:
        d.line([P(seg[b][0]), P(seg[b][1])], fill=far, width=5)
    for b in ["torso", "neck", "head", "thigh_r", "shin_r", "foot_r"]:
        d.line([P(seg[b][0]), P(seg[b][1])], fill=near, width=6 if b != "head" else 9)
    for b in ["upper_arm_r", "forearm_r", "hand_r"]:
        d.line([P(seg[b][0]), P(seg[b][1])], fill=(255, 150, 60), width=6)
    for b in seg:
        x, y = P(seg[b][0])
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 80, 110))
    for v in pts:
        x, y = P(v)
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(120, 255, 160))
    d.text((cx - 0.6 * k + 4, 6), label, fill=(220, 230, 255))


def preview(outdir):
    from PIL import Image
    os.makedirs(outdir, exist_ok=True)
    seqs = {
        "sol": [("serve_prep_v1", [0, 0.3]), ("serve_toss_v1", [0, 0.18, 0.5]),
                ("serve_ground_v1", [0.06, 0.13, 0.19, 0.24, 0.32, 0.40, 0.75])],
        "flottant": [("serve_toss_v1", [0.18, 0.5]), ("serve_jump_v1", [0.0, 0.06, 0.12]),
                     ("serve_float_v1", [0.05, 0.11, 0.165, 0.20, 0.30, 0.55]), ("land_float_v1", [0, 0.08, 0.3])],
        "smash": [("serve_prep_v1", [1.0]), ("serve_toss_v1", [0.5]), ("serve_jump_v1", [0.0, 0.06, 0.24]),
                  ("serve_smash_v1", [0.07, 0.14, 0.20, 0.225, 0.25, 0.38, 0.58]), ("land_smash_v1", [0, 0.09, 0.3])],
    }
    k = 150
    for name, seq in seqs.items():
        frames = [(cid, t) for cid, ts in seq for t in ts]
        img = Image.new("RGB", (len(frames) * 190, 400), (16, 22, 36))
        for i, (cid, t) in enumerate(frames):
            c = CLIPS[cid]
            p = sample(c, t)
            airborne = cid.startswith(("serve_jump", "serve_float", "serve_smash")) and t > 0.01
            draw(img, p, 95 + i * 190, 370, k, 0.35 if airborne else 0.0, f"{cid[:-3]} {t:.2f}")
        img.save(os.path.join(outdir, f"apercu_{name}.png"))


def main():
    for cid, c in CLIPS.items():
        with open(f"data/animations/clips/{cid}.json", "w") as f:
            json.dump(c, f, indent=1)
    s = json.load(open("data/animations/sets/standard_v1.json"))
    for a in ["serve_prep", "serve_toss", "serve_jump", "serve_ground", "serve_float", "serve_smash", "land_float",
              "land_smash"]:
        s["actions"][a] = a + "_v1"
    with open("data/animations/sets/standard_v1.json", "w") as f:
        json.dump(s, f, indent=1, ensure_ascii=False)
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
