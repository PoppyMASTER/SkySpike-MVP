# SkySpike MVP — Dossier de transmission des animations

Ce document décrit l'implémentation **réelle** des animations de SkySpike au moment de l'export, pour qu'un autre
outil (ou une autre personne) puisse corriger les poses, le rythme, l'armement, l'accompagnement et l'atterrissage
**sans toucher à la simulation ni aux contacts**. Tout ce qui n'a pas été vérifié est signalé comme tel (§ 12).

## 1. Version

| Élément | Valeur |
| --- | --- |
| Moteur | **Godot 4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`), rendu **GL Compatibility** |
| Langage | GDScript typé, aucun plugin, aucun autoload, aucun asset binaire (mannequin dessiné par polygones) |
| Projet | `SkySpike MVP` (`project.godot`), dépôt `PoppyMASTER/SkySpike-MVP`, branche `main` |
| Commit exporté | voir `VERSION.txt` à la racine de l'archive (commit exact + date de l'export) |
| État validé | J4.1 SJ1 (animations des services) et SJ2 (effets et son) validés le 31/10 et le 01/11/2026 |

Règles du projet à respecter (extrait de `CLAUDE.md`) : aucune valeur de gameplay en dur ; la simulation
(`scripts/simulation`, `gameplay`, `ai`) n'utilise ni hasard libre, ni `Time`, ni `delta`, ni `_process` ;
l'animation et le rendu **lisent** l'état de la simulation et n'y écrivent jamais ; un marqueur d'animation ne
déclenche jamais de contact. Le test `tests/unit/test_architecture.gd` vérifie les dépendances entre couches.

## 2. Lancer et tester

```bash
# importer (première ouverture ou après ajout de fichiers)
godot --headless --path . --import
# tous les tests (≈ 60 s) — doit afficher « 213 test(s) réussi(s), 0 échec(s) »
godot --headless --path . -s tests/run_tests.gd
# seulement les tests dont le nom de fichier contient un mot (ex. serve_animation, rig_animator, animation_clip)
godot --headless --path . -s tests/run_tests.gd -- serve_animation
# non-régression de la simulation : 12 matchs IA contre IA (référence : 981 contacts, 358 points, 2,74 contacts/point)
godot --headless --path . -- --sim 12
```

**Jouer** : scène principale `res://scenes/main.tscn` (F5 dans l'éditeur, ou `godot --path .`). `main.gd` charge les
données puis instancie `res://scenes/match/match.tscn` (racine `MatchRunner`). Le joueur contrôlé est le slot 0
(attaquant bleu) ; il sert quand son équipe a le service. Touches : ←/→ ou Q/D déplacement, **Espace** saut,
**L** (ou K) passe / service, J réception / contre / feinte ; manette : stick, A, B/Y, X.

| Service | Commandes |
| --- | --- |
| Sol | appui bref sur L (lancer bas), puis **L** pendant que le ballon redescend dans la zone |
| Flottant | L (bref ou court maintien), relâcher, **Espace** (saut), puis **Espace ou L** tôt (pieds encore bas) |
| Smashé | **maintenir L** (lancer haut, barre jaune), relâcher, Espace au bon moment, puis Espace ou L près du sommet du saut |

Le **type** n'est pas choisi par une touche : il dépend de la hauteur des pieds au tick du contact
(`ContactResolver.serve_kind`) : < 5 % de la hauteur de saut = sol ; ≥ `serve_smash_jump_ratio` (0,7) = smash ;
entre les deux = flottant.

**Outils de debug en jeu** : F1 panneau sandbox (réglages `anim_*`, `fx_*`, `audio_*`, choix du joueur contrôlé,
« tester une animation » isolée), F2 zones de contact, F3 squelette, F4 pivots, F5 nom du clip / domaine / temps /
fondu, P pause, N un tick, R relancer.

**Captures automatiques** (simulateur réel, scénarios scriptés déterministes, graine 1) :

```bash
X="xvfb-run -a -s '-screen 0 1600x900x24'"   # sous Linux sans écran ; sinon lancer godot directement
# 12 vignettes par service (vue normale et vue squelette + pivots) + planche comparative + transitions du smash
godot --path . --rendering-driver opengl3 --resolution 1600x900 -- --capture-service DOSSIER [--video]
python3 tools/service_sheets.py DOSSIER          # assemble les planches (et demo_services.mp4 si --video)
# vidéo de référence d'un service : normal puis ralenti ×0,25, arrêt sur le tick du contact (sol|flottant|smash, normal|debug)
godot --path . --rendering-driver opengl3 --resolution 1600x900 --write-movie smash_debug.avi --fixed-fps 60 -- --anim-video smash debug
ffmpeg -i smash_debug.avi -vf "crop=760:520:0:280,scale=1140:780" -c:v libx264 -pix_fmt yuv420p smash_debug.mp4
# planches de poses de tous les clips (5 instants par clip)
godot --path . --rendering-driver opengl3 --resolution 1600x900 -- --anim-sheet DOSSIER
```

Scénarios (`scripts/app/service_capture.gd`, `scripts/app/fx_capture.gd`) : `[ticks de maintien de L, tick du saut
ou −1, tick de la frappe]` après le lancer : sol `[0, -1, 18]`, flottant `[0, 40, 42]`, smash `[150, 12, 30]`.
Contacts obtenus : sol tick 135, flottant tick 154, smash tick 294 (q 0,98 / 0,87 / 0,88).

## 3. Fichiers à modifier

| Animation | État(s) de la simulation | Clip (`data/animations/clips/`) | Domaine de temps | Source |
| --- | --- | --- | --- | --- |
| Attente avec ballon / préparation | `SERVE_HOLD` | `serve_prep_v1.json` | `charge` (0 → 1) | générateur |
| Lancer | `SERVE_TOSS` | `serve_toss_v1.json` | `seconds` | générateur |
| Impulsion et saut du service | `SERVE_JUMP` | `serve_jump_v1.json` | `seconds` | générateur |
| Frappe au sol | `SERVE_HIT` (intention `ground`) | `serve_ground_v1.json` | `window` | générateur |
| Frappe flottante | `SERVE_HIT` (intention `float`) | `serve_float_v1.json` | `window` | générateur |
| Frappe smashée | `SERVE_HIT` (intention `smash`) | `serve_smash_v1.json` | `window` | générateur |
| Suivi du geste (après contact) | `FREE` / `AIR` / `RECOVER` | même clip que la frappe, poursuivi | `window` | générateur |
| Atterrissage après flottant / smash | `RECOVER` | `land_float_v1.json` / `land_smash_v1.json` | `length` | générateur |
| Ancien service unique (repli) | `SERVE_HIT` si `anim_serve_variants` = 0 | `serve_v1.json` | `window` | JSON à la main |
| Attente, course | `FREE` / `LOCKED` | `idle_v1.json`, `run_v1.json` | `loop_time`, `distance` | JSON à la main (J4) |
| Saut, atterrissage générique | `AIR`, `RECOVER` | `jump_v1.json`, `land_v1.json` | `air_velocity`, `length` | JSON à la main (J4) |
| Réception, passe, attaque, feinte | `RECEIVE`, `SET`, `SPIKE`, `FEINT` | `receive_v1`, `set_v1`, `spike_v1`, `feint_v1` | `window` | JSON à la main (J4) |
| Contre | `BLOCK_READY` (maintien `ready`), `BLOCK_AIR` | `block_v1.json` | `seconds` | JSON à la main (J4) |
| Attaque du perso « marteau » | `SPIKE` (override) | `hammer_spike_v1.json` | `window` | JSON à la main (J4) |

- **Table action → clip** : `data/animations/sets/standard_v1.json`. Overrides par personnage :
  `data/animations/<perso>.json` (seul `hammer_01` en a un : `spike → hammer_spike_v1`), référencé par
  `animation_set_ref` dans `data/characters/<perso>.json`. Liste des actions connues :
  `AnimationSetDefinition.ACTIONS` (`scripts/characters/animation_set_definition.gd`).
- **Générateur** `tools/gen_serve_clips.py` : produit `serve_prep/toss/jump/ground/float/smash_v1` et
  `land_float/smash_v1` à partir de poses écrites en **angles absolus** (repère du monde) avec IK des jambes à
  appuis fixes, et réécrit `standard_v1.json`. `python3 tools/gen_serve_clips.py --preview DOSSIER` dessine les
  poses avec la même cinématique que le rig. **Attention** : relancer le générateur écrase ces 8 JSON ; modifier soit
  le générateur, soit les JSON, pas les deux.
- **Code d'animation** : `scripts/animation/` (`rig_def.gd` squelette et FK, `animation_clip.gd` format et
  interpolation, `clip_library.gd` chargement / overrides / replis, `pose.gd` mélange, `rig_animator.gd` choix du clip,
  temps, transitions, `anim_frame.gd` résultat). Rendu : `scripts/rendering/mannequin_rig.gd` (Skeleton2D + Bone2D),
  `match_view.gd`, `match_overlay.gd` (debug du rig).
- **Service, saut, contact, récupération** (lecture seule pour les animations) : `scripts/gameplay/player_actor.gd`
  (machine d'états, fenêtres, saut, récupération), `serve_charge.gd` (lancer), `serve_prediction.gd` (intention),
  `strike_record.gd` (mémoire de frappe pour le suivi), `contact_spec.gd`, `contact_resolver.gd`, `contact_model.gd`,
  `player_snapshot.gd` (ce que l'animation lit), `scripts/simulation/player_body.gd` (physique du joueur).

## 4. Le rig commun (17 os)

Repère : **mètres**, **x vers l'avant** du personnage, **y vers le BAS** (convention Godot), origine = sol sous les
pieds. Angles en **radians**, **relatifs au parent**, sens de rotation de Godot (horaire à l'écran = positif).
Pose de repos (tous les angles à 0) : debout, bras le long du corps, jambes tendues.

| Os | Parent | Position de repos dans le parent (gabarit 1,80 m) | Longueur | À 0 rad il pointe |
| --- | --- | --- | --- | --- |
| `root` | — | (0, 0) = sol | — | — |
| `pelvis` | root | (0, −0,96) (hanches) | — | — |
| `torso` | pelvis | (0, 0) | 0,52 | vers le haut |
| `neck` | torso | (0, −0,52) | 0,08 | vers le haut |
| `head` | neck | (0, −0,08) | 0,24 | vers le haut |
| `upper_arm_l` / `_r` | torso | (∓0,02, −0,47) (épaule) | 0,30 | vers le bas |
| `forearm_l` / `_r` | upper_arm | (0, 0,30) (coude) | 0,26 | vers le bas |
| `hand_l` / `_r` | forearm | (0, 0,26) (poignet) | 0,09 | vers le bas |
| `thigh_l` / `_r` | pelvis | (∓0,02, 0) (hanche) | 0,45 | vers le bas |
| `shin_l` / `_r` | thigh | (0, 0,45) (genou) | 0,44 | vers le bas |
| `foot_l` / `_r` | shin | (0, 0,44) (cheville) | semelle de −0,07 à +0,20 en x, à +0,07 sous la cheville | vers le bas |

- Os qui **pendent** (bras, cuisses, jambes, pieds) : angle **négatif = vers l'avant**, positif = vers l'arrière,
  ±π = vers le haut. Os qui **montent** (torse, cou, tête) : **positif = penché vers l'avant**.
- **Côté** : `_l` = côté **loin** (dessiné derrière le corps, plus sombre, `RigDef.FAR_BONES`), `_r` = côté **près**.
  Le bras frappeur des services est `upper_arm_r` / `forearm_r`.
- **Limites vérifiées par les tests** (sur chaque pose clé livrée) : `forearm_*` ≤ +0,05 (le coude ne se plie que
  vers l'avant : pas d'hyper-extension) ; `shin_*` ≥ −0,05 (genou) ; |angle| ≤ π. Décision du 31/10 : la limite du
  coude est **conservée** ; l'armé « main au-dessus du coude » d'un vrai service (rotation d'épaule en 3D) est rendu
  par un « arc tendu » (coude en arrière, main en arrière).
- `pelvis` et `root` ne sont **jamais animés** dans les clips livrés (le bassin ne tourne pas, ne se décale pas).
- Morphologie (`data/morphology/*.json`) : taille, longueur de jambe, envergure, corpulence. Elle ne change **que le
  dessin** (`RigDef.dims_for`) ; les mêmes angles s'appliquent à tous les personnages.

## 5. Format d'un clip

Clé du fichier = `id`. Champs (lus par `AnimationClip.from_file`, toute erreur est signalée et réparée) :

| Champ | Rôle | Défaut |
| --- | --- | --- |
| `schema_version` | 1 | obligatoire |
| `id` / `action` | identifiant (`^[a-z][a-z0-9_]*$`) / action de `ACTIONS` | obligatoires |
| `duration_s` | durée du clip (0,05 à 5 s) | 1 |
| `loop` | boucle | false |
| `time_domain` | `seconds`, `window`, `loop_time`, `distance`, `air_velocity`, `length`, `charge` (§ 6) | seconds |
| `pose_mode` | seul `absolute` est pris en charge (pose complète, angles relatifs au parent) | absolute |
| `default_interpolation` | `linear`, `smooth`, `spline` (§ 7) | linear |
| `blend_in_s` | durée du fondu d'entrée (0 à 1 s) | 0,08 |
| `window_start` | repère de départ de la fenêtre (domaine `window`) | début du clip |
| `air_legs` | en l'air, jambes reprises de cette action (ex. `jump`) | — |
| `move_legs` | au sol en mouvement, jambes reprises de cette action (ex. `run`) | — |
| `stride_m`, `air_ref_speed` | cycle de course (m par tour) ; vitesse verticale de référence (domaine `air_velocity`) | 1,9 ; 9,5 |
| `grounded` | indication pour l'aperçu isolé (debug) | true |
| `foot_lock` | **accepté mais ignoré** (aucune implémentation) | — |
| `events` | repères `{t, type, name}` : `type` = `contact_marker` (pour `impact`) ou `visual_marker` | — |
| `keyframes` | `[{t, pose: {os: angle}}]`, `t` strictement croissant dans [0, durée] ; os absent = 0 | ≥ 1 |

Repères utilisés par le code : `impact` (obligatoire en domaine `window`, sinon 40 % de la durée), `cock` (début de
fenêtre des frappes de service, maintien en saut quand les variantes sont coupées), `squash` / `squash_end` (compression
visuelle au départ du saut de service), `release`, `extension`, `follow` (informatifs, testés pour leur présence),
`ready` (maintien du contre). **Aucun repère ne déclenche de contact.**

Exemple réel complet (`data/animations/clips/serve_jump_v1.json`, 3 poses clés, angles relatifs au parent) :

```json
{"schema_version": 1, "id": "serve_jump_v1", "action": "serve_jump", "duration_s": 0.24, "loop": false,
 "time_domain": "seconds", "pose_mode": "absolute", "default_interpolation": "spline", "blend_in_s": 0.03,
 "events": [{"t": 0.0, "type": "visual_marker", "name": "squash"},
            {"t": 0.06, "type": "visual_marker", "name": "extension"},
            {"t": 0.24, "type": "visual_marker", "name": "cock"}],
 "keyframes": [
  {"t": 0.0,  "pose": {"torso": 0.25, "neck": -0.18, "head": -0.27, "upper_arm_l": -2.7, "forearm_l": -0.15, "hand_l": 0.0,
     "upper_arm_r": 1.65, "forearm_r": -1.3, "hand_r": 0.0, "thigh_l": -0.9304, "shin_l": 1.3539, "foot_l": -0.4235,
     "thigh_r": -0.4421, "shin_r": 1.3715, "foot_r": -0.9294}},
  {"t": 0.06, "pose": {"torso": -0.12, "neck": -0.104, "head": -0.156, "upper_arm_l": -2.43, "forearm_l": -0.15, "hand_l": 0.0,
     "upper_arm_r": 2.17, "forearm_r": -1.4, "hand_r": 0.0, "thigh_l": -0.08, "shin_l": 0.05, "foot_l": 0.75,
     "thigh_r": 0.06, "shin_r": 0.08, "foot_r": 0.8}},
  {"t": 0.24, "pose": {"torso": -0.32, "neck": -0.04, "head": -0.06, "upper_arm_l": -2.18, "forearm_l": -0.15, "hand_l": 0.0,
     "upper_arm_r": 2.67, "forearm_r": -1.65, "hand_r": 0.0, "thigh_l": -0.4, "shin_l": 0.8, "foot_l": 0.45,
     "thigh_r": 0.15, "shin_r": 1.0, "foot_r": 0.55}}]}
```

## 6. Temps d'un clip (domaines) — `RigAnimator._clip_time`

Toujours une fonction du **temps de simulation** (120 ticks/s), jamais du nombre d'images : même état → même pose à
30 ou 144 i/s ; la pause fige, le ralenti ralentit. Entre deux ticks, le temps d'état est interpolé (`alpha`).

| Domaine | Temps du clip |
| --- | --- |
| `seconds` | temps écoulé dans l'état de la simulation (au-delà de la durée : dernière pose) |
| `window` | repère `window_start` → `impact` étiré de l'ouverture de la fenêtre jusqu'à l'instant de contact attendu, puis temps réel (§ 10) |
| `charge` | charge du lancer (0 → 1) × durée |
| `loop_time` | temps de jeu, en boucle |
| `distance` | position x × orientation / `stride_m` (cycle de course lié au terrain parcouru : pas de glissement) |
| `air_velocity` | 0,5 − vy / (2 × `air_ref_speed`) : montée en début de clip, chute en fin |
| `length` | temps d'état / durée de l'état (récupération) : le clip s'étire sur la durée réelle de l'atterrissage |

## 7. Interpolation, mélange, priorité, transitions

**Entre deux poses clés d'un clip** (`AnimationClip.sample`) :
- `linear` : interpolation linéaire ; `smooth` : smoothstep par segment (**arrêt sur chaque pose clé**) ;
- `spline` (clips de service) : Hermite **monotone** (Fritsch-Butland) sur des angles **déroulés** : le mouvement garde
  sa vitesse en traversant une pose quand il continue dans le même sens, s'arrête là où il change de sens, ne dépasse
  jamais les poses (pas de dépassement des limites). Tangente nulle au début et à la fin du clip.
- Les angles passent par le plus court chemin (de +2,8 à −3,05, le bras passe au-dessus de la tête, pas par le bas).

**Mélange de poses** (`Pose.mix`) : `lerp_angle` os par os (plus court chemin). `Pose.with_bones_from` remplace un
groupe d'os (jambes) par ceux d'une autre pose.

**Choix du clip et priorité** (`RigAnimator._choose`, puis `evaluate`) :
1. L'**état de la simulation** choisit l'action (table ci-dessous). Aucune animation n'est choisie par une entrée
   clavier ou par la hauteur du ballon.
2. **Suivi du geste de service** (`_follow_through`) : après la fermeture de la fenêtre, si le joueur est `FREE`,
   `AIR` ou `RECOVER`, ne court pas, et que la frappe date de moins de 3 s, le clip de frappe continue (type **réel**
   confirmé, ou intention si frappe manquée) jusqu'à sa fin. Au sol après un flottant / smash : clip d'atterrissage.
   Toute autre action (réception…) a priorité et coupe le suivi.
3. **Jambes** : en l'air, si le clip a `air_legs`, les jambes viennent de ce clip (domaine du clip des jambes) ; au sol
   en mouvement (|vx| > 0,3 m/s) avec `move_legs`, les jambes viennent de la course.
4. **Compression du saut de service** : si le clip a `squash` / `squash_end` et que l'état est `SERVE_JUMP`, les jambes
   partent de la pose `squash` et rejoignent la cible en `squash_end − squash` secondes (visuel uniquement : la vitesse
   verticale part au tick de la commande).
5. **Intensité** (`anim_serve_intensity`, clips de la famille service) : buste, cou, tête, bras multipliés (bornés à ±π),
   jamais les jambes.
6. **Fondu d'entrée** (`_blend_in`) : à chaque changement de clip (ou de repère de maintien), fondu smoothstep depuis
   la **dernière pose affichée**, durée `blend_in_s` du nouveau clip, ou `anim_serve_blend_s` si > 0 pour la famille
   service. En `SERVE_HIT`, le fondu est plafonné à 40 % du temps restant avant le contact attendu.
7. **Calage au sol** (joueur au sol) : la pose est décalée verticalement (`shift_y`, borné à ±0,6 m) pour que la semelle
   la plus basse touche le sol. En l'air : pas de calage.

| État | Action jouée | Remarque |
| --- | --- | --- |
| `FREE`, `LOCKED` | `idle` ou `run` (si \|vx\| > 0,3) | `run` en domaine `distance` |
| `AIR` | `jump` | ou suivi du geste de service |
| `RECOVER` | `land`, ou `land_float` / `land_smash` si la frappe CONFIRMÉE date de < 2 s | domaine `length` |
| `RECEIVE`, `SET`, `SPIKE`, `FEINT` | `receive`, `set`, `spike`, `feint` | domaine `window` (calé sur `*_ideal`) |
| `SERVE_HOLD` | `serve_prep` | domaine `charge`, jambes de course si le serveur se déplace |
| `SERVE_TOSS` | `serve_toss` | jambes de course si déplacement |
| `SERVE_JUMP` | `serve_jump` (ou `serve_toss` figé au repère `cock` si variantes coupées) | |
| `SERVE_HIT` | `serve_ground` / `serve_float` / `serve_smash` selon l'**intention** | `serve` si variantes coupées |
| `BLOCK_READY` / `BLOCK_AIR` | `block` (maintien `ready` / lecture) | |

Réglages visuels (sandbox, groupe Affichage, sans effet sur la simulation) : `anim_serve_variants` (0/1),
`anim_serve_intensity` (0,5–1,5), `anim_follow_through_scale` (0,5–2, durée du suivi), `anim_serve_blend_s` (0–0,3 s).

## 8. Orientation gauche / droite

- Les clips sont écrits pour un joueur **tourné vers +x (la droite)**. Aucun angle n'est inversé selon le côté.
- `facing` (±1) vient de la simulation (camp du joueur, fixe pendant un match). Le rendu miroir le rig entier :
  `MannequinRig.place(feet, px_par_m, facing)` → `scale = (px_par_m × facing, px_par_m)`.
- Les os `_l` restent toujours « loin » (derrière), `_r` « près », quel que soit le côté.
- Domaine `distance` : le cycle utilise `position.x × facing`, symétrique pour les deux côtés.

## 9. Déplacement physique et décalages visuels

- La position du joueur est **uniquement** celle de `PlayerBody` (pieds, en mètres) : course, saut, gravité, bornes du
  terrain, vitesse réduite pendant les actions (`action_move_factor`, `serve_toss_move_factor`). L'animation **ne
  déplace jamais** le joueur (pas de « root motion »), ne change ni sa vitesse ni sa hauteur de saut.
- Le rig est posé aux pieds interpolés entre deux ticks. Seuls décalages visuels : `shift_y` (calage au sol, au sol
  seulement) et la caméra (secousse ≤ 6 px du SJ2). Les jambes repliées en l'air sont visuelles : la hauteur réelle
  des pieds est `PlayerBody.position.y`.
- Le bassin n'est jamais décalé horizontalement : un transfert de poids se montre par les genoux, le buste et les
  talons (pointe avant levée puis talon arrière levé dans `serve_ground_v1`), appuis au sol fixes.

## 10. Contact physique et synchronisation de la pose de frappe

**Le contact est décidé par la simulation seule** (`PlayerActor._update_window`), jamais par la main du mannequin :
- Une action à fenêtre (`ContactSpec`, paramètres `*_on`, `*_off`, `*_ideal`, `*_time_tol`, `*_zone_dx/dy/radius`)
  ouvre une **zone circulaire** fixée au joueur. Service : centre à (0,35 m devant, 2,1 m au-dessus des pieds),
  rayon 0,7 m, fenêtre de 0,03 à 0,28 s, instant idéal 0,12 s.
- À chaque tick de la fenêtre, le segment parcouru par le ballon est comparé à la zone (collision balayée). Le contact
  est validé au tick de l'**approche maximale** (ou quand le ballon ressort de la zone, ou à la fermeture si le
  ballon est encore dedans). Qualité = f(écart au temps idéal, distance au centre) → vitesse et angle de sortie.
  Sans passage dans la zone : `ACTION_MISSED`, aucune frappe.
- **Type de service** = hauteur des pieds au tick du contact (§ 2).

**Synchronisation** :
1. À l'ouverture de `SERVE_HIT`, `ServePrediction` rejoue ballon et saut avec la même physique et la même règle de
   validation pour annoncer l'**intention** (type probable) et l'**instant de contact attendu** (`serve_expected`).
   Elle est réévaluée à chaque tick jusqu'au contact. Le clip est choisi d'après cette intention.
2. Domaine `window` : le repère `impact` du clip est amené sur `serve_expected` (sinon sur l'instant idéal).
   Le temps du clip est **lissé** : il ne revient jamais en arrière et avance au plus à 3,5 × le temps réel.
3. Au contact, `CONTACT.serve_kind` donne le type **réel** ; `StrikeRecord` le garde pour le suivi et l'atterrissage.
   Le résultat physique est prioritaire : si la prévision se trompait, seuls le suivi et l'atterrissage changent.
4. Frappe manquée : pas de contact ; le geste de l'intention se termine normalement.
5. Mesures (balayage de 72 scénarios de frappe et 20 services IA) : intention = type réel = clip dans tous les cas testés ; écart entre
   l'impact visuel et le contact réel < 0,08 s de clip (test `test_impact_marker_follows_the_real_contact…`).

**Ce qu'il ne faut pas faire** : déplacer le repère `impact` pour « mieux coller » au ballon en modifiant la
simulation ; changer `serve_zone_*`, `*_ideal`, la gravité ou les vitesses ; ajouter une logique de contact dans le
rendu. Pour rapprocher la main du ballon, changer la **pose** à `impact` (bras plus haut / plus avancé).

## 11. Tests utiles aux animations (tous inclus dans l'archive)

| Fichier | Ce qu'il vérifie |
| --- | --- |
| `tests/integration/test_serve_animation.gd` (15) | marqueurs des clips, pieds plantés (sol), choix du clip par l'intention, flottant ≠ smash, intention = clip = réel, atterrissage selon le type confirmé, suivi au sol, frappe manquée cohérente, impact calé sur le contact sans modifier la simulation, impulsion immédiate, absence d'à-coups, **continuité par articulation** (épaules, coudes < 0,6 rad/tick ; autres < 0,35 ; à-coup < 0,6), autres personnages, réglages visuels, IA |
| `tests/integration/test_rig_animator.gd` (13) | chaque état → un clip, course liée à la distance, saut lié à la vitesse verticale, atterrissage étiré, maintiens, fondus, pause, vitesse d'animation, aucune écriture dans la simulation, préparation selon la charge, jambes de course du serveur |
| `tests/unit/test_animation_clip.gd` (10) | chargement de tous les clips sans problème, interpolations (dont spline), boucle, réparation des données invalides, replis, **limites articulaires**, poses au sol sans chute extrême |
| `tests/unit/test_rig_def.gd` (6), `tests/integration/test_mannequin_view.gd` (5) | hiérarchie de 17 os, proportions, repos au sol, longueurs constantes, morphologie visuelle seulement |
| `tests/integration/test_serve.gd` (24) | mécanique du service (lancer, saut, fenêtre, type, prévision) — **ne pas modifier** |
| `tests/unit/test_architecture.gd` (5) | dépendances entre couches, motifs interdits dans la simulation |

Avant toute livraison : `godot --headless --path . -s tests/run_tests.gd` (0 échec) et `-- --sim 12` (981 / 358 / 2,74
inchangés : une différence signifie que la simulation a été touchée).

## 12. Limites, bugs connus et points non testés

**Limites connues** :
1. **La main n'est pas alignée sur le ballon** : le contact se fait dans une zone de 0,7 m de rayon ; la pose `impact`
   montre une frappe plausible, pas la position exacte du ballon (aucune IK de la main vers le ballon).
2. Rig 2D : pas de rotation d'épaule ni de buste en profondeur ; la limite du coude empêche l'armé « main au-dessus du
   coude » (choix validé : à retravailler avec les visuels du personnage pilote).
3. Le bassin ne tourne ni ne glisse (aucun clip ne l'anime) ; le transfert de poids reste limité.
4. Pas d'IK des pieds à l'exécution : les jambes sont précalculées (générateur) ; seul le calage vertical au sol existe.
5. En l'air, les jambes des frappes flottante / smash suivent le temps du clip, pas la vitesse verticale :
   l'anticipation de l'atterrissage n'est pas pilotée par la hauteur réelle (fondu de 0,04 s à l'atterrissage).
6. **Course en marche arrière** : le cycle `distance` est joué à l'envers (effet « moonwalk »).
7. **Clips du jeu courant** (`idle`, `run`, `jump`, `land`, `receive`, `set`, `spike`, `feint`, `block`) : encore ceux
   du J4, 2 à 4 poses en `smooth` (arrêt sur chaque pose) : raides ; armé de l'attaque « bras tendu vers le haut » ;
   `land_v1` ressemble à une préparation de saut ; contre debout jambes tendues. Diagnostic du 01/11/2026, non corrigé.
8. Intensité (`anim_serve_intensity`) : simple multiplication des angles relatifs, grossière à fort réglage.
9. `foot_lock` est accepté dans les clips mais n'a aucun effet.
10. Gameplay (hors animation) : avec la visée assistée, un smash sort à peu près à la vitesse d'un flottant
    (≈ 45 km/h) ; la différence perçue repose sur le geste et les effets.

**Non testé ou non vérifié visuellement** :
- Service du joueur tourné vers la gauche (équipe rouge) : symétrie par miroir testée pour la course seulement ;
  aucune capture des services en `facing = −1`.
- Personnages autres que l'attaquant standard en vidéo : les clips de service sont testés (angles finis, pieds au sol)
  sur `hammer_01` et `std_setter_02`, sans revue visuelle.
- Fréquences d'affichage autres que 60 i/s (l'animation dépend du temps de simulation, testé par les tests unitaires).
- Ressenti manette / clavier : à valider par Djebril ; aucune mesure de latence perçue.
- Services IA en match : 20 services vérifiés pour la cohérence intention / type ; pas de revue visuelle exhaustive.
- Simulation à 60 ou 240 ticks/s : non testée avec les nouveaux clips (référence à 120).
