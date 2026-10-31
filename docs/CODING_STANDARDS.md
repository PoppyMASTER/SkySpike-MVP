# Conventions de code

## Nommage

- Dossiers, fichiers, fonctions, variables, signaux : `snake_case`.
- Classes (`class_name`) : `PascalCase`. Constantes et valeurs d'enum : `UPPER_SNAKE_CASE`.
- Membres privés : préfixe `_`.
- Identifiants de données (persos, clips, presets, paramètres) : `^[a-z0-9_]+$`, égaux au nom du fichier.

## Règles

1. **Un script = une responsabilité principale.** Au-delà de ~300 lignes, revoir le découpage
   (le test d'architecture liste ces fichiers) sans fractionner artificiellement.
2. **Typage** : variables, paramètres et retours typés ; `Array[T]` quand c'est possible. Pas de `:=` sur une
   valeur `Variant` (lire un JSON) : type explicite.
3. **Aucune valeur de gameplay en dur.** Déclarer le paramètre dans `data/params/param_defs.json`, régénérer la
   constante dans `scripts/core/param_ids.gd`, lire via `params.get_value(ParamIds.X)`. Les tests vérifient que chaque
   paramètre déclaré a sa constante et qu'il est réellement lu.
4. **Données** : jamais de dictionnaire JSON brut dans une mécanique. Ajouter le champ au chargeur (`scripts/data/`),
   à l'objet typé et à `docs/DATA_FORMATS.md`, avec son repli et un test.
5. **Erreurs** : jamais de plantage silencieux. Problème de données → `LoadIssue` (fichier + chemin du champ + message),
   journal central `GameLog`, onglet « Données » du panneau.
6. **Dépendances** : respecter la table de `ARCHITECTURE.md`. Pas de bus global ; signaux locaux ou appels explicites.
7. **Déterminisme** : dans `simulation`, `gameplay`, `ai`, ni temps réel, ni `delta`, ni hasard hors `MatchRng`.
8. **Commentaires** en français, `##` pour la documentation d'une classe ou fonction : dire le pourquoi, pas le quoi.
9. **Tests** : toute règle de jeu, conversion ou chargement a un test dans `tests/unit` ou `tests/integration`.
   Un test se nomme `test_<ce_qui_est_vérifié>` ; les messages d'assertion disent ce qui est attendu.

## Ajouter un paramètre

1. Entrée dans `data/params/param_defs.json` (id, groupe, libellé, unité, défaut, bornes normales et expérimentales,
   mode d'application `immediate` / `next_rally` / `next_match`, description).
2. Constante dans `scripts/core/param_ids.gd`.
3. Lecture dans le code via `ParamIds`.
4. Éventuellement valeur historique dans `data/presets/legacy_reference.json`.
Le panneau sandbox l'affiche automatiquement dans l'onglet de son groupe.
