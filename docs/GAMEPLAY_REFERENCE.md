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

## Touches par défaut [Validé, provisoire, Prévu J2]

| Action | Clavier | Manette |
| --- | --- | --- |
| `move_horizontal` | ← / → ou A / D | stick gauche |
| `jump_attack` | Espace | A |
| `receive_block_feint` | J | X |
| `set_action` | K | B |
| `serve_action` | L | Y |

En visée manuelle, la direction = l'axe horizontal au moment du contact. Passe et réception sont deux touches
distinctes, sans choix automatique.

Debug (J1) : F1 panneau, Espace pause, N un tick. Les touches de debug seront déplacées au J2 pour libérer Espace.

## Machine d'actions [Prévu J2–J3]

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

## Contre [Prévu J3]

Écart = qualité de bloc − qualité d'attaque + biais : au-dessus de `seuil_contre` contre gagnant, entre les
seuils bloc partiel, en dessous le ballon passe. Chaque terme est publié dans l'événement `BLOCK_RESOLVED`.
