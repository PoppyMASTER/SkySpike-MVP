# Enseignements de l'ancien projet

Source : *Audit technique SkySpike (Godot)*, 30/10/2026, dépôt `PoppyMASTER/Spike`, commit `5c3b1b7` (build 20).
Légende : **Constat** = fait vérifié dans l'ancien code ; **Décision** = ce que fait le MVP (validé en Phase 0 le 31/10/2026).

| # | Constat | Conséquence observée | Décision MVP |
| --- | --- | --- | --- |
| 1 | `game.gd` (1 525 lignes) regroupe règles, physique, IA, caméra, effets, réseau | Impossible de modifier un domaine sans toucher les autres ; rendu couplé aux détails internes | Couches séparées avec dépendances vérifiées par test (`ARCHITECTURE.md`) |
| 2 | Simulation appelée depuis `_process` avec sous-pas variables (≤ 6 ms) | Résultats dépendants du FPS | `SimClock` à pas fixe, `dt` jamais modifié ; test de déterminisme multi-FPS |
| 3 | `randomize()` + 40 appels au hasard dispersés | Échanges non rejouables | `MatchRng` à graine, flux séparés, tirages étiquetés |
| 4 | Ralenti et arrêt sur image modifiaient `dt` de la simulation | Les effets changeaient la physique | Ralenti = moins de ticks par seconde réelle ; effets côté rendu (J5) |
| 5 | Fiches JSON lues comme dictionnaires partout, sans validation | Fautes de frappe silencieuses | Chargeurs + `SchemaReader` → objets typés, `LoadIssue` lisibles, replis définis |
| 6 | Valeurs magiques dans les formules | Calibrage par modification du code | `ParamStore` unique, presets, panneau sandbox ; `legacy_reference` pour comparer |
| 7 | Trajectoires « visées » vers un point (`launch_t`) | Frappes peu interprétables physiquement | Vitesse initiale + gravité ; le solveur balistique sert seulement à l'assistance et à l'IA (J2–J3) |
| 8 | Zones de contact logiques séparées du dessin | Point fort | Conservé : zones dans les paramètres, jamais déduites des os |
| 9 | Contact déclenché au premier tick où le ballon entre dans la zone après l'appui | Appuyer tôt donnait une touche au bord (peu intuitif) | Fenêtre active + instant idéal + erreurs de temps et de position séparées (J2–J3) |
| 10 | Squelette procédural de 10 points, sans `Skeleton2D` | Rendu « formes simples » | `Skeleton2D` dès la V1, IK maison, clips JSON (J4) |
| 11 | Aucune mesure de performance enregistrée ; `t_draw`/`t_pose` jamais affichés | Pas de base de comparaison | Métriques dans le diagnostic dès J1 (FPS, µs/tick, ticks abandonnés) |
| 12 | États et poses en chaînes | Erreurs de frappe non détectées | `enum` typés |
| 13 | Instantanés réseau sérialisables | Point fort | `MatchState` copiable avec empreinte exacte ; base des tests et des replays |

## Valeurs historiques

Documentées dans `data/presets/legacy_reference.json` (références de comparaison, pas des valeurs par défaut) :
gravité ballon 11 m/s², rayon 0.12 m, vitesse joueur 3.6–7.8 m/s, apogée du saut 1.45–2.2 m,
smash 30–45 m/s, service 9.5–24 m/s. Autres valeurs relevées (pas encore de paramètre équivalent) :
gravité joueur 15 m/s² (× 0.55 près de l'apogée), filet 2.43 m, portée bras levés 1.55 m, fenêtre d'action 0.24 s,
rayons de zones 0.58–0.75 m, accélération au sol 48 m/s², contrôle aérien 18 m/s².
