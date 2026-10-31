# Feuille de route MVP V1

Chaque jalon se termine par un rapport (objectif, fichiers, interfaces, tests et résultats réels, captures, risques)
et une validation de Djebril avant le suivant.

| Jalon | Contenu | Critères CDC | État |
| --- | --- | --- | --- |
| **J1 Fondation** | Projet, paramètres et presets, chargeurs JSON validés, objets typés, boucle à pas fixe, hasard à graine, scène de test, diagnostic, panneau minimal, tests, CI | 1, 12 (partiel), 14 (docs) | **Validé le 31/10/2026** |
| J2 Physique | Terrain, filet, collisions balayées, un joueur humain (course, saut, contact), entrées, réglages en direct | 5 (partiel), 11 (partiel) | **Validé le 31/10/2026** |
| J3 Gameplay 3v3 | Six joueurs, postes, IA de base, rallye, service, réception, passe, smash, feinte, contre, score | 2, 3, 4, 5, 11 | **Validé le 31/10/2026** |
| J4 Animation | Rig `Skeleton2D` partagé (17 os), 11 clips JSON (10 standards + marteau à deux mains), lecteur, fondus, repli, morphologie visuelle, mannequin anthracite, outils de debug | 6, 7, 8, 12 | **Livré le 31/10/2026, en attente de validation** |
| **J4.1a Service refondu** | Lancer contrôlé, prévisualisation de trajectoire, profondeur réglée par la direction tenue, IA qui lance et vise, correction du serveur figé | 2, 3 | **Principe validé en 3 étapes le 31/10/2026 ; étapes A, B et C livrées le 31/10/2026, en attente de validation (playtest)** |
| **J4.1 SJ1 Animations des services** | Trois gestes distincts (sol, flottant, smash), impulsion immédiate, intention de frappe partagée, atterrissages, outils de capture (planches, démo animée) | 6, 7 | **Livré le 31/10/2026 ; passe de correction gestuelle livrée, en attente de validation** |
| J4.1 SJ2 Effets et audio | Effets selon type, vitesse et qualité réelle ; système audio minimal (3 sons générés par code, remplaçables) | 6, 9 | à faire après validation du SJ1 |
| J4.1 SJ3 IA collective | Réception, attribution du ballon, passes exploitables, replacement, défense ; statistiques de playtest avant/après | 3 | à faire après le SJ2 |
| J4.1b à J4.1e | Retournement automatique, plongeon, IA alliée et adverse, animations énergiques (voir DECISIONS) | 2, 3, 6, 7 | à faire, dans cet ordre |
| J5 Lisibilité et sandbox | Traînée et prévision, caméra, panneau complet, presets, rapport de session, rejouer un rallye | 9, 10 | à faire |
| J6 Stabilisation | Tests complets, mesures de performance PC, guide de playtest, limites, backlog | 13 | à faire |

## Points ouverts (sans bloquer)

Formules de contre définitives (playtest), IA avancée, cibles de performance chiffrées, direction artistique,
mapping tactile (hors MVP).

## Cahier visuel du mannequin (reçu le 31/10/2026, réalisé au J4)

- Corps : gris anthracite mat, proportions humaines naturelles, silhouette sportive.
- Articulations (épaules, coudes, poignets, hanches, genoux, chevilles) légèrement marquées, sans effet robotique.
- Équipes : discret liseré bleu pour l'équipe du joueur, rouge pour l'adversaire.
- Animation : articulations pilotées par `Skeleton2D`/`Bone2D`, sans étirement artificiel des membres.
- Lisibilité : positions des bras et des jambes identifiables pendant smashs, contres et réceptions.
- Évolution : mannequin remplaçable par un personnage pixel art sans toucher à la simulation (le rendu ne lit que `MatchState`).

Écarts au cahier du mannequin, à valider : le plongeon n'est pas livré (hors MVP, décision Phase 0) ; la « préparation du saut » est portée par l'atterrissage (accroupi) et le début du clip de saut, car la simulation valide l'impulsion immédiatement : une flexion avant l'impulsion retarderait le visuel par rapport à la simulation.
