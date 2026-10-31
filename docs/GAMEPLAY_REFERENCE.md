# Référence gameplay

Légende : **[Validé]** décision prise ; **[Prévu Jx]** pas encore implémenté ; **[Calibration]** valeur provisoire.

## Cadre [Validé]

- Volley 3 contre 3, vue de profil, filet en x = 0, sol en y = 0 (mètres, secondes).
- Le joueur choisit son poste (attaquant, passeur, défenseur) avant le match et ne contrôle que ce joueur.
- Déplacement horizontal uniquement ; saut vertical avec contrôle aérien réglable.
- Tous les rôles peuvent tout faire ; les stats et l'IA font la différence.
- Mode de visée `assisted` ou `manual`, choisi avant le match.
- Plateforme MVP : PC (clavier + manette). Pas de plongeon dans le MVP.

## Règles du match [Validé, Prévu J3]

1 set de 15 points, 2 points d'écart, un point par échange, l'équipe qui marque sert, rotation du serveur
attaquant → passeur → défenseur, service derrière la ligne, 3 touches par équipe (4e = faute),
double touche = faute, touche de bloc non comptée. Nombre de points réglable.

Phases : `READY → SERVE_PREP → BALL_LIVE → POINT_AWARDED → RESET → READY`.

## Touches par défaut [Validé, provisoire ; J2 : move, jump_attack et receive_block_feint implémentées]

| Action | Clavier | Manette |
| --- | --- | --- |
| `move_horizontal` | ← / → ou A / D | stick gauche |
| `jump_attack` | Espace | A |
| `receive_block_feint` | J | X |
| `set_action` | K | B |
| `serve_action` | L | Y |

En visée manuelle, la direction = l'axe horizontal au moment du contact. Passe et réception sont deux touches
distinctes, sans choix automatique.

Debug (depuis J2) : F1 panneau, F2 zones de contact, P pause, N un tick, R relancer (même graine). Clavier : ← → et Q/A/D (couvre QWERTY et AZERTY).

## Implémenté au J2 [Calibration pour toutes les valeurs]

États : `FREE`, `RECEIVE`, `AIR`, `SPIKE`, `RECOVER` (`Enums.ActionState`). Le reste de la machine arrive au J3.
- Saut : `jump_attack` au sol ; vitesse de décollage = √(2·g·apex), apex issu de la stat de saut. Contrôle aérien réglable.
- Smash : 2e appui de `jump_attack` en l'air, une fois par saut. Réception : `receive_block_feint` au sol.
- Contact : pendant la fenêtre `[on, off]` de l'action, si le segment parcouru par le ballon pendant le tick passe à moins de `rayon` du centre de la zone, un contact a lieu et ferme la fenêtre. Un contact par action.
- Qualité `q` et sortie : `ContactModel` (voir plus bas). Bruit d'angle = stat de précision, tiré dans le flux `contacts`.
- Événements : `ACTION_STARTED`, `CONTACT` (q, e_t, e_s, vitesse, angle), `ACTION_MISSED`, `PLAYER_JUMPED`, `PLAYER_LANDED`, `NET_HIT`.
- Filet : boîte de collision, rebond × `net_restitution`. Le joueur ne traverse pas le filet.

## Machine d'actions complète [Prévu J3]

États : `LOCKED`, `FREE`, `RECEIVE`, `SET`, `BLOCK_READY`, `AIR_ATTACK`, `SPIKE`, `FEINT`, `BLOCK_AIR`,
`LAND`, `RECOVER`, `SERVE_HOLD`, `SERVE_TOSS`, `SERVE_JUMP`, `SERVE_HIT`.
Un appui engage l'action ; le contact n'a lieu que si le ballon est atteignable pendant la fenêtre active.
Priorités selon sol / air / près du filet / service : tableau de la Phase 0 (section F), à recopier ici au J3.
Près du filet, ballon chez l'adversaire : maintenir `receive_block_feint` = posture de bloc ; le contre n'existe
qu'en saut de bloc, et sa qualité dépend du moment du saut.

## Modèle de contact [Validé, Prévu J2–J3]

Par action : fenêtre active `[t_on, t_off]`, instant idéal, zone circulaire dans le repère du joueur.
Qualité `q = clamp(1 − w_t·e_t² − w_s·e_s², 0, 1)` avec `e_t` = erreur de temps / tolérance, `e_s` = distance au
centre / rayon. Trop tôt = trajectoire plus haute et plus courte, trop tard = plus basse. Le mode assisté
multiplie les tolérances et corrige la direction dans une limite d'angle réglable.

## Service [Implémenté au J4.1a, étape A]

L sert de touche de passe en jeu et de touche de service pendant la tenue du ballon. Une seule logique de lancer et de contact produit
les trois services (au sol, flottant, smashé) ; seuls la hauteur du saut et le timing changent. Tous les seuils sont des paramètres du sandbox.

**Machine à états du lancer** (`ServeCharge`, front d'appui, annulation, relâchement) :
`SERVE_HOLD` (ballon tenu) ─ appui sur L ─► appui en cours ─ relâché avant `serve_tap_max_s` ─► **lancer bas** (`serve_toss_low_speed`, avance `serve_toss_forward_min`) ;
maintenu au-delà ─► **charge** (0 → 1 en `serve_charge_time`) ─ relâché ─► **lancer haut** (hauteur `serve_toss_speed` → `serve_toss_speed_max`, avance
`serve_toss_forward_min` → `serve_toss_forward`). K / B pendant l'appui = annulation (le ballon reste tenu, il faut un nouvel appui).
Un maintien sans front d'appui ne déclenche rien. Aucune direction à tenir.

**Après le lancer** (`SERVE_TOSS`) : le joueur reste libre (déplacement à `serve_toss_move_factor`, jamais devant la ligne de fond). Pendant
`serve_lockout_s`, les appuis de service sont ignorés (l'appui du lancer ne peut pas frapper). Ensuite :
- **L** : frappe **au sol** (fenêtre de contact ordinaire) ;
- **Espace** : saut, puis en l'air **Espace** (2e appui) ou **L** ouvrent la **même** fenêtre de contact (un seul déclenchement possible).
La frappe n'est jamais automatique : la simulation valide le contact selon la position du ballon, le timing et la qualité.

**Type de service** (`ContactResolver.serve_kind`, d'après la hauteur des pieds au contact, publié dans `CONTACT.serve_kind`) :
| Type | Condition | Vitesse maximale |
|---|---|---|
| au sol | pieds à moins de 5 % de la hauteur de saut | vitesse de service × `serve_ground_speed_mult` |
| flottant | saut inférieur à `serve_smash_jump_ratio` × hauteur de saut | vitesse de service |
| smashé | saut d'au moins `serve_smash_jump_ratio` × hauteur de saut | min(vitesse de service × `serve_smash_speed_mult`, **`serve_smash_speed_cap`**) |
Les vitesses de The Spike ne sont qu'une référence visuelle : le plafond du smash est configurable. La qualité (timing, placement) plafonne encore la vitesse.

**Visée** : en assisté, la direction tenue pendant la frappe règle la profondeur par la vitesse sur une trajectoire au-dessus du filet
(`assist_net_clearance`, de `assist_ratio_min` à `assist_ratio_max`). Manuel : angle seul (`aim_range`).

**Animation** (visuelle uniquement) : le geste suit l'intention de frappe annoncée par la simulation (`serve_intent`) ; le suivi et l'atterrissage suivent le
type réel au contact. Clips : `serve_prep_v1`, `serve_toss_v1`, `serve_jump_v1`, `serve_ground_v1`, `serve_float_v1`, `serve_smash_v1`, `land_float_v1`,
`land_smash_v1` (générés par `tools/gen_serve_clips.py`). Vérification : `-- --capture-service DOSSIER [--video]` puis `python3 tools/service_sheets.py DOSSIER`.

**IA** : mêmes commandes qu'un humain (`AiServe`) ; tirage par service (flux `ai`) : au sol avec `ai_serve_ground_chance` (appui bref, frappe au
passage dans la zone), sinon charge (`ai_serve_charge` ± `ai_serve_charge_spread`), saut sous le ballon et frappe. Elle lit son propre lancer, sans téléportation.

**Prévisualisation** (serveur humain, avancée en étape B) : points blancs = arc du lancer, qui grandit avec la charge ; barre jaune = charge ;
cercle = zone de frappe ; trajectoire après la frappe, atterrissage ± 1 écart-type. **Prévision de la balle** (tout joueur, permanente) : trajectoire
pâle, anneau d'atterrissage (vert dans les lignes, orange dehors, croix rouge au filet).

**Étape B** : la prévision montre départ, montée, sommet, descente et bande de frappe potentielle (réglages `preview_*`). Le serveur a des poses dédiées : attente, préparation (accroupi selon la charge), lancer, bras armé en l'air, frappe, suivi, atterrissage ; jambes de course quand il bouge.
**Étape C** : impact, traînée selon la vitesse, indicateur de vitesse (km/h), secousse de caméra mesurée ; réglages `fx_*` (groupe Affichage). Tout est visuel : aucun effet sur la physique.

## Contre [Prévu J3]

Écart = qualité de bloc − qualité d'attaque + biais : au-dessus de `seuil_contre` contre gagnant, entre les
seuils bloc partiel, en dessous le ballon passe. Chaque terme est publié dans l'événement `BLOCK_RESOLVED`.

## Implémenté au J3 [Calibration pour toutes les valeurs]

- **Match** : six joueurs (slots 0-2 bleus à gauche, 3-5 rouges à droite), un set de 15 points, 2 d'écart. Phases READY → SERVE_PREP → BALL_LIVE → POINT_AWARDED → RESET.
- **Postes** : attaquant, passeur, défenseur ; positions de départ `home_*_x`. Le service tourne attaquant → passeur → défenseur à chaque changement de service.
- **Arbitre** : 3 touches maximum par équipe, double touche = faute, 4e touche = faute, touche de bloc non comptée (et le contreur peut rejouer), ballon au sol hors terrain = faute de la dernière équipe qui l'a touché, service qui retombe sans avoir été frappé = faute de service.
- **Touches** : flèches / Q D déplacement, Espace saut puis smash, J réception (sol) ou contre (au filet) ou feinte (en l'air), L passe ou service (K en alias), maintenir L au service = charger le lancer ; manette : stick, A, X, B ou Y.
- **Visée** : assistée (défaut) ou manuelle (`aim_mode`, panneau F1). En assisté, l'angle est corrigé vers une cible, plafonné.
- **Contre** : attaque = vitesse et qualité du smash ; défense = stat × (timing, alignement, marge) ; issue = bloc écrasé, touche ou passage.
- **IA** : délai de réaction, erreurs de prédiction et de timing, plan selon le nombre de touches (réception, passe, attaque), tentative de contre, retour à la formation.
- **Mesure (12 matchs IA contre IA)** : tous terminés, ~27 points par match, ~3,4 contacts par point, ~270 s de jeu par match. Les valeurs sont des calibrations, pas des décisions.
