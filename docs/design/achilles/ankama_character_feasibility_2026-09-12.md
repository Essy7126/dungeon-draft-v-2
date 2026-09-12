# Personnages de Catabase : style et production

**La cible recommandée est un dessin de jeu inspiré du Dofus 2 documenté dans les travaux de Julien Druant, simplifié et accordé à l’univers émeraude, ivoire et bronze de Catabase.** La construction retenue associe des poses dessinées, des pièces réutilisables et des remplacements locaux. Godot reste le moteur et l’atelier de mise en mouvement ; Krita sert à conserver et corriger le dessin. La génération propose des formes et des poses, soumises à sélection.

Cette cible est plausible pour un premier héros avec un périmètre limité. **La production régulière de personnages complets à la qualité d’Ankama n’est pas encore démontrée.** Le principal obstacle est la fabrication et la correction de dessins cohérents en mouvement. Les exports, les horloges et les contrôles techniques sont plus avancés que cette partie artistique.

Ce dossier remplace la recommandation générale du [premier audit](ankama_character_pipeline_2026-09-12.md). Il distingue les témoignages de studios, les observations dans Catabase et les décisions proposées. Les données de production citées sont datées ; aucune présentation ancienne n’est assimilée à la totalité des outils actuels d’un studio.

## 1. Le style Dofus retenu

Le référentiel est **le Dofus 2 de jeu présenté dans le portfolio de Julien Druant, publié en 2017**, avec son entretien Dofus Mag de 2014 en complément. L’auteur décrit un travail réalisé directement dans Flash. Ces documents donnent des références datées, distinctes des illustrations promotionnelles. [Portfolio — R1](https://www.behance.net/gallery/55966955/DOFUSCHARACTER-DESIGN-SPRITES), [entretien — R2](https://www.behance.net/gallery/55601787/DOFUSMAG-SPRITES-INTERVIEW).

Les planches examinées montrent une forte hiérarchie des masses et des couleurs. Leur complexité varie selon les créatures. Les bordures crème de présentation ne sont pas prises pour un contour de rendu obligatoire en jeu.

| Référence envisagée | Intérêt pour Catabase | Décision et raison |
| --- | --- | --- |
| Dofus Retro | Forte économie de formes et identité immédiate. | Étudier la lisibilité ; conserver une définition moderne et des possibilités de pose plus larges pour notre production. |
| Dofus 2, sprites de jeu sélectionnés dans le corpus 2014–2017 | Grandes masses, formes stylisées, dessin compatible avec des pièces et des substitutions. | **Cible principale, avec complexité réduite et proportions originales.** |
| Dofus 3 | Charte, personnalisation et compatibilité d’un personnage modifiable. | Référence de méthode. Sa simplification visuelle n’implique pas que l’ensemble de son système soit facile à reproduire. |
| Illustrations promotionnelles, cinéma et grandes peintures | Recherche d’atmosphère, de caractère et de mise en scène. | Références secondaires. Leur richesse ne fixe pas le niveau de détail d’un sprite. |

Le choix de Dofus 2 ne signifie pas qu’un style ancien serait mécaniquement plus simple. Un contour raté, une mauvaise pose ou une articulation cassée y restent très visibles. La réduction porte sur le costume, les volumes, le nombre de variantes et la quantité de gestes simultanément en fabrication.

Le héros doit rester adulte, élancé et lisible. Son identité viendra de sa silhouette, de sa posture, de son visage et de quelques signes forts. L’anatomie détaillée, les petits plis et les surfaces brillantes ne sont pas indispensables à cette identité. La dimension spectrale peut passer par le masque, le regard, la palette et les effets ponctuels tout en conservant des jambes et des appuis compréhensibles.

Ce rendu dessiné peut être préparé avec des images raster de bonne définition. Le contrôle des formes, des contours et des valeurs compte davantage que l’extension du fichier. La cible proposée n’exige donc pas de reconstruire immédiatement toute la fabrication vectorielle d’Ankama.

## 2. Les corrections apportées au premier audit

**Une source à calques n’est utile que si les retouches reviennent dans l’animation.** Dans la marche sans armes V2, le générateur lit les pièces PNG de la V1. La fonction qui écrit les fichiers OpenRaster enregistre les calques d’une pose déjà transformée ; aucun lecteur de ces fichiers ne réinjecte leur peinture dans la génération. Ces fichiers sont donc des instantanés éditables, pas encore un aller-retour complet entre dessin et animation. Cette conclusion vient de l’inspection du code, sans nouvelle retouche expérimentale. [Générateur actuel](../../../tools/passe_rive_unarmed/build_walk.py).

**Le découpage ne doit pas précéder aveuglément les poses.** Un membre conçu pour une seule silhouette peut rester reconnaissable pendant une petite rotation et devenir mauvais lorsqu’il se replie. La construction doit être décidée à partir des besoins du mouvement. Une première ébauche sert aussi à simplifier ou à corriger le design.

**La marche V2 ne possède pas une bibliothèque de dessins qui changent pendant le cycle.** Son pied est déformé à partir du même dessin par vue et par côté. Les transformations améliorent les trajectoires, mais ne dessinent pas une semelle qui se retourne. Le corps utilise également un nombre limité de formes fixes. Il manque une réponse artistique à certains changements de perspective.

**Le terrain de validation doit correspondre à la direction artistique actuelle.** La scène de marche examinée charge la forêt historique. Cette vérification reste utile pour les déplacements et la grille ; elle ne prouve pas le raccord au temple émeraude, au titre ou à la Cour des Sources dessinée. [Scène de revue](../../../tools/passe_rive_unarmed/walk_review.gd), [Cour des Sources](../../maps/greek_drawn_courtyard_v1.md).

**Une architecture documentée n’est pas un outil déjà opérationnel dans le projet.** Godot permet de mélanger pièces animées et dessins de remplacement. Le petit atelier complet proposé ici, avec retour de retouche, chronologie éditable et export, reste à éprouver. Le rapport initial donnait trop peu de poids à cet écart.

Enfin, un kit visible sous quatre angles, un contrôle de boucle réussi et une appréciation artistique positive sont trois résultats distincts. Le nombre d’images exportées, les mesures du modèle de mouvement et les tests automatisés ne doivent plus être présentés comme une mesure globale de qualité.

## 3. Les méthodes de studios à reprendre

### Ankama : prévoir la compatibilité

La charte Dofus 3 présente un parcours de conception, de vérification à taille réelle, de couleur, de revue puis de préparation pour l’animation. Les gabarits d’objets décrivent attaches, superpositions et masquages. La refonte de la marionnette commune décrite par Nicolas Détrain répond aux différences morphologiques devenues coûteuses à corriger. Ces documents justifient de définir une base et ses variations admissibles avant d’étendre un catalogue. [Charte — R3](https://www.behance.net/gallery/251142101/charte-graphique-pour-les-personnages-Dofus-3), [équipements — R4](https://www.behance.net/gallery/251141703/Charte-Graphique-et-Outils-de-Production), [marionnette — R5](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation).

**Adaptation :** construire un seul héros et une seule morphologie au départ. Les emplacements d’accessoires et les couleurs peuvent être préparés sans fabriquer immédiatement un vestiaire universel. Une silhouette qui s’écarte fortement du gabarit devient une nouvelle famille de production.

### Klei : le dessin reste une partie de l’animation

La présentation GDC de Jeff Agala et Aaron Bouthillier montre des ébauches, la correction des poses, une bibliothèque de formes et des personnages séparés en symboles. Les éléments sont réutilisés pour les images clés et les intermédiaires. La planche de bibliothèque présente de nombreuses silhouettes complètes, pas seulement une figurine rigide à faire pivoter. [GDC 2014, notamment diapositives 5–15 — R6](https://media.gdcvault.com/GDC2014/Presentations/Agala_Jeff_2D_Animation_at.pdf).

Kevin, programmeur/designer de Klei, décrit en 2012 des ensembles de parties du corps possédant plusieurs dessins, des transformations et des exports d’images avec métadonnées. Il précise que le système a mûri sur plusieurs jeux et souligne le rôle des animateurs. Son ordre de grandeur pour Wilson est d’environ une douzaine de parties avec un nombre comparable de vues ; ces valeurs ne sont ni une norme ni un budget pour Catabase. [Explication directe — R7](https://gamedev.stackexchange.com/questions/44319/what-animation-technique-is-used-in-dont-starve).

**Adaptation :** travailler les poses du corps entier, puis récupérer ce qui peut être réutilisé. Conserver des dessins particuliers lorsque la flexion, l’expression ou le raccourci le demande. Une limite arbitraire du nombre de pièces ne doit pas dégrader le geste.

### Motion Twin : rendre les reprises peu coûteuses

Thomas Vasseur décrit une fabrication 3D dans 3DS Max, un rendu très petit, des poses clés et un outil de conversion pour Dead Cells. Il insiste sur la possibilité de modifier rapidement poses et rythme après les retours de gameplay. Le personnage cité mesure environ 50 pixels dans le jeu ; cette contrainte est très différente d’un personnage dessiné et agrandi dans Catabase. Le témoignage ne décrit pas une animation sans intervention artistique. [Article de l’artiste, 2018 — R8](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-).

**Adaptation :** mesurer le coût d’une correction réussie. Conserver le temps et les événements dans des données éditables. La 3D devient une aide lorsque son usage résout un problème précis ; son intérêt chez Motion Twin ne prouve pas qu’elle donnera notre rendu final.

### Red Hook : faire de la direction artistique un outil de décision

Chris Bourassa explique comment la direction créative de Darkest Dungeon a guidé les choix et les réductions de périmètre. Le studio a notamment privilégié une présentation centrée sur les personnages et limité certaines exigences d’équipement. Il ne propose pas une méthode universelle de sprite isométrique. [GDC 2016 — R9](https://media.gdcvault.com/gdc2016/Presentations/Bourassa_Chris_a%20torch%20in.pdf).

**Adaptation :** renoncer à une fonctionnalité coûteuse si elle n’améliore pas la lecture, le jeu ou l’identité du héros. Un équipement statistique n’a pas besoin d’entraîner immédiatement un changement visuel complet. Les effets peuvent distinguer certaines évolutions d’un sort tout en conservant son geste.

### Ankama, Nindash : adapter le procédé au besoin

Le bilan de Sephy décrit trois personnes au cœur de la production, des renforts spécialisés, trois mois de travail dont un de finitions, des séquences d’images et un boss passé en marionnette pour limiter le volume d’images. La rapidité reposait aussi sur un périmètre et un style adaptés au gameplay. [Bilan de production — R10](https://sephyka.com/game-post-mortem/ankama-nindash/).

**Adaptation :** réserver les dessins et mouvements les plus coûteux aux moments qui comptent. Prévoir les finitions dès le début. Le nombre de mois de Nindash n’est pas une estimation transposable à notre héros.

## 4. Ce que Catabase sait réellement produire

Cette évaluation s’appuie sur les sources du projet, les rapports historiques et les captures examinées. Les tests d’animation existants n’ont pas été relancés pour cet audit documentaire. Le diagnostic d’environnement identifie Godot 4.7.1 ; il ne valide pas l’import du projet. Il signale également un problème d’identité Git dans le contexte isolé, distinct de la version du moteur.

| Domaine | État réaliste | Preuve et limite |
| --- | --- | --- |
| Concepts et variations visuelles | Capacité démontrée à obtenir des candidats convaincants. | Écho de bronze et Passe-rive ont suscité un choix positif. Cela ne démontre pas leur facilité d’animation. |
| Poses expressives pour un geste | Capacité démontrée sur des essais, surtout dans une direction. | Palette et arcs appréciés ; sources conservées. Les raccords et le costume présentent encore des variations. |
| Découpage, transparence et export | Outillage existant et contrôlé sur plusieurs essais. | Rapports d’assets et atelier. Les bords fins exigent toujours une inspection. |
| Temps, événements et déplacement dans Godot | Base technique réutilisable. | Kit Achille, SpriteWorkshop et essais jouables. Une nouvelle famille visuelle doit être intégrée et vérifiée à son tour. |
| Coordination d’une marche calculée | Progrès mesurés, qualité artistique non acquise. | V2 corrige bassin, bras et retour du pied ; 267 contrôles GPU historiques. Les mesures décrivent les repères du modèle. |
| Dessin cohérent sous quatre angles | Partiellement obtenu. | Des pièces existent dans quatre orientations ; elles n’ont pas été acceptées comme personnage final. |
| Retouche locale répercutée dans tout le kit | Partiellement possible par les PNG sources, circuit à compléter. | Les fichiers OpenRaster de pose ne sont pas relus par le générateur. |
| Marche, idle et transitions homogènes | Non démontré pour le nouveau héros. | La V2 se fige à l’arrêt et change instantanément de direction. |
| Série de personnages à qualité stable | Non démontré. | Aucun coût reproductible par personnage accepté ni par correction n’a été mesuré. |

Sources locales : [atelier](../../../tools/sprite_workshop/README.md), [kit Achille](achilles_sprite_kit_v2.md), [palette Passe-rive](../../../art/source/characters/achilles/passe_rive_spells_v1/README.md), [marche V2](../../../art/source/characters/achilles/passe_rive_walk_unarmed_v2/README.md).

**La capacité technique permet d’organiser, monter, exporter et vérifier. La capacité artistique doit encore être prouvée sur une courte séquence complète.** Un agent peut proposer des images, analyser des défauts et préparer des corrections ; il ne peut pas garantir qu’un générateur conservera toujours la bonne main, la bonne semelle ou le même volume d’une vue à l’autre.

## 5. La charte du premier héros

Les règles suivantes sont des propositions pour Catabase, pas des mesures officielles de Dofus. Elles constituent une hypothèse de fabrication à tester sur les décors et dans une marche.

| Élément | Règle de départ | Motif |
| --- | --- | --- |
| Proportions | Essayer une silhouette adulte d’environ 5 à 5,5 têtes ; taille finale choisie sur la carte. | Éviter à la fois le petit enfant et le corps très long dont les extrémités deviennent minuscules. |
| Mains et pieds | Formes simples, légèrement renforcées ; doigts regroupés hors gros plan. | Lecture des gestes et des appuis à taille de jeu. |
| Costume | Deux ou trois masses principales ; articulations suffisamment dégagées. | Réduire les croisements et la quantité de pièces à corriger. |
| Drapé | Un élément court au départ, sans bandes fines devant les deux jambes. | Garder les appuis visibles et limiter le mouvement secondaire. |
| Valeurs | Couleur de base, ombre large, lumière mesurée ; peu de variations internes. | Faciliter les reprises et le raccord entre pièces. |
| Contours | Contour coloré lisible à taille de jeu, détails intérieurs plus discrets. | S’accorder aux décors dessinés et garder une séparation avec le fond. |
| Matières | Métal mat et tissu simplifié ; reflets rares. | Éviter qu’une rotation impose de repeindre de nombreux éclats. |
| Palette | Pétrole, jade, ivoire et bronze ; accent lumineux limité. | Relier le héros au titre et aux lieux émeraude sans le confondre avec le sol. |

La palette proposée est un point de départ : pétrole `#1E343B`, jade `#638F80`, ivoire `#D8D4B6`, bronze `#947545`. Les valeurs devront être ajustées sur les images effectivement utilisées par le jeu. Une palette commune ne suffit pas si le personnage et le fond ont la même luminosité.

La revue visuelle utilisera au moins un sol clair, un sol sombre émeraude et une zone plus chargée. Elle comparera trois tailles voisines dans la caméra réelle. Le titre sert à juger la famille graphique ; il ne sert pas à mesurer la taille ou l’angle d’un personnage de combat.

**La haute résolution est conservée pour le travail. La définition de livraison est choisie d’après le plus grand affichage réellement nécessaire.** Un portrait de sélection peut être distinct du sprite de combat s’il respecte le même modèle. Agrandir fortement un petit sprite ne doit pas être la seule réponse à l’écran de sélection.

## 6. Une architecture de sources corrigeables

La chaîne proposée comporte une autorité claire pour chaque décision : le dessin pour les formes, la chronologie pour le mouvement, le manifeste pour les vues et événements, l’export pour les ressources livrées. Aucun fichier généré ne doit devenir silencieusement la nouvelle source.

**Dessin :** un fichier Krita conserve le travail ; un export OpenRaster de pièces non transformées sert d’échange lisible. Krita documente ce format comme une archive contenant notamment des calques PNG. Les noms de pièces et leurs positions doivent rester stables. Les modes de fusion et effets complexes sont aplatis volontairement dans la pièce concernée, puis comparés au rendu source. [Documentation OpenRaster — R11](https://docs.krita.org/en/general_concepts/file_formats/file_ora.html).

**Mouvement :** un montage 2D dans Godot conserve les poses, transformations et changements de dessin dans une chronologie éditable. Commencer avec des pièces rigides et quelques remplacements ; n’ajouter des déformations souples que lorsqu’elles améliorent un contour précis. La documentation décrit le mélange cutout/dessins, mais porte un avertissement de mise à jour pour 4.7 : le parcours retenu doit donc être vérifié dans la version du projet. [Godot — R12](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html).

**Livraison initiale :** exporter des images complètes et leurs métadonnées pour réutiliser les lecteurs existants. Cette sortie réduit les changements nécessaires dans le jeu pendant la preuve artistique. Une lecture des pièces en temps réel pourra suivre si les mesures de mémoire ou les besoins de personnalisation la justifient ; elle n’est pas un préalable au premier héros.

Le contrat minimal comprend l’identifiant des pièces, le côté anatomique, la direction, le pivot au sol, l’ordre de dessin, la durée et les événements utiles au gameplay. Le cadrage reste commun aux images d’un même geste. Une action très ample peut utiliser un cadre plus grand en conservant la taille du corps et son pivot logique.

**Premier contrôle indispensable :** retoucher une seule pièce, l’exporter, reconstruire la séquence et constater son changement aux bons endroits, sans déplacer le personnage ni modifier les pièces intactes. Le contrôle doit porter sur les fichiers réellement relus et les images réellement affichées. Ce passage reste à implémenter et à tester.

## 7. La pipeline proposée, dans l’ordre

| Étape | Travail | Condition de passage |
| --- | --- | --- |
| 0. Vérifier le circuit de correction | Sur une copie d’essai, prouver la retouche d’une pièce et son retour dans une séquence. | Le fichier modifié est bien la source ; les éléments intacts restent inchangés. |
| 1. Choisir la silhouette | Trois propositions peu détaillées, trois fonds, plusieurs tailles voisines. | Une direction est retenue pour sa lecture en jeu et son identité adulte. |
| 2. Éprouver le dessin | Jambe fléchie, bras levé, buste tourné ; simples poses de construction. | Les volumes, attaches et parties cachées ont une solution dessinée. |
| 3. Ébaucher la marche principale | Poses du corps entier, contacts et passages, rythme lisible sans effets. | Le mouvement paraît ordinaire et coordonné avant le nettoyage. |
| 4. Construire les pièces utiles | Extraire les formes réutilisables des besoins de l’ébauche ; dessiner les substitutions nécessaires. | La construction retrouve les poses choisies sans les dégrader. |
| 5. Finaliser cette direction | Corriger silhouettes, intervalles, pieds et mouvement secondaire ; comparer les exports. | La marche fonctionne à vitesse réelle, sur place et en déplacement. |
| 6. Décliner la même marche | Reprendre successivement les trois autres angles avec les mêmes proportions. | Les quatre directions sont revues et corrigées avant toute autre animation. |
| 7. Produire l’idle et les transitions | Repos vivant, départ, arrêt et changement de direction. | Le personnage rejoint une pose intentionnelle au lieu de se figer au milieu d’un pas. |
| 8. Éprouver l’expressivité | Une action ample, puis ses quatre vues, avec effets séparés. | Le geste est identifiable sans effets et reste cohérent avec la locomotion. |
| 9. Éprouver l’équipement | Un accessoire simple, ses attaches et ses masquages sur les gestes existants. | L’ajout n’oblige pas à reconstruire tout le personnage. |

Pour la marche, les contacts, compressions, passages et remontées des deux demi-pas donnent une grille de lecture. Ce ne sont pas huit images à accepter aveuglément : les genoux, le bassin et les bras doivent raconter le même mouvement. Le guide de squelette peut aider à placer les appuis, tandis que les silhouettes peintes restent l’autorité de la revue artistique.

Le premier montage pourra comparer un échantillonnage de 12 et 24 images par cycle, avec une durée identique. Ce sont des variantes d’essai, pas des seuils de qualité. Les dessins particuliers sont ajoutés aux endroits où le mouvement le demande ; exporter 60 transformations du même mauvais pied n’apporte pas cette information.

Une première action expressive sans arme peut être une impulsion de paume : légère compression, rotation du buste, extension, récupération. Elle vérifie davantage que la marche sans cumuler immédiatement un arc transformable, une longue lance et un bouclier. Le choix précis du sort reste lié au gameplay. Les gestes spectaculaires suivants peuvent utiliser des dessins entiers particuliers lorsque le découpage n’est plus avantageux.

## 8. Les critères de qualité et leurs preuves

La vérification technique et l’acceptation artistique restent séparées. Une animation est examinée à vitesse normale et à taille de jeu avant l’analyse au ralenti. Une version peut être techniquement livrable tout en restant artistiquement refusée.

| Point contrôlé | Preuve attendue | Ce qui ne suffit pas |
| --- | --- | --- |
| Identité | Comparaison aux vues du modèle : proportions, visage, costume et côtés. | Un nom de fichier identique. |
| Appuis | Observation des semelles dessinées en translation sur un sol fixe ; suivi local lorsque fiable. | La stabilité des marqueurs générés par le même modèle. |
| Volume | Contours des mains, genoux, pieds et torse aux poses extrêmes et aux passages. | Une longueur d’os constante. |
| Profondeur | Bras, jambes, costume et accessoires dans l’ordre attendu pour chaque pose. | Un ordre de calques unique pour tout le geste. |
| Boucle et rythme | Plusieurs cycles consécutifs ; raccord, alternance et absence d’accélération parasite. | Une différence moyenne de pixels faible. |
| Transitions | Arrêts à plusieurs phases, départs, virages, interruption d’action et retour au repos. | Une boucle qui tourne seule. |
| Intégration | Caméra, grille, tri visuel, cibles et événements réels. | Le laboratoire navigateur seul. |
| Correction | Une modification isolée propagée aux images concernées, avec comparaison avant/après. | Un fichier marqué « éditable ». |

Lorsqu’une mesure de glissement est utilisée, elle doit préciser le point suivi, les images couvertes et la taille d’affichage. Un suivi perdu n’est pas extrapolé. Le roulement du pied exige aussi de distinguer le talon, la pointe et le contact effectif ; leur rôle change pendant un pas.

Les défauts sont classés en trois groupes : bloquants pour le jeu, visibles à taille normale, et visibles seulement à l’agrandissement. Le premier groupe empêche l’intégration ; le second empêche l’acceptation artistique ; le troisième se traite selon son coût et sa visibilité réelle. Les problèmes de main inversée ou de pied traversant le sol restent prioritaires même si un effet les masque momentanément.

## 9. Volumes de production et mémoire

**L’unité de coût utile est l’animation acceptée dans ses quatre vues, corrections comprises.** Un sort n’exige pas toujours un nouveau geste : certaines variantes peuvent partager le corps et modifier les effets ou le rythme. À l’inverse, un même geste peut demander plusieurs dessins nouveaux pour une vue de dos.

| Périmètre | Volume à examiner | Sens de ce nombre |
| --- | --- | --- |
| Une marche | 4 clips directionnels | Premier mouvement complet, aucune preuve sur les sorts. |
| Marche, idle, une action | 12 clips directionnels | Premier ensemble pour juger locomotion et expressivité ; transitions à compter séparément. |
| Huit familles de mouvements | 32 clips directionnels | Hypothèse de premier kit étoffé, sans huit skins ni huit morphologies. |
| Trois héros, huit familles chacun | 96 clips directionnels avant réutilisation | Exemple de charge de revue, pas 96 animations nécessairement dessinées de zéro. |

La personnalisation ne fait pas disparaître la revue. Trois apparences sur 32 clips créent jusqu’à 96 combinaisons à examiner, même si le mouvement est partagé. Une validation par familles représentatives peut réduire les répétitions une fois les règles éprouvées ; ce raccourci ne doit pas être supposé fiable dès le premier accessoire.

Exemple de dimensionnement, indépendant des studios : 24 images de marche × 4 directions × 384 × 384 pixels RGBA correspondent à **54 Mio** non compressés. À 768 × 768 et 60 images par direction, le total est **540 Mio**. Ces nombres ne mesurent ni les PNG sur disque ni la mémoire réellement utilisée par Godot.

Un scénario illustratif de 6 images d’idle, 24 de marche et 8 pour une action, dans quatre directions à 384 × 384, donne 152 images et **85,5 Mio** de pixels. Il exclut les transitions, effets, marges, mipmaps et doublons éventuels. Il sert à comprendre les ordres de grandeur, pas à imposer ces nombres de dessins.

Avant d’étendre le kit, comparer plusieurs définitions de sortie au plus grand zoom utilisé, puis mesurer le chargement et le rendu du héros accompagné d’ennemis représentatifs. Recadrer les images peut économiser de l’espace à condition de conserver les offsets et le pivot. Le passage à un rendu par pièces se décide sur ces mesures et sur les variations d’apparence réellement demandées.

## 10. Progression et effort réaliste

Aucun temps fiable par personnage ne peut encore être annoncé. Les durées des essais précédents mélangent recherche, attente de génération, installation, réglages et corrections. Un décompte des appels ou une estimation à partir du nombre de PNG donnerait une précision trompeuse.

| Palier | Résultat exigé | Ce qu’il autorise ensuite |
| --- | --- | --- |
| A. Dessin maîtrisable | Un design lisible et trois poses de construction convaincantes ; retouche réinjectée. | Investir dans la marche. |
| B. Locomotion | Marche dans les quatre directions, puis idle et transitions acceptés. | Investir dans une action expressive. |
| C. Premier héros pilote | Une action ample dans quatre vues et un accessoire compatible. | Estimer un premier kit avec les coûts réellement observés. |
| D. Kit entretenable | Familles de gestes utiles, événements corrects, corrections locales répétables. | Produire un deuxième personnage de morphologie proche. |
| E. Réutilisation prouvée | Deuxième personnage construit plus simplement, sans perte de qualité. | Formaliser une famille de personnages et élargir progressivement. |

Pour chaque palier, noter le temps actif de dessin et d’animation, l’attente des outils, le nombre de corrections, les coûts externes effectivement connus et la cause des rejets. La comparaison utile est celle de deux tâches semblables et acceptées. Une génération rapide suivie de longues réparations n’est pas un gain de production.

Le premier héros doit absorber un investissement raisonnable dans la méthode, mais ne doit pas devenir le prétexte à un éditeur généraliste. Trois améliorations techniques ont une justification immédiate : retour de retouche fiable, changements de dessin dans la chronologie, revue sur les vrais décors. Les outils supplémentaires attendent un défaut concret et répété.

## 11. Outils retenus et dépendances

**Choix principal : Krita pour le dessin, Godot pour la mise en mouvement et la revue, SpriteWorkshop et les assembleurs existants pour les sorties.** Le montage doit rester assez simple pour être inspecté, corrigé par fichiers et repris dans l’éditeur. Son fonctionnement complet est le premier essai technique à démontrer.

| Outil ou procédé | Place dans la pipeline | État et condition |
| --- | --- | --- |
| ImageGen | Concepts, ébauches et dessins de remplacement ciblés. | Déjà utilisé. Chaque sortie reste un candidat, avec contrôle des proportions et du fond. |
| Krita / OpenRaster / PNG | Source de peinture et échange des pièces. | Des fichiers existent ; le retour vers le générateur doit être complété. |
| Godot | Chronologie, scène de revue, gameplay et export contrôlé. | Moteur 4.7.1 identifié ; le nouveau montage mixte reste à tester. |
| SpriteWorkshop | Comparaison, placement, durée et export de dessins existants. | Fonctionnel dans le projet ; ne crée pas de nouvelles poses crédibles. |
| Blender | Guide ponctuel d’angle, d’appui ou de mouvement. | Essais existants. À utiliser lorsqu’il facilite une décision dessinée. |
| Spine | Option si le montage Godot devient trop coûteux à corriger. | La trial ne constitue pas un outil de livraison. Licence et compatibilité devront être réglées avant adoption. |
| Animate | Référence historique de l’atelier Ankama et Klei. | Son adoption ajouterait une dépendance ; pas retenu pour ce premier pilote. |

La configuration locale de l’essai Spine mentionne des données/runtime 4.2, un éditeur trial observé en 4.3.26 et un paquet Godot 4.6.1, alors que le projet cible 4.7.1. **Ce relevé ne constitue pas une chaîne de production homogène validée.** Esoteric impose la correspondance majeure/mineure entre l’éditeur exporteur et le runtime ; la compatibilité du paquet Godot doit aussi être vérifiée. [Configuration du projet](../../../tools/spine_trial/toolchain.json), [versions — R13](https://uk.esotericsoftware.com/spine-versioning), [runtime Godot — R14](https://us.esotericsoftware.com/spine-godot).

Les restrictions de sauvegarde/export de Spine Trial et le mode maintenance d’Animate sont des contraintes pratiques. Elles ne prouvent pas qu’un logiciel serait incapable de produire le rendu souhaité. Le choix actuel vise un circuit testable avec les ressources déjà présentes. [Spine Trial — R15](https://us.esotericsoftware.com/spine-download), [Animate — R16](https://helpx.adobe.com/animate/desktop/kb/maintenance-mode.html).

## 12. Limites de l’automatisation et règle d’arrêt

La génération peut accélérer l’exploration et certaines poses fortes. Elle ne donne pas encore, dans les essais du projet, un personnage complet dont chaque correction est locale, prévisible et bon marché. Le kit initial apprécié prouve un potentiel expressif ; il ne prouve pas cette maîtrise de la maintenance.

La recherche Sprite Sheet Diffusion propose de combiner référence visuelle, guide de pose et traitement temporel. Sa page de projet consultée affiche encore une rubrique de résultats à compléter. Ni cette publication ni une démonstration commerciale ne valent validation sur Catabase. Aucun nouvel entraînement ou benchmark de modèle n’a été réalisé dans cet audit. [Publication et projet — R17](https://arxiv.org/abs/2412.03685), [page des auteurs — R18](https://chenganhsieh.github.io/spritesheet-diffusion/).

**Règle proposée : après deux corrections ciblées sans progrès visible sur le même défaut, arrêter cette approche pour la pièce concernée.** Examiner alors un remplacement dessiné, une pose plus simple, une autre construction ou une intervention artistique ciblée. Ce seuil sert à éviter une boucle de retouches improductive ; il ne déclare pas la tâche impossible.

Une intervention extérieure utile aurait un périmètre précis : une feuille de construction, une marche principale avec ses sources ou la correction de quelques passages difficiles. Le devis devrait inclure les fichiers modifiables et la manière de les réutiliser. Le coût et l’intérêt restent à établir ; aucune prestation n’est engagée ici.

Les observations peuvent être conservées durablement sous forme de références commentées, de défauts et de corrections acceptées. Elles améliorent la continuité du travail. Elles ne modifient pas les poids du modèle et ne créent pas automatiquement une compétence d’animateur. La bibliothèque doit contenir des cas utiles et vérifiés, plutôt qu’une accumulation d’images non analysées.

## 13. Décisions de départ

La cible est un héros original adulte, au dessin simplifié inspiré du Dofus 2 sélectionné, adapté aux décors actuels. Le premier périmètre comprend une morphologie, quatre directions, une marche puis un idle avec transitions, une action expressive et un accessoire témoin. Les autres gestes restent séquentiels.

La construction commence par le besoin de pose. Le dessin et la chronologie ont des sources distinctes et corrigeables ; les exports initiaux réutilisent la voie sprites du projet. Les transformations ne remplacent pas systématiquement les nouveaux dessins. Les effets sont réglés après la lecture du corps.

Le prochain travail concret comporte deux preuves : un retour de retouche fiable sur une copie d’essai, puis une planche de silhouettes originales sur les décors. L’acceptation d’une silhouette précède le nettoyage de ses poses. Un résultat réussi doit améliorer à la fois l’apparence en jeu et la facilité de la correction suivante.

Cette décision conserve les ressources historiques sans attribuer à Passe-rive un statut de référence finale. Elle ne promet ni un studio Ankama automatisé, ni une bibliothèque entière obtenue en quelques générations. Elle propose un chemin dont les progrès et les limites peuvent être observés avant d’augmenter le périmètre.

## 14. Éléments visuels examinés

Parmi les cinq planches Dofus 2 sélectionnées, les personnages coiffés de cactus permettent de comparer plusieurs orientations. Cette étude de formes ne prouve pas une animation humanoïde complète. [Voir la planche chez l’auteur](https://mir-s3-cdn-cf.behance.net/project_modules/max_1200/dc7df055966955.599b0f7e84b5b.jpg).

Les diapositives Klei montrent la bibliothèque de poses et la séparation du personnage en pièces. Ces exemples donnent une méthode de construction ; ils ne mesurent pas notre capacité à la reproduire. [Présentation originale](https://media.gdcvault.com/GDC2014/Presentations/Agala_Jeff_2D_Animation_at.pdf).

Les captures locales ci-dessous sont des preuves historiques examinées pour l’audit. Elles ne représentent pas de nouvelles animations ou un nouveau design.

![Marche V2 : huit poses extraites du cycle, pièces fixes et formes du pied à examiner.](../../../artifacts/spine_trial/passe_rive_walk_unarmed_v2/E_poses.jpg)

![Laboratoire Godot de la marche V2 : forêt historique, différente des lieux émeraude actuels.](../../../artifacts/spine_trial/passe_rive_walk_unarmed_v2/godot_walk_E.png)

Le titre émeraude et le temple du Serment ont également été examinés. Leurs grandes zones de valeurs, contours et couleurs constituent une référence de raccord. La compatibilité du nouveau personnage avec ces décors reste à démontrer par une composition et un essai jouable.

## 15. Sources et portée

Consultation et audit du dépôt : 12 septembre 2026. Les dates de publication anciennes décrivent des pratiques attestées à cette époque ; elles ne sont pas présentées comme un inventaire actuel exhaustif. Les documents Dofus 3 déjà examinés dans le premier audit restent accessibles dans le cache de recherche du projet. Le direct officiel du 6 juin 2024 n’a pas été analysé intégralement et n’est pas utilisé pour combler les détails manquants.

1. **R1 — Julien Druant.** [DOFUS Character Design Sprites](https://www.behance.net/gallery/55966955/DOFUSCHARACTER-DESIGN-SPRITES), 31 août 2017. Présentation de l’auteur et sélection de cinq planches examinées ; pas d’examen exhaustif de tout le portfolio.
2. **R2 — Dofus Mag / Julien Druant.** [Sprites & Interview](https://www.behance.net/gallery/55601787/DOFUSMAG-SPRITES-INTERVIEW), entretien de 2014, HS10, pages 58–61. Source historique conservée dans le premier audit.
3. **R3 — Julien Druant.** [Charte personnages Dofus 3](https://www.behance.net/gallery/251142101/charte-graphique-pour-les-personnages-Dofus-3). Date interne non établie ; planches examinées précédemment.
4. **R4 — Julien Druant.** [Charte Graphique et Outils de Production](https://www.behance.net/gallery/251141703/Charte-Graphique-et-Outils-de-Production). Gabarits publics examinés ; fichiers de travail internes non obtenus.
5. **R5 — Nicolas Détrain.** [Dofus Unity, Universal Puppet/Rig](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation). Témoignage de production ; schéma complet du rig et exporteur inconnus.
6. **R6 — Jeff Agala et Aaron Bouthillier, Klei.** [2-D Animation at Klei Entertainment](https://media.gdcvault.com/GDC2014/Presentations/Agala_Jeff_2D_Animation_at.pdf), GDC, 19 mars 2014. Texte des diapositives et pages pertinentes examinés ; les vidéos intégrées ne sont pas toutes présentes dans le PDF.
7. **R7 — Kevin, Klei.** [What animation technique is used in Don’t Starve?](https://gamedev.stackexchange.com/questions/44319/what-animation-technique-is-used-in-dont-starve), réponse du 3 décembre 2012. Intervention directe du programmeur/designer, distincte des réponses spéculatives du fil.
8. **R8 — Thomas Vasseur, Motion Twin.** [Art Design Deep Dive: Using a 3D pipeline for 2D animation in Dead Cells](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-), 25 janvier 2018. Témoignage direct sur les outils, les poses et les reprises.
9. **R9 — Chris Bourassa, Red Hook.** [A Torch in the Dark](https://media.gdcvault.com/gdc2016/Presentations/Bourassa_Chris_a%20torch%20in.pdf), GDC 2016. Direction créative, choix de présentation et réductions de périmètre ; aucun détail de runtime déduit.
10. **R10 — Romain « Sephy » Pergod.** [Nindash, bilan de production](https://sephyka.com/game-post-mortem/ankama-nindash/). Production 2017 et sortie 2018 ; date de rédaction non établie.
11. **R11 — Krita.** [Format OpenRaster](https://docs.krita.org/en/general_concepts/file_formats/file_ora.html). Documentation 5.3.0, format d’échange des calques.
12. **R12 — Godot.** [Cutout animation](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html). Documentation stable, avec avertissement de mise à jour pour 4.7.
13. **R13 — Esoteric Software.** [Spine versioning](https://uk.esotericsoftware.com/spine-versioning). Règle de correspondance éditeur/runtime.
14. **R14 — Esoteric Software.** [Spine-Godot runtime](https://us.esotericsoftware.com/spine-godot). Documentation évolutive d’intégration.
15. **R15 — Esoteric Software.** [Spine Trial Download](https://us.esotericsoftware.com/spine-download). Restrictions de la trial, déjà vérifiées dans le premier audit.
16. **R16 — Adobe.** [Animate maintenance mode](https://helpx.adobe.com/animate/desktop/kb/maintenance-mode.html). Politique consultée pour le choix de dépendances.
17. **R17 — Cheng-An Hsieh, Jing Zhang et Ava Yan.** [Sprite Sheet Diffusion](https://arxiv.org/abs/2412.03685), décembre 2024, révision du 16 mars 2025. Proposition de recherche ; aucun benchmark local réalisé.
18. **R18 — Les mêmes auteurs.** [Page du projet](https://chenganhsieh.github.io/spritesheet-diffusion/). Description de l’architecture et rubrique de résultats à compléter à la consultation.

Les sources, rapports et illustrations locales sont liés au fil du dossier. Leurs résultats historiques ne sont pas des tests nouvellement exécutés. Les créations des studios servent à l’étude ; les ressources de production de Catabase doivent rester originales et leurs droits d’usage traçables.
