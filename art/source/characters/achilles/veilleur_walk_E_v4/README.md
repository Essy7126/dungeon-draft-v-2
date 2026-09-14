# Veilleur — audit de la V3 et correction de marche V4

12 septembre 2026. Demande : « Fais un audit de ta propre marche et corriges ce qui ne va pas ».
Une seule marche, orientation E, sans équipement. Aucun autre personnage ou animation.

## Ce qui n’allait pas dans ma V3

1. **Volumes instables.** Le pantalon pouvait se raccourcir de moitié et la botte
   de 35 % sur son axe. J’avais contrôlé des bornes numériques trop permissives.
   Elles ne prouvaient pas la conservation visuelle du personnage.
2. **Anatomie et perspective confondues.** Je traitais la jambe lointaine déjà
   raccourcie dans le dessin comme une seconde anatomie plus courte. Cette erreur
   déséquilibrait l’alternance. Les repères estimés sur Nicolas ajoutaient encore
   des variations de longueur différentes de chaque côté.
3. **Mauvais ordre de superposition.** Trier les jambes par la hauteur de la
   semelle changeait deux fois leur ordre par cycle. Ce critère ne représentait
   pas leur profondeur par rapport au buste.
4. **Appuis compensés par tout le corps.** Le recalage déplaçait le corps sur
   15,37 px horizontalement et 19,40 px verticalement dans la cellule 512².
   Les points de semelle glissaient encore sur l’appui. Le contrôle par paire
   d’images minorait la perception de l’écart accumulé.
5. **Découpes et genoux.** Les bords des pièces, normalement cachés sous la main
   et la tunique, pouvaient réapparaître. Les bandes déformées pouvaient se replier
   sur elles-mêmes autour du genou, produisant des pointes et des raccords instables.
6. **Cadence recopiée sans adaptation.** Les 480 ms du GIF de Nicolas sont bien
   son délai encodé, mais ce délai ne suffisait pas à choisir notre cadence de marche.

Les contrôles d’export et de navigateur de la V3 étaient valides dans leur périmètre.
Ils ne validaient pas ces choix artistiques ou cette construction. Mon audit visuel
précédent était insuffisant sur les volumes et la profondeur.

## Correction réalisée

- Bottes d’origine en rotations/translations rigides, sans variation d’échelle.
  Aucune nouvelle peinture, aucun appel ImageGen. Costume et visage d’origine.
- Construction commune des jambes à partir du rapport cuisse/mollet de la jambe
  proche ; projection de profondeur à 0,95 pour la jambe lointaine. Sa hanche est
  replacée sous la tunique, 12 px plus haut dans la cellule. C’est une correction
  de construction, pas une promesse que toute longueur projetée égale l’ancien
  dessin de la jambe lointaine dans chacune des poses.
- Deux segments à longueurs constantes dans le plan du mouvement, projetés vers
  la diagonale du décor. Appui de 60 % du cycle, talon puis semelle puis pointe ;
  retour avec levée du pied. Les jambes rejoignent ces appuis sans déplacer tout
  le corps pour rattraper les erreurs.
- Ordre lointain/proche constant. Bandes du pantalon corrigées avant inversion de
  leurs triangles ; recouvrement par un petit élément du genou existant. Les
  pixels d’origine ne sont pas repeints. Une déformation 2D du tissu demeure.
- Balancement vertical de 3,20 px, horizontal de 1,60 px. Bras opposés aux jambes.
- 48 images pour 800 ms, pas plus court : 59,5 px horizontaux par cycle dans la
  cellule, contre 148,15 px pour la V3. Les bottes roulent sur un point d’appui ;
  leurs transitions vers le retour sont continues.

La V4 est une adaptation reconstruite des principes observés. Elle **n’est plus
un relevé image par image des poses du GIF**, ni le rig propriétaire de Nicolas.
La comparaison V3/V4 propose leurs cadences propres ou une phase alignée sur le
même pied. L’ancienne V3 et sa comparaison avec Nicolas restent accessibles.

## Contrôles et résultats

`audit_report.json` contient 15 contrôles :

- APNG et WebP : 48 images correspondant aux pixels visibles des PNG, total
  exact de 800 ms, délais alternés de 16/17 ms. Atlas identique aux 48 PNG.
- Les sept PNG source du gabarit accepté sont inchangés. Tous les cadres sont
  contenus dans la cellule ; ordre de profondeur constant.
- Longueurs des segments constantes dans le plan de construction, erreur
  numérique inférieure à 10⁻⁷ px. Les longueurs projetées à l’écran peuvent varier.
- Points d’appui talon, semelle à plat et pointe stables dans le monde à la
  précision numérique. Ces points restent des annotations.
- Contrôle supplémentaire sur **les PNG composités réels** : suivi du bout et
  de la semelle de la botte proche pendant 17 images d’appui à plat. Aucun décalage
  au pixel entier détecté après compensation du déplacement. Le premier patch,
  limité à un trait doré uniforme, était ambigu ; la zone finale inclut le contour
  courbe du bout de botte. Les résultats détaillés restent dans le rapport.
- Passage dernière → première image inférieur aux plus grands écarts internes
  pour les deux chevilles. Ce contrôle ne remplace pas l’examen du mouvement entier.

Un premier rendu trop accroupi a été écarté (`rejected_crouched_01.jpg`). La jambe
porteuse a ensuite été redressée. Le premier essai du contrôle de triangles avait
un signe d’orientation inversé : corrigé avant de produire un résultat.

La revue a passé **23 contrôles navigateur**, sans erreur JavaScript : 48 états
distincts et alignés, lecture/pause, cadence propre ou commune, curseur et boucle,
six combinaisons décor/version, ressources et affichages ordinateur/mobile.
Les captures du comparatif et des décors ont été inspectées. Rapport :
`verification.json`. Ce rapport valide le lecteur, pas la qualité artistique.

## Limites à garder visibles

- Les genoux gardent un aspect de découpe déformée à fort agrandissement. Les
  raccords sont plus stables, pas équivalents à des poses entièrement redessinées.
- Une seule vue peinte de chaque botte limite encore leur rotation en profondeur.
- Le suivi des pixels couvre la semelle proche à plat, pas toutes les surfaces
  de contact pendant le déroulé du talon et de la pointe.
- Aucun retour utilisateur ne valide encore artistiquement cette V4.
- La scène sur les trois décors est un photomontage. Aucune intégration native
  Godot, autre orientation, idle, transition ou équipement dans cette reprise.

## Fichiers

- Générateur : `tools/veilleur_walk/walk_v4_corrected.py` et source commune en
  lecture seule `tools/veilleur_walk/source_rig.py`.
- Mesures indépendantes : `tools/veilleur_walk/audit_walk_v4.py`.
- Sources de cette version : ce dossier, `motion.json`, `source_lock.json`.
- Sorties : `artifacts/spine_trial/veilleur_walk_E_v4/`, PNG, atlas, APNG, WebP,
  comparatif visuel, audit et revue.
- Revue : <http://127.0.0.1:8734/files/veilleur_walk_E_v4/review.html>.

Aucun code du moteur commun ni du parcours public modifié. Les tests natifs Godot
n’ont pas été relancés pour cette correction d’atelier.
