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
Fichier absent → `standard_v1`, aucun remplacement. L'existence des clips et leur format sont vérifiés au J4.

## Clip — `data/animations/clips/<id>.json` [Prévu J4]

Contrat défini en Phase 0 (section E) : `schema_version`, `id`, `action`, `duration_s`, `loop`, `time_domain`,
`pose_mode` (`absolute` seulement en V1), `default_interpolation`, `foot_lock`, `keyframes`, `events`
(`visual_marker` / `contact_marker`). 17 os : `root`, `pelvis`, `torso`, `neck`, `head`, `upper_arm_l/r`,
`forearm_l/r`, `hand_l/r`, `thigh_l/r`, `shin_l/r`, `foot_l/r`. Angles en radians relatifs au repos, perso tourné
vers +x, sens de rotation de Godot.

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
