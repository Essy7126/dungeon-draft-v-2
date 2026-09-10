# Passe-rive : reconstruire la marche avant de finir les sprites

La V1 ne constitue pas une marche validée. Les dessins conservent assez bien le
personnage, mais les appuis ne progressent pas comme le déplacement le demande.
Le défaut vient aussi du guide et de l'ordre de fabrication. Une meilleure
résolution, un détourage propre ou davantage d'images ne corrigent pas ces erreurs.

[Comparaison visuelle et mesures](http://127.0.0.1:8734/files/passe_rive_walk_audit/review.html).
Base Git vérifiée : `2473c335`, travail local du 10 septembre 2026. Les huit
dessins originaux restent conservés dans `passe_rive_motion_v1`.

## Ce qui est effectivement mesuré

Un rapprochement de texture suit une zone de l'avant-pied dans les trois premiers
PNG natifs. Il cherche une translation dans une fenêtre bornée, sur 615 points
opaques de la zone 92 × 65 pixels. L'examen des agrandissements confirme que le
dessin 2 reprend pratiquement le même pied avant que le dessin 1.

| Comparaison | Translation observée, pixels natifs | Translation attendue avec le réglage actuel | Écart après déplacement, à une hauteur de corps de 220 px |
|---|---:|---:|---:|
| Dessin 1 → 2 | (+1, −2) | (−56, −28) | environ 10 px |
| Dessin 1 → 3 | (−57, +3) | (−112, −56) | environ 13 px |

L'appui doit reculer dans l'image d'un personnage qui marche sur place, afin de
compenser l'avancée du personnage dans le monde. Dans notre première comparaison,
il reste presque immobile dans l'image. Dans la suivante, il recule surtout
horizontalement, au lieu de suivre la diagonale du déplacement.

Ces valeurs dépendent de la vitesse et de l'échelle illustratives de la revue.
Elles ne mesurent pas la vitesse d'Achille dans le jeu. Le rapprochement de
texture suppose une translation ; il ne suit pas toute l'anatomie et ne permet
pas de certifier les huit poses. Les PNG, empreintes, fenêtre de recherche et
résultats sont consignés dans `artifacts/spine_trial/passe_rive_walk_audit/audit.json`.

Le guide contient deux problèmes supplémentaires vérifiables dans ses coordonnées :

- Aux poses 3 et 7, nommées « passage », la cheville libre est encore **19,3 cm
  derrière** la cheville porteuse sur l'axe avant. Le véritable passage se
  produit entre les images sélectionnées. Les intitulés ont donc donné une
  consigne trompeuse au générateur.
- À ces mêmes instants, le bassin se décale de **1,8 cm vers le côté opposé** au
  pied porteur. Cette oscillation a été écrite avec le mauvais signe pour
  l'intention de transfert latéral. Le bassin n'est pas le centre de masse :
  ce constat ne remplace pas une analyse dynamique du corps entier.

Les vérifications précédentes portaient sur les longueurs de membres, le sol et
la boucle. Elles restent vraies, mais étaient insuffisantes pour qualifier le
guide de bonne référence de marche. Le pied du guide ne développe d'ailleurs
pas encore une attaque du talon puis un déroulé de semelle convaincants.

La V1 expose aussi chaque dessin pendant 140 ms. Avec son réglage actuel, le
personnage avance d'environ 10 pixels à la taille testée pendant cette tenue.
Une animation de sprites assume une certaine discrétisation ; il faut juger
cette cadence à l'écran, sans exiger une immobilité mathématique à chaque
instant. Cela ne justifie pas les mauvais déplacements entre les poses clés.

## Ce que les références professionnelles apportent

**Marche : Jason Martinsen / Animation Mentor.** Son cours construit contacts,
absorption, passage et remontée, examine les vues de côté et de face, puis règle
les courbes, le bassin, le buste et les pieds. La translation des pieds pendant
l'appui reste linéaire pour éviter le glissement. Pour Passe-rive : sélectionner
les poses d'après ces événements, avec une marche complète en référence, et
valider aussi le déplacement dans l'espace. Le cours utilise Maya ; le principe
se transpose à Blender. [Cours du 7 juillet 2025](https://www.animationmentor.com/blog/tutorial-animating-human-walk-cycle/).

**Dead Cells : Thomas Vasseur, artiste du jeu.** Il décrit une fiche 2D, un modèle
3D simple, des poses clés testées pour leur mouvement et leur timing, puis des
rendus PNG. L'intérêt est de pouvoir corriger et réexporter une animation sans
redessiner tout le personnage. Son traitement des attaques est volontairement
pose par pose ; ce n'est pas une règle imposant de supprimer les passages d'une
marche. Son personnage est beaucoup plus petit à l'écran que notre essai : copier
son rendu pixelisé ne garantirait pas notre style peint. Le principe utile est
une source animée éditable commune à tous les dessins.
[Retour de production, 25 janvier 2018](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-).

**Skullgirls : Mariel Cartwright, responsable de l'animation.** La conférence GDC
2014 présente un parcours brouillon → jeu → finition → jeu. Elle montre notamment
Filia : une séquence de 21 images perd six images et gagne en force grâce à des
poses mieux mises en valeur. Les silhouettes, les durées et le mouvement qui
continue après l'action comptent plus que la quantité d'intervalles. C'est aussi
une référence pour nos futures actions spectaculaires : anticipation, pose
d'impact et déformations expressives doivent être choisies, sans être confondues
avec des erreurs aléatoires d'anatomie.
[Conférence, pages 6, 17, 19 et 30–33](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf).

**DOFUS : Julien Druant.** Son portfolio montre des personnages, monstres et FX
réalisés sous Flash. C'est un exemple directement pertinent pour étudier la
lisibilité des silhouettes et les mouvements dessinés. La source date de 2017 :
elle ne démontre pas comment toute l'animation de DOFUS Unity est produite
aujourd'hui. Notre appréciation de son style ne justifie pas d'inventer sa
pipeline actuelle. [Portfolio de l'animateur](https://www.behance.net/gallery/55592215/DOFUS-CHARACTER-ANIMATION).

**Hades : Supergiant.** Le studio annonce en janvier 2019 avoir retouché des
milliers d'images du protagoniste pour les rapprocher du style du jeu. Ce retour
montre que la cohérence artistique est un travail de finition à part entière,
même quand les animations existent. Cette annonce ne détaille pas son rig.
[The Chaos Update](https://www.supergiantgames.com/blog/hades-the-chaos-update-is-now-available/).

## Méthode à retenir pour Passe-rive

Le mix reste une piste crédible, mais il doit transmettre **une séquence de
mouvement imposée**, pas seulement montrer un squelette à un générateur qui
réinvente chaque image séparément. Son succès sur notre personnage reste à
démontrer. La V1 a prouvé la création de dessins reconnaissables, pas cette
transmission temporelle.

1. **Construire un brouillon animé lisible.** Utiliser une marche complète de
   référence, la caméra trois-quarts du jeu et un mannequin aux proportions de
   Passe-rive. Fixer lance et bouclier aux mains. Corriger contacts, passage,
   déroulé des pieds et bassin avant les tissus. Garder les deux jambes de
   couleurs différentes dans ce brouillon, pour suivre leur identité.
2. **Tester les événements, pas huit étiquettes.** Examiner deux contacts
   opposés, deux absorptions, deux passages réels et deux remontées. Les instants
   ne sont pas obligatoirement répartis à intervalles égaux. Les jambes doivent
   se dépasser visiblement et la silhouette fonctionner en petite taille.
3. **Tester immédiatement le déplacement.** Conserver des repères de sol,
   suivre talon et avant-pied réellement dessinés, relier vitesse et longueur du
   cycle. Examiner aussi démarrage et arrêt : une belle boucle isolée ne suffit
   pas pour aller d'une case à l'autre.
4. **Prouver l'habillage sur un seul cycle.** Comparer une courte séquence guidée
   par vidéo à une finition 2D de poses clés. Conserver cadrage et proportions.
   Le passage derrière le drapé et les changements de face des chaussures sont
   les zones décisives. Les pixels exacts de ces occultations ne peuvent pas être
   déduits d'un seul dessin de face.
5. **Finir seulement la solution corrigeable.** Ajouter les plis, les mouvements
   secondaires et les images utiles. Toute correction d'un pied doit pouvoir
   être propagée ou retouchée sans régénérer librement les huit dessins. Si ce
   test échoue, prévoir une retouche dessinée ciblée ou une intervention
   d'animateur 2D ; aucun outil consulté ne garantit automatiquement le résultat.

Ce prochain essai a une limite claire : un cycle, une direction, un comparatif
avant/après. Sa réussite se juge sur les appuis, l'identité des jambes, le visage,
la rigidité des armes, le retour de boucle et le coût réel d'une correction.
Les autres actions attendent cette preuve.

## Outils : rôle précis et limites

| Outil | Usage pertinent ici | Limite décisive |
|---|---|---|
| Blender 5.1, déjà installé | Mouvement éditable, pieds pilotés par cibles indépendantes du bassin, caméra fixe, rendu de référence | Ne résout pas seul le style peint ; ne pas refaire une armure détaillée avant le mouvement |
| Krita 5.3.3 portable, déjà installé | Brouillons, poses clés et corrections peintes en comparant les images voisines | L'outil ne dessine pas de bonnes poses automatiquement |
| Revue Godot et audit local | Déplacement réel, taille de jeu, mesure des appuis et transitions | Charger huit PNG ne valide pas leur mouvement |
| Scenario, Kling V3 Motion Control ou Wan Animate Move | Image de Passe-rive + vidéo du mouvement pour animer une séquence entière | Documentation de capacités, aucun essai sur Passe-rive effectué ; pieds, accessoires, boucle et alpha restent à contrôler |
| EbSynth | Propager des retouches peintes sur une vidéo déjà cohérente | Dépend de la correspondance des formes et du suivi vidéo ; ne crée pas une bonne marche à partir de huit poses mauvaises |

La [documentation Krita](https://docs.krita.org/en/user_manual/animation.html)
explique la construction des poses clés et la comparaison des images précédentes
et suivantes. [Spineboy](https://en.esotericsoftware.com/spine-examples-spineboy#Legs)
montre pourquoi les cibles IK des pieds doivent pouvoir rester fixes quand le
bassin bouge. Ces principes sont utilisables avec les outils déjà présents.

Scenario documente l'entrée image + vidéo et le choix d'orientation dans
[Kling V3 Motion Control](https://help.scenario.com/articles/2242372122-kling-v3-motion-control-the-essentials),
ainsi que le transfert de mouvement dans
[Wan Animate Move](https://help.scenario.com/articles/7564346085-wan-2-2-animate-models-the-essentials).
Cela répond mieux à notre problème temporel qu'une série d'éditions indépendantes.
C'est une hypothèse de production, pas un résultat testé ni une garantie issue
de leurs formulations commerciales. Aucun abonnement ni lancement payant effectué.

[EbSynth](https://ebsynth.com/) demande explicitement que les formes peintes
correspondent à celles de la vidéo, faute de quoi des ondulations apparaissent.
Sa propagation n'utilise pas de modèle génératif ; elle transfère les textures
des poses peintes. L'offre web gratuite est limitée à la vidéo 720p ; les PNG
avec alpha sont dans l'offre Pro et le traitement entièrement local dans Studio
d'après la page consultée. Ce n'est donc pas un nouvel outil local gratuit à
installer sans examiner son utilité.

Entraîner un modèle d'apparence ne fixe pas les contacts. La recherche
[Animate Anyone](https://arxiv.org/abs/2311.17117) distingue justement référence
d'apparence, guidage de poses et continuité temporelle. Elle appuie cette
distinction, mais ne prouve pas une marche de sprite avec armes sans défaut.

## Fichiers et reprise

- `tools/passe_rive_motion/audit_walk.cjs` : rapprochement de texture et audit des
  coordonnées du guide ; réexécutable sans modifier les sources.
- `tools/passe_rive_motion/audit_crops.cjs` : agrandissements avec coordonnées.
- `artifacts/spine_trial/passe_rive_walk_audit/` : mesures JSON, agrandissements
  et page de comparaison.
- Les tests d'import de la V1 restent des preuves techniques de cette V1.
  Cet audit **ne livre pas encore une marche corrigée** et remplace son statut
  « à valider » par « à reconstruire avant finition ».
