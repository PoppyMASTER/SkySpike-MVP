# SkySpike MVP V1

Sandbox de volleyball 2D 3 contre 3 (vue de profil), sous **Godot 4.7.2 / GDScript**.
Projet neuf, distinct de l'ancien SkySpike (archivé : dépôt `PoppyMASTER/Spike`, commit `5c3b1b7`).

**État : jalon J3 (gameplay 3v3).** Six silhouettes provisoires jouent un match complet de 15 points :
service, réception, passe, smash, feinte, contre, arbitre et score. Vous pilotez un joueur bleu (attaquant,
passeur ou défenseur, au choix dans F1) ; les cinq autres sont menés par l'IA. L'animation articulée arrive au J4.

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
Debug : **F1** panneau sandbox (joueur contrôlé, visée assistée/manuelle) · **F2** zones de contact · **P** pause · **N** un tick · **R** relancer.
Outils : `-- --sim N` joue N matchs IA contre IA et résume ; `-- --capture DOSSIER` enregistre des captures.

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
