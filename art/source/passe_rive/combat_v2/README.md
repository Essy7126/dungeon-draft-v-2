# Passe-rive — poses de combat v2

Huit planches dessinées avec l’outil intégré `image_gen.imagegen` le 13 septembre
2026, en référence au personnage fourni par l’utilisateur. Tous les prompts et les
fichiers retenus sont consignés dans `generation.json`. Aucun miroir logiciel.

Les sources sont RGB, sur fond magenta opaque. Elles ne sont pas des sprites
prêts à importer ; `.gdignore` les exclut du moteur. Après deux essais de
transparence ayant produit un faux damier, l’utilisateur a explicitement répondu :
« Oui, utilise un script pour préparer les sprites ».

`tools/passe_rive_autosprite/build_combat_v2.py` effectue le détourage, retire le
magenta des bordures, conserve les cordes d’arc et sépare les composantes de
chaque personnage. Le découpage suit les silhouettes, car certaines pointes
dépassent la grille de la planche. Une échelle constante par direction évite de
redimensionner le personnage entre deux poses. Les appuis sont fixés à (192, 330)
sur des canevas de 384 × 384 ; l’élévation du saut est inscrite dans les dessins.

Les sorties runtime sont dans `assets/characters/PasseRive/combat_v2/` : huit atlas
RGBA de 1536 × 1536, `sprite_frames.tres` et `manifest.json`. Ce dernier contient les
SHA-256, les translations, les appuis et les contrôles de cadrage des 128 dessins.
Les 66 planches originales du lot `autosprite_v1` sont conservées sans retouche.

Ordre des 16 poses par direction, de gauche à droite puis de haut en bas :

| Index | Pose |
|---|---|
| 0 | Attente armée |
| 1–3 | Mise en tension, visée, lâcher rapide |
| 4–7 | Préparation basse, tension, maintien, lâcher chargé |
| 8–11 | Impulsion, envol, visée au sommet, lâcher aérien |
| 12–14 | Descente, réception, redressement |
| 15 | Seconde pose de repos dessinée, réservée |

Les trois tirs reviennent exactement à la pose 0 pour raccorder l’attente armée.
L’attente est une pose tenue, pas une nouvelle boucle de respiration. Il s’agit
d’une première version intégrée : les directions E/W restent proches d’une vue
trois quarts et les intervalles dessinés sont moins nombreux que dans les cycles
originaux. Une animation aussi souple que la référence Dofus demanderait encore
des dessins intermédiaires et une harmonisation artistique des huit directions.
