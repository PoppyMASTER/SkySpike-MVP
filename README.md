# SkySpike MVP V1

Sandbox de volleyball 2D 3 contre 3 (vue de profil), sous **Godot 4.7.2 / GDScript**.
Projet neuf, distinct de l'ancien SkySpike (archivé : dépôt `PoppyMASTER/Spike`, commit `5c3b1b7`).

**État : jalon J4 (animation).** Six mannequins humanoïdes gris anthracite aux proportions naturelles, articulés
(`Skeleton2D` / `Bone2D`), jouent un match complet : course, saut, réception, passe, service, smash (une main ou marteau à
deux mains), feinte, contre. Liseré bleu (équipe du joueur) ou rouge, indicateur jaune sur le joueur contrôlé.
Les animations sont des clips JSON calés sur la simulation (jamais l'inverse). Le plongeon reste hors MVP.

## Lancer

```bash
godot --path .                                   # ouvre la scène de test
godot --headless --path . --import               # (1re fois) importe le projet
godot --headless --path . -s tests/run_tests.gd  # tous les tests ; code de sortie 0 = OK
godot --headless --path . -s tests/run_tests.gd -- determinism   # filtre par nom de fichier
```

En jeu (touches provisoires) : **← → / Q D** bouger · **Espace** sauter, puis **Espace** en l'air = smash ·
**J** réception (au sol), contre (au filet) ou feinte (en l'air) · **K** passe · **L** service.
Manette : stick gauche, **A** saut/smash, **X** réception/contre/feinte, **B** passe, **Y** service.
Debug : **F1** panneau sandbox (joueur contrôlé, visée, onglet Animation) · **F2** zones · **F3** squelette · **F4** pivots · **F5** animation active · **P** pause · **N** un tick · **R** relancer.
Outils : `-- --sim N` joue N matchs IA contre IA et résume ; `-- --capture DOSSIER` enregistre des captures ; `-- --anim-sheet DOSSIER` produit les planches-contact des clips.

## Où lire quoi

| Document | Contenu |
| --- | --- |
| `docs/ARCHITECTURE.md` | Couches, dépendances autorisées, boucle à pas fixe, flux de données |
| `docs/DATA_FORMATS.md` | Schémas JSON (personnages, stats, morphologie, animations, paramètres, presets) et replis |
| `docs/GAMEPLAY_REFERENCE.md` | Règles retenues, machine d'actions prévue, modèle de contact |
| `docs/DECISIONS.md` | Décisions prises, avec date et raison |
| `docs/LESSONS_LEARNED.md` | Constats sur l'ancien projet et décisions qui en découlent |
| `docs/CODING_STANDARDS.md` | Conventions de code |
| `docs/ROADMAP.md` | Jalons J1 à J6 et état |
| `CLAUDE.md` | Règles permanentes pour les sessions de développement avec Claude |
