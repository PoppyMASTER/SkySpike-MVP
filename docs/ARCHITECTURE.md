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

État au J1 : `MatchSim` ne contient que le ballon (exercice de lancer) ; entrées, IA, animation arrivent aux J2–J4.

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
| `ai` (J3) | `MatchState` → `PlayerIntent` | core, characters, simulation, gameplay |
| `animation` (J4) | Clips, lecteur, IK, morphologie du rig | core, data, characters, gameplay |
| `rendering` | Dessin, interpolation, caméra, effets | core, characters, simulation, gameplay, animation |
| `app` | Assemblage : `GameData`, `MatchRunner`, `main.gd` | tout sauf debug |
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

## Fichiers (J1)

```
scenes/main.tscn                  → scripts/app/main.gd
scenes/match/match.tscn           → MatchRunner + MatchView + DebugLayer (DiagnosticsOverlay, SandboxPanel)
scripts/core/                     enums, game_log, match_rng, sim_clock, param_def, param_preset, param_store, param_ids
scripts/data/                     load_issue, json_loader, schema_reader, param_def_loader, preset_store, character_repository
scripts/characters/               stats/morphology/animation_set/character_definition, stat_conversion
scripts/simulation/ball_body.gd
scripts/gameplay/                 match_sim, match_state, match_event
scripts/rendering/match_view.gd
scripts/app/                      game_data, match_runner, main
scripts/debug/                    sandbox_panel, param_row, diagnostics_overlay
tests/                            run_tests.gd, test_case.gd, architecture_scan.gd, unit/, integration/
```
