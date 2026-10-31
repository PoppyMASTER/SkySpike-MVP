# Décisions

Format : date — décision — raison. Les choix « tout comme recommandé » viennent de la Phase 0 validée.

| Date | Décision | Raison |
| --- | --- | --- |
| 31/10/2026 | Nouveau dépôt privé `PoppyMASTER/SkySpike-MVP` ; l'ancien `PoppyMASTER/Spike` n'est plus modifié et doit recevoir le tag `legacy-build-20` sur `5c3b1b7` | Repartir propre sans perdre l'ancien. Le tag n'a pas pu être créé depuis la session de Claude (accès refusé) : à créer à la main |
| 31/10/2026 | MVP sur PC (clavier + manette), rendu GL Compatibility | Mesures demandées sur PC ; garde Android possible |
| 31/10/2026 | Touches par défaut provisoires (voir GAMEPLAY_REFERENCE) | Jouable tout de suite, remplaçable |
| 31/10/2026 | Passe et réception sur deux touches, sans choix automatique | Lisible et exigeant |
| 31/10/2026 | Match : 1 set de 15 points, 2 d'écart, rotation attaquant → passeur → défenseur, touche de bloc non comptée | Matchs courts pour le playtest |
| 31/10/2026 | Pas de plongeon dans le MVP | Non obligatoire, complique les priorités |
| 31/10/2026 | Visuels du rig en formes simples | Juger l'animation avant le dessin |
| 31/10/2026 | Contact : fenêtre active + instant idéal + zone | Timing et position mesurés séparément |
| 31/10/2026 | Pas fixe 120 ticks/s par accumulateur maison (pas `_physics_process`) | Pause, pas à pas, ralenti pilotés par le panneau |
| 31/10/2026 | Intégration exacte à accélération constante (sans frottement) | Pas de dérive : même trajectoire quel que soit le pas |
| 31/10/2026 | Exécuteur de tests maison (`tests/run_tests.gd`), sans module externe | Moins de dépendances face aux versions de Godot |
| 31/10/2026 | Couche `scripts/app/` (écart à l'arborescence du CDC) | Point d'assemblage (`GameData`, `MatchRunner`, `main`) : évite que `gameplay` dépende du rendu |
| 31/10/2026 | `data` peut utiliser `characters` (écart à la table Phase 0) | Les chargeurs construisent les définitions typées |
| 31/10/2026 | Couche `debug` autorisée à utiliser `app` (API de contrôle de `MatchRunner`) ; `app` ne référence jamais `debug` | Pas de dépendance circulaire : les nœuds de debug sont placés dans `match.tscn` et trouvent le runner par `owner` |
| 31/10/2026 | Stats manquantes → gabarit de rôle (`stats/_role_<rôle>.json`) | Repli défini et visible plutôt que 0 ou 50 implicite |
| 31/10/2026 | J1 : « exercice de lancer » dans `MatchSim` (le ballon est relancé au hasard à chaque atterrissage) | Démontrer la boucle fixe et la reproductibilité avant les joueurs ; supprimé au J3 avec ses paramètres `drill_*` |
| 31/10/2026 | Rayon du ballon par défaut 0.105 m (réglementaire), gravité 10 m/s² | Valeurs de départ provisoires ; l'ancien jeu (0.12 m, 11 m/s²) reste comparable via `legacy_reference` |
| 31/10/2026 | J1 validé par Djebril (« c ok ») | Feu vert pour le J2 |
| 31/10/2026 | J2 : collisions balayées (segment départ → arrivée contre boîte du filet, coins arrondis), un seul impact par tick, reste du déplacement abandonné | Un ballon à 60 m/s ne traverse pas un filet de 10 cm, à 60, 120 et 240 Hz (test). Approximation : trajet droit sur un tick |
| 31/10/2026 | J2 : ordre d'un tick = ballon + filet → joueurs (mouvement, actions, contacts) → sol | Un contact qui relève le ballon annule l'atterrissage du même tick |
| 31/10/2026 | J2 : contact = le centre du ballon traverse la zone (segment du tick contre cercle) pendant la fenêtre active ; un contact par action | Pas de contact « automatique » ; le marqueur d'animation ne déclenche rien |
| 31/10/2026 | J2 : saut au sol, smash = 2e appui de saut en l'air (un seul par saut), réception = J au sol uniquement | Table de touches validée : `jump_attack` sert aux deux |
| 31/10/2026 | J2 : visée = axe horizontal tenu au contact (±`aim_range`), pas de mode assisté/manuel avant le J3 | Le choix du mode se fait dans l'écran de départ (J3) |
| 31/10/2026 | J2 : limites du joueur = filet (moitié d'épaisseur + `player_half_width`) et ligne de fond + `court_out_margin` ; terrain et filet appliqués au prochain match | Pas de collision joueur-filet par la morphologie (V1 : morphologie visuelle seulement) |
| 31/10/2026 | J2 : `InputLatch` entre images et ticks ; actions déclarées dans `InputMapper` (pas dans `project.godot`) | Aucun appui perdu ni doublé à 30/60/144 i/s ; touches provisoires faciles à changer |
| 31/10/2026 | J2 : touches de debug déplacées : P pause, N un tick, R relancer, F2 zones, F1 panneau | Espace devient le saut |
| 31/10/2026 | J2 : seules les actions utilisées existent (réception, smash) ; passe, service, feinte, bloc au J3 | Pas de code ni d'entrée « pour plus tard » |
| 31/10/2026 | Cahier visuel du mannequin reçu de Djebril (voir ROADMAP, J4) : gris anthracite mat, proportions naturelles, articulations marquées, liseré bleu (joueur) / rouge (adverse), `Skeleton2D`/`Bone2D` sans étirement, bras et jambes lisibles, remplaçable par du pixel art sans toucher à la simulation | À réaliser au J4 ; la silhouette rectangulaire du J2 est provisoire |
