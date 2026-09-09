# Production de sprites — recommandation après examen des réalisations

Date : 9 septembre 2026. Recherche initiale, puis mise en œuvre d'un atelier
de clips Godot. [Guide de production et commandes](../../tools/sprite_workshop/README.md).
Les exemples importent des dessins existants ; aucune nouvelle animation
artistique finale ni comparaison Blender/Spine n'est revendiquée.

## Décision proposée

Consolider la chaîne déjà utilisée pour Achille : références visuelles stables,
dessins de poses, sélection et corrections ciblées, assemblage reproductible,
chronologie de jeu et revue en combat. Créer un petit atelier de clips et de
comparaison autour des outils existants.

Cette recommandation remplace les priorités successives données à Spine puis
à Blender 2D dans les versions précédentes de ce document. Elles reposaient sur
les possibilités des outils et leur pilotage, sans comparaison artistique locale.
Le contrôle par code ne démontre pas un meilleur mouvement.

## Éléments vérifiés dans notre projet

- La ruée d'Achille utilise quatre dessins. La pose aérienne est maintenue pendant
  le déplacement réel ; la réception commence à l'arrivée. Le moteur reste
  responsable de la translation. Sources : `tools/achilles_kit_sprite_pipeline/build.cjs`
  et `characters/achilles/2d/achilles_sprite_2d_backend.gd`.
- Le kit v2 conserve les dessins, prompts, substitutions et motifs de rejet.
  Une pose de tir perdant le bouclier a été remplacée par une pose compatible
  déjà disponible. Voir `art/source/characters/achilles/sprites_kit_v2/README.md`.
- Le polish v3 prend le sprite de repos original comme autorité visuelle. Des
  candidats élargissaient le corps ; une autre marche répétait le même appui.
  Seules les parties utiles ont été retenues. La ruée appréciée par l'utilisateur
  a été conservée. Voir `art/source/characters/achilles/sprites_polish_v3/README.md`
  et `tools/achilles_polish_v3_pipeline/README.md`.
- Le pipeline des monstres possède déjà découpe en pièces, pivots et IK. Un
  remplacement de logiciel conserverait le besoin de travailler les poses,
  l'anatomie, les parties cachées et le rythme.
- Le retarget 3D d'Achille est décrit comme un prototype structurel avec des
  corrections artistiques restantes dans `tools/blender/achilles_animation_pool/README.md`.

La planche `assets/characters/Achilles/sprites_kit_v2/preview_base_E_light.jpg`
a été examinée : sa première rangée correspond aux quatre poses de ruée.
Les lectures de code et documents ne constituent pas une nouvelle exécution des
anciens tests ni une comparaison animée Blender/Spine/sprites dans cette analyse.

## Ce que les recherches permettent de conclure

Le cut-out anime les mêmes pièces déplacées ou déformées. Il peut faciliter
la réutilisation, mais les poses et dessins restent à construire. La 2D réduit
certains problèmes de volume, caméra et retarget ; elle ne résout pas à elle
seule les difficultés de conception d'un mouvement.

Spine documente le remplacement des images pour les changements de perspective.
Son exemple Alien combine des dessins image par image et des déformations. Cela
illustre une méthode hybride ; ce n'est pas une preuve qu'un rig transformera
nos dessins actuels en animations finales sans travail supplémentaire.

Krita documente une animation raster fondée sur les poses importantes puis les
intermédiaires, avec timeline, images voisines en transparence et durées de maintien.
Aseprite propose également ces outils de revue/édition et l'export PNG/JSON.
Ces fonctions organisent le travail ; elles ne garantissent pas l'anatomie ou
la cohérence de dessins générés.

## Chaîne de production simple

1. Fixer la référence du personnage dans chaque direction : proportions,
   silhouette, palette, équipement et main porteuse. Réutiliser l'image approuvée
   comme référence des nouvelles corrections ; un prompt textuel ne suffit pas
   à garantir la continuité.
2. Définir l'action par quelques poses et sa chronologie. La ruée existante sert
   de référence de production. Le nombre de dessins dépend du geste : quatre
   dessins adaptés à une ruée ne constituent pas un standard pour une marche.
3. Produire des candidats à partir de cette référence. Vérifier d'abord les poses
   décisives et la silhouette à taille de jeu, puis compléter les intermédiaires.
4. Conserver les poses acceptées et corriger seulement les poses ou détails
   défectueux. Les répétitions de génération ne constituent pas une garantie ;
   fixer un budget d'essais et identifier les dessins qui nécessitent une retouche.
5. Assembler avec les scripts existants : échelle physique cohérente, ancre au
   sol revue, durées par image, sources et variantes explicites. Ne pas ajuster
   automatiquement l'échelle à la hauteur de chaque pose.
6. Exporter atlas, SpriteFrames et données temporelles compatibles, puis vérifier
   le résultat dans le lecteur du jeu et en combat.

Chaque direction possède ses dessins. Préserver l'équipement et ses côtés
anatomiques. Les poses d'un même personnage ne doivent pas être réinventées
entièrement à chaque nouvelle action.

## Outil à créer en priorité

Un atelier léger de clips dans Godot, avec les mêmes services accessibles par
commande. Son périmètre initial est limité :

- afficher la référence, le clip courant et le candidat côte à côte ;
- afficher les images précédente et suivante en transparence ;
- choisir, remplacer et réordonner les images d'un clip ;
- corriger les ancres et durées, avec les marqueurs de départ/impact/arrivée ;
- lire aux durées réelles et à taille de jeu, puis comparer avant/après ;
- conserver le manifeste des sources, les décisions et les exports reproductibles.

Réutiliser les lecteurs de revue, alignements, substitutions, assembleurs et
harness de combat présents. Le panneau sert à rendre ces corrections accessibles
et inspectables. Son fonctionnement ne nécessite pas un nouvel éditeur de rig.

Les sorties des commandes doivent rester compactes : modifications, alertes,
chemins des aperçus et logs détaillés. Recalculer seulement le clip affecté.

## Place des autres outils

| Outil | Cas où l'évaluer |
| --- | --- |
| Blender 2D | Un besoin précis de déformation ou réutilisation que notre chaîne actuelle traite mal ; mesurer le gain sur ce cas |
| Spine | Beaucoup de variantes partageant une morphologie, mouvements articulés réutilisables ou éléments secondaires ; vérifier le coût de préparation et correction |
| Aseprite | Retouches et revue image par image ; particulièrement adapté au pixel art |
| Krita | Retouches dessinées et animation raster pour les sources peintes |

Aucun achat ou changement de chaîne n'est requis par cette recommandation.
L'ajout d'un logiciel doit répondre à un besoin constaté. Les fonctions de Blender
ou Spine ne prouvent pas à elles seules une amélioration du rendu.

## Premier exercice et critères d'acceptation

Conserver la ruée d'Achille comme référence positive. Choisir un clip actuellement
insatisfaisant, par exemple l'attaque de la Sentinelle en E, et le corriger avec
la chaîne existante. Comparer la cohérence du personnage, la lisibilité du geste,
les appuis, le rythme et le nombre de corrections nécessaires. Étendre aux autres
directions après ce résultat.

Contrôles automatiques : fichiers présents, absence de découpage involontaire,
régions d'atlas fidèles, sources traçables, événements uniques et comportement
correct dans le moteur. Les coordonnées alpha ne prouvent pas un bon appui,
et un test technique réussi ne certifie pas une animation finale.

Contrôles visuels : identité et équipement stables, poses compréhensibles,
absence de glissement injustifié, transitions acceptables et lecture à taille jeu.
Une méthode n'est adoptée que sur ses résultats, pas sur le nombre d'outils ajoutés.

## Sources primaires consultées

- [Godot : cut-out et animation par dessins](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html).
- [Spine : remplacement d'images, déformations et réutilisation](https://esotericsoftware.com/spine-demos).
- [Spine : exemple Alien, dessins et déformations combinés](https://en.esotericsoftware.com/spine-examples-alien).
- [Krita : workflow d'animation raster](https://docs.krita.org/en/user_manual/animation.html).
- [Aseprite : fonctions d'animation et export](https://www.aseprite.org/).
- [Blender : possibilités de l'API Python](https://docs.blender.org/api/main/info_quickstart.html).
