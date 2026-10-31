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
| 31/10/2026 | J2 validé implicitement par Djebril (passage au jalon suivant) | Feu vert pour le J3 |
| 31/10/2026 | Ordre des jalons : J3 = gameplay 3v3 (comme prévu), le cahier visuel du mannequin passe au J4 | Décision de Djebril ; le plongeon reste hors MVP tant qu'il ne décide pas autrement |
| 31/10/2026 | J3 : l'exercice de lancer du J1 et ses paramètres `drill_*` sont supprimés ; avec moins de six joueurs, `MatchSim` reste en « mode libre » (ballon en jeu, aucune règle, il repose au sol) | Les tests J2 à un joueur restent valables ; le match complet démarre à six joueurs |
| 31/10/2026 | J3 : phases READY → SERVE_PREP → BALL_LIVE → POINT_AWARDED → RESET → READY, plus MATCH_OVER | Le serveur est seul libre pendant SERVE_PREP ; les autres sont verrouillés à leur poste |
| 31/10/2026 | J3 : service = tenue, lancer, saut, frappe, avec fenêtre de contact comme les autres coups ; touche L (Y manette) | Service lisible et exigeant ; pas de service automatique |
| 31/10/2026 | J3 : un contact est validé au point de rapprochement maximal du ballon dans la zone (pas au bord de la zone) | Sinon le contact se produisait au bord avec une qualité faible, et la qualité ne mesurait plus le placement |
| 31/10/2026 | J3 : visée assistée par défaut (`aim_mode`), manuelle au choix ; l'IA utilise toujours la même fonction d'angle, avec une correction plafonnée (`ai_assist_max_angle`) | L'IA n'a aucun pouvoir spécial : mêmes intentions, mêmes contacts, mêmes erreurs de timing |
| 31/10/2026 | J3 : contre = comparaison attaque / défense (`BlockResolver`) ; trois issues : bloc écrasé (stuff), touche, passage ; BLOCK_RESOLVED publie tous les termes | Formules provisoires, à calibrer au playtest |
| 31/10/2026 | J3 : vitesses de service 9–17 m/s (au lieu de 12–22) et angle de franchissement du filet (`assist_net_clearance`) | L'IA servait dans le filet ou trop long à plus haute vitesse |
| 31/10/2026 | J3 : tampon d'entrée avant action (buffer) reporté | Pas nécessaire pour valider les règles ; à revoir au ressenti de Djebril |
| 31/10/2026 | J3 : IA = lecture de `MatchState` avec délai de réaction, erreurs de prédiction et de timing retirées à chaque nouveau contact, mêmes `PlayerIntent` que l'humain | Déterministe (flux `ai` de `MatchRng`) et sans accès aux données cachées |
| 31/10/2026 | J3 validé implicitement par Djebril (« part sur J4 ») | Feu vert pour le J4 |
| 31/10/2026 | J4 : l'animation est une fonction pure de l'état de simulation (action, temps d'action, instant idéal, vitesse, position, tick), jamais du temps réel ; la couche `animation` reçoit les mêmes interdits que la simulation | Indépendance du FPS, pause et ralenti cohérents, impossible de décaler un contact par l'animation |
| 31/10/2026 | J4 : le repère `impact` d'un clip est calé sur l'instant idéal de l'action (domaine `window`) ; il ne déclenche jamais de contact | Le visuel accompagne le contact sans le décider ; les contacts restent déterminés par la simulation |
| 31/10/2026 | J4 : `PlayerSnapshot` expose `action_ideal` et `action_length`, `MatchState` expose `tick_seconds` | Le rendu a besoin de ces valeurs pour caler l'animation ; lecture seule, hors empreinte de déterminisme |
| 31/10/2026 | J4 : rig = `Skeleton2D` + 17 `Bone2D` + pièces rigides `Polygon2D` (pas de maillage déformé) ; liseré d'équipe = silhouette agrandie derrière le corps | Liseré discret autour de la silhouette seulement, corps jamais coloré ; remplaçable par des sprites en réécrivant `_build_pieces` |
| 31/10/2026 | J4 : au sol, le rig est décalé verticalement pour poser les semelles (cinématique directe) ; le corps physique ne change pas | Genoux fléchis sans flotter ni s'enfoncer, sans écrire de décalage dans chaque clip |
| 31/10/2026 | J4 : jambes reprises du saut quand le joueur est en l'air pendant une passe, un contre ou un service (`air_legs`) | Une seule animation de bras par action, pas de variantes sol / air à maintenir |
| 31/10/2026 | J4 : 11 clips (10 standards + `hammer_spike_v1`), poses en radians absolus, sens de Godot ; clip invalide → repli journalisé, jamais de plantage | Contrat de Phase 0 respecté ; `foot_lock` accepté mais ignoré en V1 |
| 31/10/2026 | J4 : plongeon non livré ; préparation du saut portée par l'atterrissage et le début du saut | Plongeon hors MVP (Phase 0) ; la simulation valide l'impulsion tout de suite, une flexion préalable décalerait le visuel (à valider par Djebril) |
| 31/10/2026 | J4 : vitesse d'animation = réglage de la vue (`anim_speed`, `preview_speed`), jamais `time_scale` | Régler une animation ne peut pas modifier la vitesse de la simulation |
| 31/10/2026 | J4.1 (décision de Djebril) : ordre = gameplay d'abord (service, retournement, plongeon, IA, animations) puis graphismes (pilote détaillé, 100 px/m configurable) | Chaque sous-jalon est validé avant le suivant ; ne rien reconstruire de ce qui fonctionne |
| 31/10/2026 | J4.1 : le **plongeon fait désormais partie du MVP** (annule la décision de Phase 0) ; touche dédiée Maj gauche / RB, soumis à la physique, au timing et à un temps de récupération ; remappage des commandes à prévoir | Livré au J4.1c |
| 31/10/2026 | J4.1 : retournement = séparation `attack_dir` (sens vers le camp adverse, fixe, direction de sortie par défaut) et orientation visuelle du corps ; le retournement ne change ni coordonnées physiques ni sens des contacts, et ne doit pas empêcher passes arrière, feintes ou attaques dirigées | Livré au J4.1b |
| 31/10/2026 | J4.1 : **aucune anticipation physique ajoutée au saut** (l'impulsion est immédiate à la validation de la commande) ; l'énergie vient de l'animation (compression, extension, atterrissage). Un paramètre d'anticipation physique, à 0 par défaut, pourra être préparé plus tard sans être utilisé | Livré au J4.1e |
| 31/10/2026 | J4.1a (révisé le 31/10 après retour de Djebril) : **L = passe en jeu, service pendant la tenue du ballon** ; maintenir L charge le lancer (plus on tient, plus le ballon monte : `serve_toss_speed` → `serve_toss_speed_max` en `serve_charge_time`), relâcher le lance sur une courbe de base vers le filet (`serve_toss_forward`), aucune direction à tenir ; **le saut est obligatoire** (Espace) puis L frappe en l'air ; plus de frappe au sol | Remplace la dérive pilotée par la direction ; K reste un alias de passe, B/Y manette |
| 31/10/2026 | J4.1a : le serveur peut se replacer sous le ballon pendant le lancer (`serve_toss_move_factor`) mais reste derrière la ligne de fond | Le placement fait partie du service |
| 31/10/2026 | J4.1a : en visée assistée, la direction tenue à la frappe règle la profondeur par la VITESSE sur une trajectoire qui passe au-dessus du filet et retombe sur la cible (`ContactResolver._serve_arc`, `Ballistics.through_two_points`) ; la qualité plafonne la vitesse | L'ancienne règle (angle seulement) donnait toujours le même service, car le filet imposait l'angle |
| 31/10/2026 | J4.1a : prévisualisation du service (`ServePreview`) calculée par la simulation avec `BallBody.step` et `ContactResolver.plan_contact`, la formule du vrai contact, sans bruit ; affichée seulement pour le serveur humain ; hors empreinte de déterminisme | Une prévision qui ment serait pire que pas de prévision ; elle est testée contre le service réel |
| 31/10/2026 | J4.1a : l'IA charge, lance, saute et frappe comme un humain (`AiServe`) (direction de lancer et de frappe tirées dans le flux `ai`, `ai_serve_toss_spread`, `ai_serve_aim_spread`) et lit son propre lancer sans délai ni erreur de perception | Services variés, 0 faute de service sur 12 matchs |
| 31/10/2026 | J4.1a : correction d'un blocage préexistant : un serveur qui ratait sa frappe restait figé dans son geste et la partie ne reprenait jamais (`lock_to` le remet libre) | Jamais vu avec l'IA avant ce jalon ; atteignable par un humain |
| 31/10/2026 | J4.1a : prévision permanente de la balle (`BallPrediction`, formule fermée, points pâles et anneau d'atterrissage vert / orange / croix au filet), publiée dans `MatchState.ball_prediction` dès que le ballon n'est plus tenu ; hors empreinte | Demande de Djebril : voir en tout temps où la balle retombe |
| 31/10/2026 | J4.1a : `player_actor.gd` à ~315 lignes : revu, la charge du lancer est déjà extraite (`ServeCharge`), le reste est la machine d'états | Seuil de revue, pas limite ; à rediscuter au J4.1c (plongeon) |
