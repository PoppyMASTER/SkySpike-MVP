# Formats de données

Tous les fichiers sont dans `data/`, en JSON UTF-8, versionnés par `schema_version` (actuellement 1).

## Règles communes

- `schema_version` obligatoire ; version inconnue = fichier rejeté.
- `id` : `^[a-z0-9_]+$`, unique, **égal au nom du fichier** (personnages, presets).
- Champ inconnu = avertissement (le fichier est gardé).
- Chaque problème produit un `LoadIssue` : fichier, chemin du champ (`stats.receive`, `values.ball_gravity`…), message.
  Visibles dans l'onglet « Données » du panneau (F1) et dans le journal. **Aucun chargement ne fait planter le jeu.**
- Chemins `*_ref` relatifs à `data/`.

## Personnage — `data/characters/<id>.json`

| Champ | Type | Obligatoire | Note |
| --- | --- | --- | --- |
| `schema_version` | entier | oui | 1 |
| `id` | chaîne | oui | = nom du fichier |
| `display_name` | chaîne | oui | |
| `role` | `attacker` / `setter` / `defender` | oui | |
| `stats_ref` | chemin | oui | |
| `morphology_ref` | chemin | non | |
| `animation_set_ref` | chemin | non | |
| `appearance_ref` | chemin | non | pas encore pris en charge (J4) : avertissement |

Identité incomplète, rôle inconnu, version inconnue ou id ≠ nom de fichier → **personnage rejeté** (absent de la sélection).

## Stats — `data/characters/stats/<id>.json`

8 entiers 0–100 : `attack_power`, `receive`, `block`, `set_power`, `set_accuracy`, `spike_accuracy`, `speed`, `jump`.

| Problème | Repli |
| --- | --- |
| Stat manquante | valeur du gabarit de rôle + avertissement |
| Stat hors bornes ou mauvais type | valeur du gabarit de rôle + erreur |
| Fichier introuvable, illisible ou version inconnue | gabarit de rôle entier |
| Gabarit de rôle absent | toutes les stats à 50 + avertissement |

Gabarits : `data/characters/stats/_role_attacker.json`, `_role_setter.json`, `_role_defender.json`.

### Conversion en grandeurs physiques

`valeur = min + (max − min) × (stat / 100)^courbe`, bornes et courbes dans les paramètres (groupe « Stats → physique »).

| Stat | Grandeur | Paramètres |
| --- | --- | --- |
| `speed` | vitesse de course (m/s) | `speed_min`, `speed_max`, `speed_curve` |
| `jump` | apogée du saut (m) | `jump_apex_min`, `jump_apex_max`, `jump_curve` |
| `attack_power` | vitesse de smash, de service (m/s) | `spike_speed_*`, `serve_speed_*`, `power_curve` |
| `set_power` | vitesse max de passe (m/s) | `set_speed_*`, `power_curve` |
| `spike_accuracy`, `set_accuracy`, `receive` | dispersion d'angle (rad), décroissante | `*_noise_at_0`, `*_noise_at_100`, `accuracy_curve` |
| `block` | facteur de bloc (sans unité) | `block_factor_*`, `block_curve` |

## Morphologie — `data/morphology/<id>.json`

`height`, `weight`, `arm_span`, `leg_length` : réels, 1.0 = gabarit standard. **Visuel uniquement en V1.**
Plage normale 0.85–1.15 ; 0.6–1.5 accepté avec avertissement ; au-delà → 1.0. Champ ou fichier absent → 1.0.
`weight` = indice de corpulence visuelle, pas une masse.

## Ensemble d'animations — `data/animations/<id>.json`

```json
{ "schema_version": 1, "default_set": "standard_v1", "overrides": { "spike": "hammer_spike_v1" } }
```

Actions : `idle`, `run`, `jump`, `land`, `receive`, `set`, `spike`, `serve`, `block`, `feint`.
Action inconnue → remplacement ignoré + erreur. `default_set` inconnu → `standard_v1` + erreur.
Fichier absent → `standard_v1`, aucun remplacement. Depuis le J4, l'existence des clips et leur action sont vérifiées au chargement (voir ci-dessous).

## Ensemble standard — `data/animations/sets/standard_v1.json` [J4]

```json
{ "schema_version": 1, "id": "standard_v1", "actions": { "idle": "idle_v1", "run": "run_v1", "jump": "jump_v1",
  "land": "land_v1", "receive": "receive_v1", "set": "set_v1", "spike": "spike_v1", "serve": "serve_v1",
  "block": "block_v1", "feint": "feint_v1" } }
```

Chaque action de `AnimationSetDefinition.ACTIONS` doit pointer vers un clip existant. Un personnage remplace une
action par `overrides` (ex. `"spike": "hammer_spike_v1"`) sans changer de rig. Repli : clip du personnage introuvable →
clip standard ; action sans clip standard → pose de repos ; chaque repli est journalisé une fois.

## Clip — `data/animations/clips/<id>.json` [J4]

```json
{ "schema_version": 1, "id": "receive_v1", "action": "receive", "duration_s": 0.5, "loop": false,
  "time_domain": "window", "pose_mode": "absolute", "default_interpolation": "smooth",
  "blend_in_s": 0.05, "events": [ { "t": 0.2, "type": "contact_marker", "name": "impact" } ],
  "keyframes": [ { "t": 0.0, "pose": { "thigh_l": -0.87, "torso": 0.49 } }, { "t": 0.2, "pose": { "…": 0.0 } } ] }
```

| Champ | Rôle | Valeur par défaut / repli |
| --- | --- | --- |
| `time_domain` | Comment l'état de la simulation choisit l'instant du clip (voir ci-dessous) | `seconds` (domaine inconnu : erreur + `seconds`) |
| `loop` | Boucle (retour de la dernière pose vers la première) | faux |
| `default_interpolation` | `linear` ou `smooth` (lissage) | `linear` |
| `blend_in_s` | Durée du fondu depuis l'animation précédente | 0,08 s |
| `grounded` | Les poses supposent un joueur au sol (le rendu pose alors les semelles sur le sol) ; faux = clip aérien | vrai |
| `air_legs` | Si le joueur est en l'air, les jambes viennent de cette animation (ex. `jump`) | aucune |
| `stride_m` | Course : distance parcourue pour un tour de clip | 1,9 m |
| `air_ref_speed` | Saut : vitesse verticale (m/s) qui correspond au début / à la fin du clip | 9,5 |
| `window_start` | Fenêtre : repère où commence la lecture (ex. `toss` pour le service) | début du clip |
| `events` | Repères `{ t, name, type }` (`visual_marker`, `contact_marker`) : `impact`, `hold`, `toss`, `ready` | — |
| `foot_lock` | Accepté, ignoré en V1 (les semelles sont posées automatiquement) | — |

Domaines : `seconds` (secondes écoulées dans l'état) · `window` (le repère `impact` tombe sur l'instant idéal de la
simulation ; avant : préparation accélérée ou ralentie ; après : vitesse normale) · `loop_time` (temps de jeu, boucle) ·
`distance` (cycle de course selon la distance parcourue dans le sens du regard : reculer rejoue le cycle à l'envers) ·
`air_velocity` (vitesse verticale : montée → chute) · `length` (étalé sur la durée de l'état, ex. récupération).
Un repère `impact` **n'a jamais d'effet sur le gameplay** : c'est un point de calage visuel.

Les 17 os : `root`, `pelvis`, `torso`, `neck`, `head`, `upper_arm_l/r`, `forearm_l/r`, `hand_l/r`, `thigh_l/r`,
`shin_l/r`, `foot_l/r`. Pose = angles en radians, **absolus** par rapport au repos, sens de rotation de Godot
(y vers le bas), personnage tourné vers +x : os qui pendent (bras, cuisses, jambes, pieds) → angle négatif = vers
l'AVANT ; os qui montent (torse, cou, tête) → angle positif = penché vers l'AVANT. Un os absent d'une pose clé = repos.

| Problème | Repli |
| --- | --- |
| Fichier illisible, version inconnue, `id` ≠ nom de fichier, `action` manquante, aucune pose valide | clip rejeté (erreur) → repli du jeu standard |
| Os inconnu | ignoré (avertissement) |
| Angle hors ±π ou non numérique | repos pour cet os (erreur) |
| Temps de pose hors du clip ou non croissant | pose ignorée (erreur) |
| Repère hors du clip, `window_start` inconnu | repère ignoré (erreur) |
| Domaine `window` sans repère `impact` | 40 % de la durée (avertissement) |
| `pose_mode` autre que `absolute` | `absolute` (erreur) |

## Paramètres — `data/params/param_defs.json`

```json
{ "schema_version": 1, "params": [ {
  "id": "ball_gravity", "group": "physics", "label": "Gravité du ballon", "unit": "m/s²",
  "default": 10.0, "min": 6.0, "max": 16.0, "experimental_min": 0.5, "experimental_max": 40.0,
  "apply": "immediate", "integer": false, "step": 0.1, "description": "…" } ] }
```

`apply` : `immediate`, `next_rally`, `next_match`. Refusé : défaut hors bornes, min > max, bornes expérimentales
qui n'englobent pas les bornes normales, id en double ou mal formé.

## Presets — `data/presets/` (livrés, lecture seule) et `user://presets/` (utilisateur)

```json
{ "schema_version": 1, "id": "legacy_reference", "base": "default", "experimental": false,
  "notes": "…", "values": { "ball_gravity": 11.0 } }
```

Un preset peut être partiel : il s'applique par-dessus sa base (chaîne de `base` résolue). Une valeur hors bornes
est refusée et signalée, sauf si le preset est marqué `experimental` (le mode expérimental s'active alors).
Exports du panneau : `user://exports/preset_<date>.json`.
