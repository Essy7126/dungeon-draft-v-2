# Passe-rive — ce que la production Dofus change à notre méthode

Recherche du 11 septembre 2026. Périmètre : **marche uniquement**, puis ses quatre orientations avant toute autre animation. Dernier verdict utilisateur : la marche n'est ni fluide ni belle. Ce verdict remplace le statut « revue artistique attendue » pour le candidat isométrique actuel.

## Résultat utile

Nous avons surtout fabriqué des images terminées et essayé de raccorder leurs différences. Il nous manque une source artistique que l'on peut animer et corriger sans redessiner involontairement le personnage entier. La piste à tester est une **animation 2D hybride : pièces dessinées stables, courbes de mouvement, dessins de remplacement aux changements de forme et de perspective**. Le mannequin Blender garde son rôle de référence des appuis.

L'étude a produit un [comparatif local image par image](http://127.0.0.1:8734/files/dofus_motion_study/review.html) : deux marches Dofus, corps seul et équipé, face à nos douze images par orientation. Les références sont attribuées et séparées des ressources du jeu. Aucun nouveau sprite Passe-rive n'a été créé ou approuvé dans cette recherche.

## 1. Les preuves de production retrouvées

### La charte des personnages, par son auteur

Julien Druant publie une charte pour les personnages et PNJ de Dofus 3. Les planches examinées prescrivent des formes simplifiées, une construction isométrique cohérente et une lecture à taille réelle. Le parcours présenté passe par le croquis, le dessin vectoriel, la comparaison avec des personnages validés, les couleurs, la revue artistique, la vue de dos et une fiche pour les animateurs. Le gabarit montre aussi la silhouette et l'encombrement sur une case. Les pages de méthode observées portent les numéros 9, 9, 11, 12 et 13 : cette numérotation est celle de la source. [Charte de Julien Druant](https://www.behance.net/gallery/251142101/charte-graphique-pour-les-personnages-Dofus-3).

Son document distinct sur les objets décrit des règles de matière et des gabarits destinés à uniformiser la fabrication des équipements. Ce document concerne les items ; ce n'est pas le manuel d'un éditeur de mouvement. [Charte et outils de production](https://www.behance.net/gallery/251141703/Charte-Graphique-et-Outils-de-Production).

### La marionnette commune de Dofus Unity

Nicolas Détrain explique que les écarts morphologiques accumulés entre classes et sexes avaient dégradé la compatibilité des apparences avec la marionnette commune. Sa refonte a reconstruit celle-ci et les animations des personnages joueurs, en coordination avec le game design. La publication expose aussi les mêmes personnages avec différentes pièces d'équipement. Elle ne fournit pas un rig téléchargeable ni un manuel complet de l'exporteur. [Présentation du responsable animation](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation).

Son profil professionnel précise son travail de liaison entre character designers, développeurs et game designers sur Dofus 3. Il distingue son expérience Flash/Animate chez Ankama et son emploi plus récent de Spine sur un autre projet. **La présence de Spine dans son CV ne prouve donc pas que Dofus est animé avec Spine.** [Témoignage professionnel de Nicolas Détrain](https://www.malt.com/profile/nicolasdetrain).

### L'éditeur et le moteur sont deux choses différentes

Les portfolios Dofus de Détrain et d'Anima Tom indiquent Flash/Adobe Animate. Le second contient des séries d'animations de monstres et de PNJ attribuées à leur animateur. Cela atteste un outil de fabrication ; cela ne décrit pas à lui seul le format lu par le moteur actuel. [Détrain, sprites Dofus](https://www.behance.net/gallery/244473173/DOFUS-Sprite-Animation), [Anima Tom, animations de jeu](https://www.behance.net/gallery/10550983/Game-Animations-for-DOFUS).

Ankama a annoncé le portage de ses serveurs existants vers le client Unity au 3 décembre 2024. Il faut distinguer cet historique du moteur de l'outil dans lequel un animateur dessine ses poses. [Annonce officielle Ankama](https://support.ankama.com/hc/fr/articles/29422009505937--DOFUS-DOFUS-3-0-pr%C3%A9-inscriptions).

Je n'ai pas trouvé de distribution publique vérifiée de l'éditeur interne, de son exporteur ou de la marionnette complète. Les mentions de Tiphon et les dépôts de clients décompilés ne sont pas retenus comme documentation officielle de production.

## 2. Ce qui a réellement été observé

Deux GIF de marche du portfolio de la marionnette ont été décodés. Dans chacun, les images 0 à 15 sont exactement identiques aux images 16 à 31. L'intervalle retenu est donc un cycle observé, et non une coupe arbitraire. Les 16 délais encodés valent chacun 30 ms, soit 480 ms. **Ce chiffre décrit le GIF publié, pas les images/s de Dofus ni le nombre de dessins manuels.** La version de course ne répète pas ce même intervalle : elle a été écartée du lecteur en boucle.

Lecture visuelle de ces extraits : les passages de jambes restent identifiables, le genou se replie au retour, les mains suivent des trajectoires distinctes du buste. L'équipement conserve ses formes et la cape change de silhouette. Ces observations constituent une cible esthétique ; les GIF seuls ne prouvent ni les contraintes exactes du rig ni une absence de glissement dans le monde. [Source animée et explication](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation).

Le comparatif conserve les délais originaux et donne un lecteur indépendant à Passe-rive. Il serait trompeur de conclure « Dofus est meilleur parce que sa boucle va plus vite ». Nos images actuelles durent 100 ms chacune et présentent aussi des différences de volume et de trajectoire.

Autres consultations : plusieurs emotes, un personnage vu de dos, une course équipée et des animations de sanglier ont été examinés par échantillons. Ils ne constituent pas une analyse exhaustive de ces clips. La vidéo officielle [making-of du Bouledogre, 2013](https://www.youtube.com/watch?v=NO0D8qbX86Y) et les vidéos humanoïdes d'Anima Tom sont repérées, mais n'ont pas été analysées intégralement. Ne pas présenter leurs titres comme une observation du contenu.

La fabrication télévisée de Wakfu et de BESTIALE est un autre contexte. L'interview de Studio Unagi décrit un mélange dessin/rig pour BESTIALE ; elle peut fournir des idées, mais ne prouve rien sur le moteur Dofus. [Entretien publié par Toon Boom](https://www.toonboom.com/fr/studio-unagi-sur-la-combinaison-de-lanimation-traditionnelle-et-de-lanimation-avec-marionnettes-dans-bestiale).

## 3. Pourquoi notre marche reste décevante

Constats sur nos fichiers et nos essais, distincts des sources Ankama :

| Défaut | Cause ou hypothèse précise | Intervention à tester |
| --- | --- | --- |
| Masque, broche, cape et bouclier changent entre images | Les poses clés et les intermédiaires proviennent de dessins générés différents. | Fixer les pièces qui doivent conserver leur identité ; retoucher uniquement la pièce fautive. |
| Un pied dérive sur la diagonale du sol | Le déplacement peint ne compense pas correctement les deux composantes du déplacement du personnage. | Définir le contact en coordonnées du monde, puis contrôler sa projection à l'écran. |
| Le rythme paraît haché | Douze images sont tenues uniformément ; certaines transitions de pose et de contour sont importantes. | Corriger les trajectoires et la répartition temporelle avant de multiplier les images. |
| Le corps paraît mécanique | Le guide des appuis ne contient pas à lui seul toute l'intention artistique ; son imitation est aussi imparfaite. | Travailler le transfert du poids, les épaules, la stabilité du regard et la réponse du costume. |
| Une correction demande de reprendre tout le dessin | Nous conservons surtout un personnage aplati par image. | Rendre éditables séparément les pieds, les mains, le tissu et les accessoires. |
| Les essais s'accumulent sans résultat accepté | La réussite du chargement ou du détourage a parfois précédé une vraie revue du mouvement. | Conserver un verdict artistique explicite, séparé des contrôles techniques. |

La mesure locale existante suit quatre repères d'une chaussure sur quatre images E : environ 7,25 pixels de dérive à l'échelle du jeu, encore 6,81 après ajustement de vitesse. Le suivi est perdu ensuite. Ce n'est pas une mesure du cycle complet ni une identification automatique du vrai contact talon/pointe. [Rapport de suivi](../../../artifacts/spine_trial/passe_rive_walk_iso_v1/foot_tracking_report.json), [audit des réparations partielles](passe_rive_partial_repairs_2026-09-11.md).

Augmenter seulement la fréquence d'affichage répéterait les mêmes dessins. Une interpolation vidéo peut fabriquer davantage d'images tout en déformant la lance ou en inventant un pied au croisement. Une meilleure fluidité apparente ne suffirait pas à accepter ce résultat.

## 4. Les outils qui répondent au problème

| Outil | Apport concret | État et décision pour ce projet |
| --- | --- | --- |
| **Godot : AnimationPlayer, Sprite2D/AnimatedSprite2D, Polygon2D** | Pistes de position/rotation, changement de dessin, ordre d'affichage et déformation locale. Essai immédiatement sur notre carte. | Déjà disponible. Premier choix pour assembler le pilote et réutiliser nos contrôles. |
| **Krita 5.3** | Dessins de pieds, genoux, mains et tissu ; pelure d'oignon et comparaison des voisins. Les masques de transformation disposent aussi de courbes animées. | Déjà présent dans les outils locaux. Sert à préparer et corriger les pièces ; aucun nouveau greffon nécessaire à cette étape. |
| **Adobe Animate** | Bibliothèque de symboles, chronologie et dessins vectoriels ; outil attesté dans les portfolios Dofus étudiés. | Absent du poste contrôlé, hors Acrobat. Option pertinente si nous choisissons cet éditeur ; pas d'abonnement lancé. |
| **Spine** | Courbes, attachments de remplacement, IK et fantômes pour régler les cycles. | Trial déjà installée ; sauvegarde/export limités. Une licence serait nécessaire pour en faire notre outil de production. |
| **Blender** | Projection, appuis et déplacements de référence. | Déjà disponible. Conserver cette aide sans lui confier automatiquement le rendu du costume. |
| **OpenCV** | Mesurer une dérive locale et détecter la perte de suivi. | Installé et essayé. Outil de diagnostic, pas de création d'une belle marche. |
| **ImageGen / transfert vidéo** | Chercher un dessin manquant ou un candidat de geste. | Sorties à contrôler. Ne plus demander une nouvelle version complète du personnage pour chaque pied à corriger. |

Godot documente explicitement le mélange entre pièces articulées et dessins de remplacement pour les mains, les pieds ou les expressions. La page porte toutefois un avertissement de mise à jour incomplète pour 4.7 : les détails d'IK doivent être vérifiés dans notre moteur, et non recopiés aveuglément. [Guide Godot](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html).

Krita documente l'animation raster image par image et les masques de transformation animés avec interpolation linéaire, constante ou Bézier. [Animation Krita](https://docs.krita.org/en/user_manual/animation.html), [courbes et masques](https://docs.krita.org/en/reference_manual/dockers/animation_curves.html).

Adobe indique au 8 juin 2026 qu'Animate reste disponible pour les nouveaux utilisateurs, en mode maintenance, avec correctifs mais sans nouvelles fonctionnalités prévues. Son arrêt annoncé précédemment n'est plus la politique publiée. [FAQ officielle Adobe](https://helpx.adobe.com/animate/desktop/kb/maintenance-mode.html).

Spine documente une approche combinant poses majeures, passes successives et courbes. Il signale aussi qu'un travail isolé par partie peut produire des mouvements déconnectés. Le corps entier doit donc être revu après chaque passe. [Guide d'animation Spine](https://us.esotericsoftware.com/spine-animating).

## 5. Pilote concret : une marche de Passe-rive qui puisse être corrigée

Ce protocole est une proposition de production issue du diagnostic ; ce ne sont pas des paramètres secrets d'Ankama.

**A. Fixer la source animable E.** Garder Passe-rive adulte et élancé, son masque, sa capuche pétrole et son drapé jade. Construire une feuille de pièces avec des zones de recouvrement aux articulations. Le pied doit posséder des silhouettes adaptées à l'appui, à la poussée et au retour ; la rotation d'une même image ne suffit pas dans toutes les perspectives. La lance reste attachée à la main droite anatomique et le bouclier à la gauche.

**B. Poser le corps entier.** Préparer contact, compression, passage et remontée pour les deux demi-pas. Conserver une version peu détaillée où l'on peut modifier facilement le bassin et les jambes ensemble. Une articulation n'est pas un objectif esthétique : si son dessin est laid ou raide, remplacer la forme au lieu d'ajouter des os.

**C. Donner une trajectoire aux appuis.** Tant qu'un point du pied est planté, son déplacement dans le monde doit rester presque nul. Dans la boucle sur place, il recule relativement au personnage. Distinguer talon, plante et pointe ; relever le pied pendant le retour. Contrôler les deux composantes de la diagonale isométrique. La vitesse du déplacement Godot et la distance du cycle doivent être liées.

**D. Enrichir sans brouiller.** Faire sentir une petite compression lors de la prise de poids, une remontée au passage et une réponse des épaules. Le regard demeure plus stable que le bassin. Avec une lance et un bouclier, les bras ne peuvent pas balancer comme ceux d'un marcheur sans charge. Ajouter ensuite un retard discret du bas du drapé et de la ceinture ; les mains et les prises d'armes restent prioritaires. Tester l'amplitude à taille de jeu.

**E. Choisir la sortie après la revue.** Des courbes peuvent être évaluées à chaque image affichée sans nécessiter autant de dessins originaux. Un export en sprites reste possible : on choisira alors son nombre d'images d'après le mouvement obtenu. Ne pas imposer « douze dessins » ou « trente images » comme recette universelle.

**F. Compléter les autres vues de cette même marche.** Après E, traiter S, N et W successivement. Vérifier les côtés anatomiques, le devant/dos du bouclier, les recouvrements du costume et les transitions entre directions. Aucune autre animation ne passe devant cette étape.

## 6. Répartition du travail à reprendre d'une production organisée

Nous n'avons pas besoin de multiplier les logiciels pour imiter une grande équipe. Nous devons rendre explicites ses décisions. Pour chaque version :

- **Dessin** : identité, proportions, pièces cachées nécessaires, silhouette à petite taille.
- **Animation** : intention, poses, trajectoires, temps et mouvements secondaires.
- **Intégration** : pivot, distance parcourue, ordre d'affichage, arrêt et changement de direction.
- **Revue artistique** : regarder à vitesse normale et sur la carte ; garder un défaut daté et une correction précise.

Le livrable d'une étape doit être utilisable par la suivante. Un PNG de présentation ne remplace pas une feuille de pièces ; un export sans erreur ne remplace pas une animation acceptée. Ces responsabilités sont une adaptation pour notre projet, pas un organigramme prétendument complet d'Ankama.

## 7. Conditions pour conserver la nouvelle méthode

Le pilote devra montrer un progrès sur le **dessin en mouvement**, pas seulement sur le mannequin. Vérifier E sur place, en déplacement réel et au ralenti ; puis effectuer la même revue des trois autres vues. Vérifier la frontière de boucle et plusieurs départs/arrêts. Garder la même échelle d'une image à l'autre.

Deux critères pratiques décident aussi de la suite : peut-on corriger un pied sans changer le masque ou la lance ? Et le temps de cette correction diminue-t-il au deuxième essai ? Si la réponse est non, l'organisation des pièces ou le mode de dessin reste insuffisant, même si le premier rendu est séduisant.

L'étude ne démontre pas encore que je réussirai une marche au niveau de Dofus avec ce montage. Si les dessins de remplacement restent faibles, l'aide la plus ciblée serait une courte intervention d'un animateur 2D sur **un cycle source et sa feuille de pièces**, plutôt qu'une commande du kit entier. Aucun contact ni commande n'a été effectué.

## 8. Preuves, limites et reprise

- Source artistique actuelle : `art/source/characters/achilles/passe_rive_walk_iso_v1/`. Statut : **refus de fluidité/qualité**, candidat conservé comme comparaison.
- Cache d'étude : `artifacts/dev/dofus-research/`, URLs exactes, quelques captures, pages consultées et métadonnées. Les images de tiers ne sont pas des ressources de production.
- Comparatif : `artifacts/spine_trial/dofus_motion_study/`. Deux cycles de référence vérifiés par égalité des pixels ; 48 images Passe-rive chargées. Lecture/pause, pas d'image et bouclage des commandes vérifiés ; aucun débordement mobile ni erreur JavaScript constaté. Cela vérifie l'outil de comparaison, pas l'art.
- Les sources publiques exposent une partie du travail : aucune prétention d'avoir audité tout le pipeline Ankama, les éditeurs internes ou toutes les vidéos.
- Genjutsu : essai préparé précédemment, toujours **non soumis**, choix explicite de consommation de l'essai gratuit non reçu. Aucun achat, aucun entraînement lancé.
- Lire ces références améliore notre dossier et nos règles de travail ; cela ne modifie pas les poids du modèle. [Mémoire courte](../../ai/animation_memory.md).

**Reprise prioritaire : construire la source 2D éditable de la marche E, avec ses pieds de remplacement et sa lance indépendante. Ne pas relancer une planche complète d'intermédiaires ni un lot de sorts.**
