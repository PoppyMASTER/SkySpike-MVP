# SkySpike MVP — règles permanentes

Le propriétaire (Djebril) parle français : réponses, commentaires, docs et messages de commit en français.
Spécification : cahier des charges MVP V1 (31/10/2026) et Phase 0 validée « tout comme recommandé ».
Travail **un jalon à la fois** (`docs/ROADMAP.md`) ; ne pas commencer le jalon suivant sans validation.

## Ne jamais

- Modifier l'ancien dépôt `PoppyMASTER/Spike` ni en copier les scripts monolithiques.
- Écrire une valeur de gameplay en dur : tout passe par `data/params/param_defs.json` + `ParamIds` + `ParamStore`.
- Lire un dictionnaire JSON brut dans une mécanique : chargeurs de `scripts/data/` → objets typés.
- Utiliser dans `simulation/`, `gameplay/`, `ai/` : `randf`/`randi`/`RandomNumberGenerator` (hors `MatchRng`),
  `Time.*`, `delta`, `_process`, nœuds physiques Godot. Le test d'architecture le vérifie.
- Faire écrire le rendu, l'animation ou les effets dans la simulation. Un marqueur d'animation ne déclenche pas de contact.
- Ajouter une fonctionnalité hors MVP (réseau, gacha, menus complets, progression…) ou un fichier vide « pour plus tard ».
- Prétendre avoir testé sans avoir exécuté. Le ressenti manette/clavier est validé par Djebril.

## Toujours

- Respecter les dépendances entre couches (`docs/ARCHITECTURE.md`, vérifiées par `tests/unit/test_architecture.gd`).
- Ajouter ou mettre à jour les tests avec chaque changement ; lancer la suite avant de pousser :
  `godot --headless --path . --import && godot --headless --path . -s tests/run_tests.gd`
- Regarder une capture avant d'affirmer qu'un écran est correct :
  `xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --resolution 1600x900 -- --capture DOSSIER`
- Présenter toute modification structurelle avant de l'appliquer ; noter les décisions dans `docs/DECISIONS.md`.
- Distinguer dans les docs : constat d'audit, décision validée, hypothèse, valeur de calibration.
- Script > 300 lignes : revoir le découpage (seuil de revue, pas une limite artificielle).

## Conventions

`snake_case` pour fichiers, fonctions, variables, signaux ; `PascalCase` pour les classes ; `UPPER_SNAKE_CASE` pour les constantes.
Scripts typés. Détails : `docs/CODING_STANDARDS.md`.
