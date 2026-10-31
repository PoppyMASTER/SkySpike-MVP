# Feuille de route MVP V1

Chaque jalon se termine par un rapport (objectif, fichiers, interfaces, tests et résultats réels, captures, risques)
et une validation de Djebril avant le suivant.

| Jalon | Contenu | Critères CDC | État |
| --- | --- | --- | --- |
| **J1 Fondation** | Projet, paramètres et presets, chargeurs JSON validés, objets typés, boucle à pas fixe, hasard à graine, scène de test, diagnostic, panneau minimal, tests, CI | 1, 12 (partiel), 14 (docs) | **Validé le 31/10/2026** |
| J2 Physique | Terrain, filet, collisions balayées, un joueur humain (course, saut, contact), entrées, réglages en direct | 5 (partiel), 11 (partiel) | **Livré le 31/10/2026, en attente de validation** |
| J3 Gameplay 3v3 | Six joueurs, postes, IA de base, rallye, service, réception, passe, smash, feinte, contre, score | 2, 3, 4, 5, 11 | à faire |
| J4 Animation | Rig `Skeleton2D` partagé, 10 clips standards, lecteur JSON, fallback, marteau à deux mains, morphologies | 6, 7, 8, 12 | à faire |
| J5 Lisibilité et sandbox | Traînée et prévision, caméra, panneau complet, presets, rapport de session, rejouer un rallye | 9, 10 | à faire |
| J6 Stabilisation | Tests complets, mesures de performance PC, guide de playtest, limites, backlog | 13 | à faire |

## Points ouverts (sans bloquer)

Formules de contre définitives (playtest), IA avancée, cibles de performance chiffrées, direction artistique,
mapping tactile (hors MVP).

## Cahier visuel du mannequin (reçu le 31/10/2026, à réaliser au J4)

- Corps : gris anthracite mat, proportions humaines naturelles, silhouette sportive.
- Articulations (épaules, coudes, poignets, hanches, genoux, chevilles) légèrement marquées, sans effet robotique.
- Équipes : discret liseré bleu pour l'équipe du joueur, rouge pour l'adversaire.
- Animation : articulations pilotées par `Skeleton2D`/`Bone2D`, sans étirement artificiel des membres.
- Lisibilité : positions des bras et des jambes identifiables pendant smashs, contres et réceptions.
- Évolution : mannequin remplaçable par un personnage pixel art sans toucher à la simulation (le rendu ne lit que `MatchState`).
