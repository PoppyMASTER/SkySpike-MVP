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
