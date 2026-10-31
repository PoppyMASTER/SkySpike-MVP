# SkySpike MVP V1

Sandbox de volleyball 2D 3 contre 3 (vue de profil), sous **Godot 4.7.2 / GDScript**.
Projet neuf, distinct de l'ancien SkySpike (archivé : dépôt `PoppyMASTER/Spike`, commit `5c3b1b7`).

**État : jalon J1 (fondation).** Une scène de test fait rebondir un ballon à pas fixe ;
données, paramètres, presets, mesures et tests sont en place. Les joueurs arrivent au J2.

## Lancer

```bash
godot --path .                                   # ouvre la scène de test
godot --headless --path . --import               # (1re fois) importe le projet
godot --headless --path . -s tests/run_tests.gd  # tous les tests ; code de sortie 0 = OK
godot --headless --path . -s tests/run_tests.gd -- determinism   # filtre par nom de fichier
```

En jeu : **F1** panneau sandbox · **Espace** pause · **N** avance d'un tick.

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
