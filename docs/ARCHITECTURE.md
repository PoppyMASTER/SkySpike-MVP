# Architecture

## Principe

Une seule direction : les entrées (humain et IA) deviennent des intentions, `MatchSim` est le seul
à modifier l'état, et tout ce qui est visuel lit `MatchState` + `MatchEvent` sans rien écrire.

```
Clavier / manette ─► InputMapper ─┐
                                   ├─► PlayerIntent ×6 ─► MatchSim (pas fixe, MatchRng) ─► MatchState + MatchEvent
AiController (lit MatchState) ─────┘                                                        │
                                                                    ┌──────────────────────┼─────────────────┐
                                                                    ▼                      ▼                 ▼
                                                              Animation ─► Rig       Rendu (balle,      Debug / sandbox
                                                              (clips, IK)  Skeleton2D  traînée, caméra)  (lit tout, écrit via ParamStore)
JSON ─► chargeurs (data/) ─► objets typés          ParamStore (unités, bornes, défauts) ─► MatchSim, rendu, debug
```

État au J3 : `MatchSim` contient le ballon, le filet, six joueurs, l'arbitre (`Referee`), les contacts (`ContactResolver`) et le contre (`BlockResolver`) ; l'IA (`AiDirector`, couche `ai`) lit `MatchState` et produit des `PlayerIntent`. L'animation arrive au J4.

Ordre d'un tick : ballon (intégration, collision balayée du filet) → joueurs (mouvement, actions, contacts) → sol (atterrissage, relance).
Entrées : `InputMapper.poll` (chaque image) → `InputLatch` → un `PlayerIntent` consommé par tick (les appuis ne sont ni perdus ni doublés).

## Couches et dépendances autorisées

Une couche ne peut utiliser que les couches listées. Vérifié automatiquement
(`tests/architecture_scan.gd` → `tests/unit/test_architecture.gd`) par recherche des `class_name`.

| Couche (`scripts/…`) | Rôle | Peut utiliser |
| --- | --- | --- |
| `core` | Enums, journal, horloge à ticks, hasard à graine, paramètres | — |
| `characters` | Définitions typées des persos, conversion stat → grandeur physique | core |
| `data` | Lecture JSON, validation, construction des objets typés, presets | core, characters |
| `simulation` | Corps physiques purs (ballon ; joueurs au J2), intégration, collisions | core, characters |
| `gameplay` | `MatchSim` (seul autoritaire), état, événements, règles (J3) | core, characters, simulation |
| `input` (J2) | Périphériques → `PlayerIntent` | core, gameplay |
| `ai` | `MatchState` → `PlayerIntent` | core, characters, simulation, gameplay |
| `animation` (J4) | Clips, lecteur, IK, morphologie du rig | core, data, characters, gameplay |
| `rendering` | Dessin, interpolation, caméra, effets | core, characters, simulation, gameplay, animation |
| `audio` (J4.1 SJ2) | Sons de frappe : écoute les événements, n'écrit jamais dans la simulation | core, data, gameplay |
| `app` | Assemblage : `GameData`, `MatchRunner` (crée `MatchAudio` en nœud enfant, aucun autoload), `main.gd` | tout sauf debug |
| `debug` | Panneau sandbox, diagnostics | tout (écrit seulement via `ParamStore` et l'API de `MatchRunner`) |

Seule la couche `app` charge des scripts ou scènes par chemin ; ailleurs, on passe par `class_name`.

Dans `simulation`, `gameplay` et `ai` sont interdits : hasard hors `MatchRng`, `Time.*`, `delta`,
`_process`, nœuds physiques Godot (vérifié par test).

## Boucle à pas fixe

- `MatchRunner._process(delta)` → `SimClock.advance(delta)` renvoie le nombre de ticks à exécuter.
  `acc += min(delta, max_frame_s) × time_scale` ; un tick tant que `acc ≥ dt`, plafonné à `max_ticks_per_frame`
  (le surplus est abandonné et compté dans le diagnostic).
- `dt = 1 / sim_hz` (120 par défaut, réglable 60–240, appliqué au prochain match).
- Ralenti = `time_scale < 1` ; pause et pas à pas via `SimClock`. La durée d'un tick ne change jamais :
  le résultat logique est identique quel que soit le FPS ou le ralenti (test `integration/test_determinism.gd`).
- Rendu : interpolation entre les deux derniers états avec `alpha = acc / dt`.
- Pourquoi pas `_physics_process` : pause, pas à pas, ralenti et fréquence pilotés depuis le panneau,
  sans dépendre d'un réglage moteur global.

## Hasard

`MatchRng` : graine maître → flux `contacts`, `ai`, `misc` (graines dérivées par `hash`). Chaque tirage
porte une étiquette ; mode trace pour journaliser. Changer le comportement de l'IA ne décale pas les
tirages des contacts.

Limite : reproductible sur la même machine et le même exécutable ; pas de garantie entre plateformes.
La dérivation des graines est figée par un test : si une version de Godot la change, le test le signale.

## Fichiers (J4)

```
scenes/main.tscn                  → scripts/app/main.gd
scenes/match/match.tscn           → MatchRunner + MatchView + DebugLayer (DiagnosticsOverlay, SandboxPanel)
scripts/core/                     enums, game_log, match_rng, sim_clock, param_def, param_preset, param_store, param_ids
scripts/data/                     load_issue, json_loader, schema_reader, param_def_loader, preset_store, character_repository
scripts/characters/               stats/morphology/animation_set/character_definition, stat_conversion
scripts/simulation/                ball_body, player_body, court_geometry, swept_collision, sweep_hit, ballistics
scripts/gameplay/                 match_sim, match_state, match_event, rally_state, referee, contact_spec, contact_resolver,
                                  block_resolver, player_intent, player_actor, player_snapshot, contact_model, sim_context
scripts/ai/                       ai_director
scripts/input/                    input_mapper, input_latch
scripts/animation/                rig_def, rig_dims, pose, animation_clip, clip_library, anim_frame, rig_animator
scripts/rendering/                match_view, match_overlay, mannequin_rig, anim_sheet
scripts/app/                      game_data, match_runner, match_config, ai_match, main
scripts/debug/                    sandbox_panel, param_row, diagnostics_overlay
data/animations/                  sets/standard_v1.json, clips/*.json, <personnage>.json (remplacements)
tests/                            run_tests.gd, test_case.gd, architecture_scan.gd, unit/, integration/
```

## Animation et rendu des joueurs (J4)

```
MatchState / PlayerSnapshot  →  RigAnimator (couche animation)  →  AnimFrame (pose + décalage vertical)
                                      ↑ ClipLibrary (clips JSON)           ↓
                                                                    MannequinRig (Skeleton2D + 17 Bone2D + pièces rigides)
```

- **Source de vérité** : la simulation. Le rendu ne lit que `MatchState` ; il n'écrit jamais dans la simulation (test :
  1 500 ticks avec et sans rendu, mêmes empreintes).
- **Animation = fonction de l'état de simulation** : action en cours, temps d'action, instant idéal, vitesse, position, tick.
  Aucun temps réel, aucun `delta` : la couche `animation` est soumise aux mêmes interdits que `simulation` (vérifié par test).
  Même état → même pose à 30 ou 144 i/s ; pause et ralenti figent ou ralentissent aussi l'animation.
- **Impact visuel** : le repère `impact` du clip est calé sur l'instant idéal de l'action (domaine `window`). Il accompagne le
  contact, il ne le déclenche pas.
- **Fondus** : quand le clip change, la pose précédente est fondue vers la nouvelle (`blend_in_s`, en temps de simulation).
- **Pieds au sol** : au sol, le rig est décalé verticalement pour que les semelles touchent le sol (le corps physique reste
  celui de la simulation). En l'air, aucun décalage.
- **Morphologie** : `height`, `weight`, `arm_span`, `leg_length` ne changent que les dimensions du dessin (`RigDims`).
  Test : `simulation`, `gameplay`, `ai` et `input` ne lisent jamais la morphologie.
- **Remplacer le dessin par des sprites** : réécrire `MannequinRig._build_pieces` (une pièce par os). Squelette, poses,
  animateur, clips, simulation et données restent inchangés.
- **Debug** : F3 squelette, F4 pivots, F5 animation active et progression, F2 zones ; panneau F1 → Animation : aperçu d'un
  clip isolé (horloge propre, pause, vitesse), vitesse de lecture des animations du match, retour aux valeurs par défaut.
  La vitesse d'animation est un réglage de la vue : elle ne touche jamais à `time_scale` de la simulation.
