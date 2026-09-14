# Reprise de la production des personnages — après le rejet du Veilleur

12 septembre 2026. **Verdict utilisateur : marche quatre vues rejetée artistiquement.** Les proportions avaient été jugées utilisables ; le personnage animé est maintenant jugé mécanique et sans vie. Cette décision remplace « avis artistique attendu ». Les anciens résultats techniques restent des résultats techniques, et les fichiers sont conservés.

## 1. Conclusion du diagnostic

Nous avons automatisé le déplacement d'un dessin sans suffisamment concevoir son animation. Le défaut principal est dans les poses, la construction du corps et notre manière de décider qu'une étape mérite d'être poursuivie. Ajouter un logiciel, des images intermédiaires ou des directions ne résout pas ce défaut.

Le dossier précédent décrivait déjà une méthode pertinente : poses du corps entier, rythme, pièces et dessins de remplacement adaptés à ces poses, puis interpolation et export. **Je ne l'ai pas appliquée jusqu'au bout.** L'implémentation est revenue à des courbes de pieds et de bras autour d'une image centrale rigide. La documentation n'était donc pas le seul manque : la capacité d'exécution artistique et son contrôle n'ont pas été démontrés.

## 2. Ce qui ne fonctionne pas dans notre résultat

Constats issus des sources de fabrication, des poses exportées E et de leur comparaison avec l'étude Nicolas Détrain conservée dans le projet. Ce ne sont pas des mesures biomécaniques d'une population ni un jugement automatique de beauté.

| Constat vérifiable | Conséquence visible / interprétation | Changement nécessaire |
| --- | --- | --- |
| Tête, torse, bassin, écharpe et tunique appartiennent à une même image centrale. | Le haut du corps conserve pratiquement sa pose pendant que les jambes travaillent. Aucun décalage indépendant tête–thorax–bassin n'est possible dans cette construction. | Concevoir les poses globales et leur construction avant de choisir les découpes. Séparer les masses qui doivent réellement bouger ; dessiner les formes qui ne peuvent pas être obtenues par rotation. |
| L'oscillation du corps vaut seulement 0,48 px horizontalement et 0,96 px verticalement, d'un extrême à l'autre, à l'échelle du laboratoire. Rotation globale : ±0,8°. | La réaction du corps à l'appui est presque effacée. Il ne suffit pas d'augmenter ces nombres : une oscillation arbitraire produirait un autre défaut. | Composer l'abaissement, le passage et la remontée comme des poses avec un transfert de poids lisible. |
| Le cycle entier dure 800 ms et avance d'environ 20 px à l'échelle affichée, soit environ 25 px/s et 2,5 pas/s. | Peu de terrain couvert pour une alternance rapide des jambes ; cela contribue à la lecture de petits pas étriqués. Aucune « cadence idéale universelle » n'en est déduite. | Choisir ensemble caractère de la marche, amplitude et vitesse réelle sur la carte. |
| Les 48 images proviennent de courbes communes et d'un calcul d'articulations. | Elles échantillonnent un geste ; elles ne constituent pas 48 poses conçues. Une boucle peut être continue et rester pauvre. | Évaluer quelques poses contrastées, puis le rythme entre elles, avant de densifier. |
| Les bottes gardent un dessin directionnel fixe, déplacé et tourné ; les ombres des jambes suivent une déformation de surface. | Le raccourci, la torsion et les changements de volume restent limités par la vue initiale. Les raccords peuvent être propres sans que la jambe paraisse vivante. | Dessins de remplacement ou source volumique adaptée lorsque la forme change réellement. |
| Les nouvelles directions nécessitent de nouveaux dessins et attaches. | Les petites variations de construction s'ajoutent au défaut du cycle commun ; la quantité à revoir augmente. | Faire accepter une animation expressive avant sa déclinaison. Une planche de quatre vues n'est pas un jalon de qualité en soi. |
| Les contrôles valident chargement, appuis partiels, durée, chemin et boucle. | Ils répondent à « est-ce que cela fonctionne ? », pas à « est-ce que ce personnage donne envie de jouer ? ». | Conserver ces vérifications, mais faire du verdict visuel un critère bloquant de production. |

Preuves : [générateur des vues](../../../tools/veilleur_walk/build_iso.py), [courbes V5](../../../tools/veilleur_walk/walk_v5_refined.py), [configuration exportée](../../../artifacts/spine_trial/veilleur_walk_iso_v1/walk_review.json), [poses E](../../../artifacts/spine_trial/veilleur_walk_iso_v1/E_poses.jpg), [origine de l'étude Nicolas](../../../artifacts/dev/veilleur-nicolas-study/source.json). Les mesures dérivées et les empreintes des entrées sont conservées avec la [comparaison interactive](http://127.0.0.1:8734/files/animation_reset/review.html).

Les principes écrits mais insuffisamment exécutés figurent dans les sections 6, 7 et 12 du [dossier de faisabilité précédent](ankama_character_feasibility_2026-09-12.md). Le contrôle des pieds a été utile ; c'est sa place excessive dans nos décisions de progression qui a été une erreur.

## 3. Ce que font réellement les productions citées

**Ankama / Nicolas Détrain.** Le portfolio présente un travail d'animation de personnages ; notre cache permet de revoir un cycle image par image. On y lit des poses de jambes plus distinctes et une silhouette qui change davantage que dans le Veilleur. Cette observation ne donne accès ni à son rig interne ni à ses décisions de fabrication. Le portfolio de sprites identifie Animate/Flash comme outils : posséder ces outils ne remplace pas ce travail. [Portfolio de l'animateur](https://www.behance.net/gallery/244473173/DOFUS-Sprite-Animation), [marionnette Dofus étudiée précédemment](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation).

**Nindash, mobile Ankama.** Romain « Sephy » Pergod décrit des actions pensées avec le gameplay et très peu de dessins, des séquences PNG exportées depuis Animate, puis une marionnette Unity pour un boss trop grand pour cette approche. Les nombreuses apparences réutilisaient une conception simplifiée. Le noyau de trois personnes avait aussi le soutien de spécialistes, notamment pour les effets ; l'auteur avait plus de dix ans d'expérience. Ce cas montre une économie de production fondée sur des choix artistiques et des compétences, pas une génération automatique de mouvements complexes. [Bilan original](https://sephyka.com/game-post-mortem/ankama-nindash/).

**Dead Cells.** Thomas Vasseur explique une fabrication en 3D puis un rendu en images 2D. Il recherche des poses convaincantes et un rythme correct avec peu d'images avant d'en ajouter ; les reprises rapides de l'animation font partie de l'intérêt du procédé. Ce témoignage ne prouve pas qu'un mannequin procédural ou un rendu Blender quelconque atteindra cette qualité. [Retour de production de l'artiste, 2018](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-).

**Hades.** Un développeur de Supergiant confirme en 2019 que de nombreux personnages, dont Zagreus, sont modélisés et animés en 3D puis rendus en milliers d'images sous différents angles. L'apparence « sprite » ne révèle donc pas la façon dont le mouvement a été fabriqué. [Réponse du développeur](https://steamcommunity.com/app/1145360/discussions/0/1738883810796606862/).

**Spine.** Sa documentation décrit la composition de poses majeures et de leur timing avant les intermédiaires. L'exemple Spineboy sépare notamment les commandes de bassin et de pieds, et permet une action coordonnée du torse, de la tête et du bras. C'est un exemple inspectable pour comprendre une construction animable, pas un habillage Dofus prêt à reprendre. [Méthodes d'animation](https://esotericsoftware.com/spine-animating), [construction de Spineboy](https://esotericsoftware.com/spine-examples-spineboy).

Ces cas documentent plusieurs moyens de fabriquer. Leur point commun utile pour nous est une animation conçue et corrigeable, puis une réutilisation de ce qui fonctionne. Ils ne justifient pas de prétendre connaître tous les outils propriétaires d'Ankama.

## 4. Choix réaliste pour notre reprise

La cible reste un personnage original, adulte et simplifié, compatible avec les décors émeraude. Le Veilleur n'est plus une base d'animation à enrichir ; ses proportions sont une référence historique, pas une obligation de conserver ce personnage.

**Je recommande une production 2D hybride avec une source de mouvement réellement animée et modifiable.** Les poses, remplacements de dessins et rythmes viennent d'abord ; découpes, déformations et effets servent ces choix. La variante 3D rendue en sprites reste possible si une animation source convaincante s'y prête. Nous ne reconstruisons pas un nouveau générateur de marche pour décider ensuite si le mouvement est bon.

La voie la plus fiable est un petit pilote confié à un animateur capable de livrer le fichier de travail, ou l'adaptation d'une animation existante sous licence adaptée. Le périmètre du pilote est défini ci-dessous ; aucun contact, achat ou engagement n'est effectué. Un extrait de portfolio Dofus est une référence d'étude, pas une ressource de production autorisée.

En autonomie complète avec les outils actuels, je peux préparer les références, organiser les poses, assister les retouches, intégrer et vérifier. **Je n'ai pas démontré que je peux produire régulièrement seul une animation originale proche d'Ankama.** Un nouvel essai doit être présenté comme une expérience artistique limitée, et non comme une méthode de production désormais acquise.

ImageGen reste utile pour explorer la silhouette et proposer des poses ; la cohérence temporelle et la retouche fiable restent à démontrer sur chaque source retenue. Accumuler des références dans une mémoire externe améliore nos consignes et évite certaines erreurs ; cela ne réentraîne pas les poids du modèle. Les premiers sorts appréciés prouvent que des poses générées peuvent fonctionner, pas que nous savons les décliner et les corriger à volonté.

## 5. Pilote de reprise : un livrable, une décision

**Intention :** un adulte surnaturel calme et déterminé, marche ordinaire, souple, sans arme ni effet. Le caractère doit se lire dans le corps. Une seule vue trois-quarts, à la taille réellement utilisée sur une carte émeraude du projet.

**Sources attendues :** un cycle déjà convaincant, son fichier d'animation modifiable, les dessins ou le modèle nécessaires, et les droits d'usage identifiés. Pour une création originale, présenter d'abord les poses globales de contact, abaissement, passage et remontée des deux demi-cycles. Ce sont des repères de travail, pas huit dessins imposés à toute technique.

**Livraison artistique préalable :** une boucle brute et une séquence courte entrée en marche → déplacement → arrêt, sur fond neutre puis sur le décor. Pas d'armure détaillée, particules ou autres angles à ce stade. Conserver le rythme choisi par l'animateur ; ne pas le remplacer automatiquement par nos anciennes courbes.

**Acceptation :** à vitesse normale et à taille jeu, le personnage a une intention lisible ; le poids passe d'une jambe à l'autre ; le haut du corps participe ; la silhouette reste cohérente ; les contacts et l'arrêt ne distraient pas. L'approbation visuelle concerne cette sortie précise. Le ralenti sert au diagnostic, pas à fabriquer une impression favorable.

**Preuve de correction :** modifier un élément demandé du geste, dans sa source, sans changer les proportions ou le costume ailleurs. Si le mouvement est bon mais sa retouche impossible, la production en série n'est pas encore démontrée.

**Suite seulement après réussite :** adaptation du design original → retouche témoin → idle et raccords → deuxième angle → quatre angles → une action forte → kit. Réutiliser l'export et le lecteur existants lorsque cela convient. Si deux corrections ciblées échouent sur le même défaut, arrêter cette voie et réexaminer la source ou le besoin d'intervention artistique. Ne pas prolonger la série de versions procédurales.

## 6. État réel à la fin de cette reprise

- Le diagnostic, la comparaison et le périmètre du pilote sont préparés. Le Veilleur quatre vues est marqué rejeté dans les fiches de reprise.
- Aucun nouveau personnage ou nouveau cycle n'est déclaré réussi. Aucune estimation de délai ou de coût de série n'est établie.
- Les tests historiques sont conservés. Cet audit ne relance pas le moteur et ne transforme pas ces anciens tests en preuve artistique.
- Prochaine preuve manquante : une animation source convaincante **et** une adaptation corrigeable sur notre personnage. C'est sur cette preuve que doit porter la prochaine dépense de production.
