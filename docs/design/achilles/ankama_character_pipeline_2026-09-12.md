# Production des personnages chez Ankama

**Audit initial conservé.** Le [dossier consolidé de faisabilité](ankama_character_feasibility_2026-09-12.md) précise la cible Dofus 2 adaptée à Catabase, les capacités démontrées, les limites du retour de retouche et la pipeline retenue. Ses décisions priment sur les recommandations générales ci-dessous.

La production de personnages chez Ankama repose sur un ensemble de décisions compatibles : identité visuelle, formes animables, bibliothèque de mouvements, équipements, contraintes du moteur et revues artistiques. Les sources publiques permettent de reconstituer cette organisation et plusieurs de ses mécanismes concrets. Elles ne donnent pas accès à l’ensemble des fichiers sources, des exporteurs ni des règles internes actuelles.

**La recommandation pour Dungeon Draft est de construire un personnage 2D éditable, éprouvé en mouvement et sur la carte avant de décliner son kit.** La génération d’images peut participer à la recherche visuelle. Le dessin de production, les poses, les changements de vue et les corrections doivent ensuite rester contrôlables séparément.

## 1. Périmètre et niveau de certitude

La référence principale est **Dofus 3, issu du portage sur Unity**. L’annonce officielle situe ce passage au 3 décembre 2024. Les témoignages sur Dofus 2 sont utiles pour comprendre les problèmes hérités, mais ne décrivent pas automatiquement le système actuel. [Ankama, préinscriptions Dofus 3.0 — S11](https://support.ankama.com/hc/fr/articles/29422009505937--DOFUS-DOFUS-3-0-pr%C3%A9-inscriptions).

Trois catégories sont distinguées dans ce dossier : **documenté** désigne une explication d’Ankama, d’un intervenant de la production ou de l’éditeur d’un logiciel ; **analyse** désigne une conclusion tirée de ces informations ; **proposition** désigne une méthode conçue pour Dungeon Draft. Une démonstration publiée atteste un exemple, pas tous les cas du jeu.

| Production | Information établie | Limite de transposition |
| --- | --- | --- |
| Dofus 2 | Dessin vectoriel, production de sprites et contraintes de grille décrits en 2014. [S3](https://www.behance.net/gallery/55601787/DOFUSMAG-SPRITES-INTERVIEW) | Témoignage historique ; budgets actuels inconnus. |
| Dofus 3 | Refonte de la marionnette commune et des animations joueurs. [S4](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation) | Exporteur et lecteur interne non documentés complètement. |
| Waven | Animation dans Animate, croquis de poses puis essai dans le moteur. [S7](https://fr.linkedin.com/in/christophe-bulteel-88580066) | Témoignage de la phase alpha ; ne fixe pas toute la pipeline actuelle. |
| Nindash | Séquences PNG et marionnette dans Unity suivant le besoin. [S8](https://sephyka.com/game-post-mortem/ankama-nindash/) | Petit jeu mobile, mouvements et échelle différents. |
| BESTIALE | Harmony, dessin, rigs et quelques éléments 3D combinés selon les plans. [S18](https://www.toonboom.com/fr/studio-unagi-sur-la-combinaison-de-lanimation-traditionnelle-et-de-lanimation-avec-marionnettes-dans-bestiale) | Série animée réalisée avec Studio Unagi ; aucune preuve du runtime Dofus. |
| Wakfu, jeu et série | Deux productions à traiter séparément. | Une compétence citée pour la série ne suffit pas à identifier les outils du jeu. |

## 2. Conception et charte graphique

**Documenté.** Dans la charte publiée pour Dofus 3, Julien Druant privilégie des formes lisibles à taille réelle, des courbes synthétiques et une construction isométrique. Les contours sont discrets : 30 % d’opacité dans la règle présentée, avec des exceptions. L’éclairage s’adoucit en descendant sur le corps ; les dégradés remplacent les ombres découpées trop dures, avec des couleurs moins agressives. Le parcours illustré va du croquis au vectoriel, à la comparaison à 100 %, aux couleurs, à la revue artistique, au dos puis à la fiche d’animation. [Charte personnages — S1](https://www.behance.net/gallery/251142101/charte-graphique-pour-les-personnages-Dofus-3).

**Analyse.** « Ressembler à Dofus » est une consigne trop imprécise. Le Dofus de différentes époques ne propose pas exactement les mêmes proportions, contours ou ombres. Des images choisies sans période ni fonction commune peuvent donc se contredire. Une illustration promotionnelle et un personnage vu sur une case ne répondent pas au même besoin de lecture.

**Documenté.** Lors de recherches présentées en 2018, Druant explique vouloir des personnages plus mûrs, cohérents avec le Krosmoz, tout en prévoyant les conséquences sur les objets, montures, émotes et déplacements. Il présente alors des recherches, pas une refonte déjà déployée. [Entretien direct — S20](https://www.millenium.org/news/287947.html).

**Proposition pour le nouveau personnage.** Préparer une courte charte propre à Dungeon Draft : silhouette adulte, niveau de simplification, traitement du visage, taille visible des mains et des pieds, palette et hiérarchie de lumière. Les références Dofus servent à étudier la fabrication ; les décors émeraude et l’écran titre fixent l’appartenance à notre univers.

Le premier livrable doit montrer le personnage sur trois fonds réels : une zone sombre, une zone claire et une zone chargée en détails. La taille de jeu est la référence principale, accompagnée d’un agrandissement pour inspecter les contours. Une grande image séduisante ne décide pas seule de la qualité du design.

## 3. Silhouette, vues et préparation animable

**Documenté.** Dans Dofus Mag, Druant relie la simplification des sprites aux contraintes de mémoire du dessin vectoriel. Il explique aussi que la silhouette doit préserver la possibilité de cibler les cases voisines. Son retour sur le passage à Dofus 2 décrit une production initialement disparate, suivie d’un travail d’unification. L’ajout de visages a notamment demandé de reprendre le placement des chapeaux. [Entretien de 2014, pages 58–61 — S3](https://www.behance.net/gallery/55601787/DOFUSMAG-SPRITES-INTERVIEW).

**Analyse.** Un personnage de jeu est un objet soumis à des transformations et à des interactions. Le dessin doit définir ce que devient un genou plié, une main vue de dos, un buste tourné ou une capuche au-dessus d’une épaule. Une seule vue terminée laisse toutes ces décisions en suspens.

Le « squelette » 2D doit être compris comme une organisation de pièces et de contrôles. Il peut guider une animation sans contenir une anatomie 3D complète. Une pièce peut changer de dessin pendant le geste ; une main n’a pas à conserver la même silhouette par simple rotation.

**Proposition.** La source du nouveau personnage comportera une vue principale trois-quarts, les autres vues utiles, une feuille de proportions et une bibliothèque de substitutions. Pour commencer : paume ouverte, poing, prise d’arme ; pied posé, pied en poussée, pied en retour ; buste neutre et buste tourné. Ces éléments seront dessinés selon les besoins réellement rencontrés, sans fabriquer une immense bibliothèque à l’avance.

Le fichier de travail doit aussi contenir les parties momentanément cachées : dessous de manche, jonction cou/torse, haut de cuisse et arrière du costume. Le résultat attendu est une articulation qui reste dessinée convenablement quand elle s’ouvre. La simple présence d’un pixel opaque près du joint ne constitue pas un contrôle artistique suffisant.

## 4. Marionnette commune et personnalisation

**Documenté.** Nicolas Détrain décrit une perte progressive de compatibilité entre les apparences et la marionnette commune de Dofus. Des différences morphologiques entre classes et sexes imposaient des ajustements manuels récurrents. Il indique avoir dirigé et réalisé une refonte du rig universel nécessitant de recréer les animations des personnages joueurs, en lien avec le game design pour préserver identité des classes et lisibilité. [Présentation du projet — S4](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation).

**Analyse.** La réutilisation dépend d’un contrat de compatibilité. Elle fonctionne tant que les pièces partagent les repères, proportions admissibles et comportements attendus. Ajouter librement une longueur de bras ou une cape ne coûte pas seulement un dessin : cela peut affecter tous les gestes qui utilisent cette partie.

Il faut également distinguer un héros personnalisable et une créature unique. Le premier bénéficie d’une base commune stable ; la seconde peut justifier des proportions et une animation spécifiques. Chercher immédiatement une marionnette capable de tout faire ferait porter au premier personnage le coût d’un système destiné à des dizaines d’archétypes.

**Documenté.** La charte présente un système ColorGray : un gris de base `#808080` et des variations de valeur ou de température servent à préparer la recoloration. Les planches montrent cinq emplacements. Cela décrit le document publié, pas nécessairement le nombre d’options du client actuel. [Annexe ColorGray — S1](https://www.behance.net/gallery/251142101/charte-graphique-pour-les-personnages-Dofus-3).

**Proposition.** Le premier personnage doit définir un seul gabarit réutilisable. Une variante de couleur et un accessoire amovible suffiront à tester la séparation entre identité, animation et apparence. Si modifier un gant exige de refaire toutes les poses du visage, le système n’est pas prêt à être étendu.

## 5. Équipements et ordre d’affichage

**Documenté.** Les gabarits publiés pour les équipements Dofus 3 indiquent des origines communes de clips, un ordre de calques, des pièces avant/arrière et des règles de visibilité. Les exemples couvrent cinq vues de l’objet et un contrôle sur personnage à 100 %. Ils séparent notamment masque, barbe et coiffure. Les capes sont divisées en parties haute et basse ; un sac dispose d’un clip distinct pour éviter l’étirement qu’il subissait avec le tissu. Des gabarits existent pour les boucliers, ailes et sacs, avec des icônes en 120 × 120 et 60 × 60 dans l’exemple final. Le document demande aussi de contrôler les accessoires en animation. [Charte et outils de production — S2](https://www.behance.net/gallery/251141703/Charte-Graphique-et-Outils-de-Production).

**Analyse.** Un équipement est donc susceptible de modifier plusieurs choses à la fois : formes visibles, éléments cachés, attache et superposition. Une capuche peut cacher une coiffure tout en conservant le visage. Un bouclier doit montrer son revers lorsqu’il tourne. Ces relations expliquent pourquoi superposer une image complète d’accessoire à un personnage peut fonctionner en pose neutre puis échouer dès le premier geste.

**Proposition.** Pour Dungeon Draft, chaque accessoire aura une fiche simple : emplacement d’attache, dimensions admises, vues, éléments à masquer, zones rigides et zones souples. Un tissu et une pièce de métal ne partageront pas automatiquement la même déformation. Les mains anatomiques seront conservées d’une direction à l’autre ; un miroir sera autorisé seulement lorsque l’asymétrie du dessin le permet réellement.

Le nouveau personnage peut commencer sans arme et sans longue cape. Cela rend la lecture des appuis plus facile. Un accessoire témoin sera ajouté après le premier mouvement accepté pour prouver la compatibilité, avant de multiplier les équipements.

## 6. Animation : intention, poses et correction

**Documenté.** Le recrutement Waven relayé par Christophe Bulteel décrit explicitement une suite : petits croquis préparatoires, poses principales, animation dans Animate, puis test dans le moteur avant intégration. Le travail concerne des personnages 2D en perspective isométrique. [Témoignage de production — S7](https://fr.linkedin.com/in/christophe-bulteel-88580066).

**Documenté sur l’outil.** Animate organise des symboles réutilisables et leurs instances ; les symboles peuvent contenir leur propre animation. Sa chronologie permet de modifier le contenu sur des images clés et de régler les intervalles. Ces possibilités expliquent comment combiner pièces stables et dessins particuliers, sans établir les conventions exactes d’Ankama. [Symboles — S12](https://helpx.adobe.com/animate/desktop/multimedia-and-video/symbols.html), [images clés — S13](https://helpx.adobe.com/animate/desktop/animation/frames-keyframes.html).

**Analyse.** La fluidité et la qualité du mouvement sont liées mais distinctes. Un affichage très fréquent peut rendre une mauvaise trajectoire parfaitement lisse. Une animation lisible dépend aussi de la pose du corps entier, du rythme, du transfert de poids et de la variation des silhouettes.

Les GIF de marche publiés par Détrain donnent une référence visuelle des passages de jambes et du comportement de l’équipement. L’étude locale a trouvé une répétition exacte de 16 images avec des délais de 30 ms, soit 480 ms dans deux GIF. **Ces valeurs décrivent les fichiers publiés ; elles ne prouvent ni la cadence du jeu ni le nombre de dessins originaux.** [Portfolio — S4](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation), [comparatif local](http://127.0.0.1:8734/files/dofus_motion_study/review.html).

**Proposition pour une marche ordinaire.** Commencer par les poses de contact, compression, passage et remontée des deux demi-pas. Regarder la silhouette entière, puis établir les appuis et le déplacement. Revoir ensuite les bras, le buste, la tête et le costume ensemble. L’amplitude doit correspondre à une marche quotidienne, et non à un défilé ou une course ralentie.

Les rotations suffisent pour certaines transitions ; un changement de dessin est préférable lorsqu’une forme se retourne ou se raccourcit fortement en perspective. Ajouter des os pour éviter de dessiner un pied ne résout pas nécessairement le problème. Le critère est le contour obtenu à l’écran.

**Proposition pour les gestes complexes.** Définir une anticipation, une action reconnaissable et une récupération. Le corps doit rendre le geste compréhensible avec les effets désactivés. Ensuite seulement, la traînée, le flash ou les particules renforcent l’intention. Les directions de dos nécessitent une mise en scène lisible : recopier les déplacements de la vue de face peut masquer le geste derrière le buste.

## 7. Export, moteur, effets et performance

**Documenté pour Dofus 2.** Dans un entretien de 2019, le producer Logan identifie Tiphon comme le module chargé des animations et évoque optimisation des ressources graphiques et mise en cache. Cette référence historique ne démontre pas que Dofus 3 utilise un outil public portant le même nom. [Entretien direct — S10](https://dofus.jeuxonline.info/actualite/56783/interview-quinzaine-logan-producer-dofus).

**Documenté pour Animate.** Adobe distingue l’export d’images complètes d’une animation et un atlas accompagné de données permettant de reconstruire celle-ci. Le second peut réutiliser les textures uniques ; il nécessite un lecteur compatible. La documentation décrit notamment `Animation.json`, `spritemap.json` et `spritemap.png`. **C’est une capacité d’Adobe, pas la preuve du format d’export d’Ankama.** [Documentation export — S14](https://helpx.adobe.com/animate/desktop/exporting-and-publishing/create-sprite-sheet.html).

**Documenté dans un autre jeu Ankama.** Pour Nindash, Sephy explique exporter de courtes animations depuis Flash vers Unity en spritesheets. Il évoque ensuite l’animation de boss directement dans Unity. [Journal de développement, août 2017 — S9](https://openclassrooms.com/forum/sujet/jeu-mobile-nindash-skull-valley).

Son bilan précise que les grandes dimensions du premier boss rendaient la spritesheet excessive. Une marionnette a remplacé cette sortie pour ce cas. Les effets, réalisés avec un technical artist, combinaient notamment particules, shaders et animations ; le bilan décrit également le temps consacré aux finitions et aux tests. [Bilan Nindash — S8](https://sephyka.com/game-post-mortem/ankama-nindash/).

**Analyse.** Source éditable et format livré sont deux décisions séparées. Une animation fabriquée avec une marionnette peut être exportée en images ; une animation dessinée peut coexister avec des éléments animés en temps réel. Il faut choisir la sortie en fonction du coût mémoire, des variations d’apparence et de la facilité d’intégration.

| Sortie envisagée pour Dungeon Draft | Avantage | Coût à vérifier |
| --- | --- | --- |
| Images complètes par pose | Rendu prévisible, intégration simple, liberté du dessin. | Mémoire et nombre d’images augmentent avec les vues et variantes. |
| Pièces et pistes animées dans Godot | Corrections locales, accessoires réutilisables, courbes continues. | Superpositions, déformations, lecteur et coût de rendu à contrôler. |
| Mélange des deux | Dessins particuliers pour les actions difficiles, réutilisation ailleurs. | Un même contrat de pivot, temps, événements et apparence reste nécessaire. |

Exemple de dimensionnement, indépendant d’Ankama : 240 images RGBA de 768 × 768 représentent **540 Mio** de pixels non compressés. Ce calcul ne donne ni la taille PNG sur disque ni la mémoire effective après compression, découpe ou chargement partiel. Il montre pourquoi conserver la grande résolution de travail pour toutes les images livrées mérite une mesure avant extension du kit.

**Proposition d’intégration.** Le jeu doit connaître la direction, la durée, la distance d’un cycle, les transitions et les événements du geste. Pour une marche, la phase progresse avec la distance parcourue. Pour une attaque, l’instant de l’effet doit rester cohérent avec l’animation, y compris après une interruption. Le personnage doit revenir dans un état valable lorsqu’une action est annulée.

## 8. Équipe, suivi et validation

**Documenté.** L’offre officielle de lead animation pour Dofus et Waven demande d’encadrer les animateurs, définir les priorités, évaluer les livrables, suivre l’avancement et garantir les contraintes artistiques et techniques. Elle cite le travail avec les character designers et game designers et demande une maîtrise particulière d’Animate. Elle distingue les chartes des deux jeux. [Offre Ankama — S6](https://recrutement.ankama.com/jobs/7446962-lead-animateur-trice-2d).

Détrain décrit pour Dofus 3 un rôle de liaison entre dessin, développement et game design. Son profil distingue son expérience Flash/Animate chez Ankama de l’adoption ultérieure de Spine chez Triskell. **Ce CV ne prouve pas l’emploi de Spine pour Dofus.** [Profil professionnel — S5](https://www.malt.com/profile/nicolasdetrain).

**Analyse.** L’organisation protège la cohérence lorsqu’une décision traverse plusieurs métiers. Le dessinateur ne livre pas un objet impossible à animer ; l’animateur ne transforme pas involontairement son identité ; l’intégrateur ne change pas le rythme sans contrôler la lecture du geste.

**Proposition.** Même avec une petite équipe, quatre responsabilités doivent rester explicites : direction artistique, dessin de production, animation, intégration. Une fiche par animation suffit au départ. Elle contient le candidat actuel, les défauts précis, les corrections demandées et deux verdicts indépendants : fonctionnement technique et qualité artistique.

Un défaut doit être localisable : « le pied proche change de longueur au passage de la pose 4 à la pose 5 » est actionnable. « Manque de fluidité » reste un symptôme à examiner. Après correction, la revue reprend à vitesse normale sur la carte, puis au ralenti pour comprendre un problème restant.

**Limite sur les outils de gestion.** CGWire affiche Ankama Animations parmi les studios associés à Kitsu. Cela ne permet pas d’affirmer que les équipes Dofus utilisent ce gestionnaire, ni de connaître leur configuration. [CGWire — S19](https://www.cg-wire.com/). Installer un gestionnaire de studio complet n’est donc pas une priorité pour ce pilote.

## 9. Enseignements des autres productions Ankama

Le cas Nindash est particulièrement utile pour comprendre la production rapide. Le bilan décrit un noyau de trois personnes, épaulé par d’autres spécialistes, sur trois mois dont un consacré aux finitions. Les actions ont été définies en fonction du gameplay ; certaines utilisaient très peu d’images. Ce choix est cohérent avec un jeu de dash, et ne fournit pas une recette de marche humanoïde. [Bilan Nindash — S8](https://sephyka.com/game-post-mortem/ankama-nindash/).

Pour BESTIALE, Guillaume Dubois décrit un mélange de dessins, rigs complets, rigs spécifiques à certains plans et éléments 3D. Les brouillons étaient transmis à Ankama puis retravaillés au fil des revues. Ce témoignage soutient une idée de production : adapter le procédé au geste peut être pertinent. Il ne démontre pas que les mêmes fichiers ou logiciels servent au jeu Dofus. [Entretien Studio Unagi — S18](https://www.toonboom.com/fr/studio-unagi-sur-la-combinaison-de-lanimation-traditionnelle-et-de-lanimation-avec-marionnettes-dans-bestiale).

**Analyse pour Dungeon Draft.** Un seul procédé n’a pas à couvrir un pas ordinaire, un tir chargé, une métamorphose et une disparition. En revanche, ces procédés doivent préserver le personnage, la perspective et les repères communs. L’hybridation est utile lorsqu’elle réduit une difficulté identifiée ; accumuler les transferts entre logiciels peut aussi rendre chaque correction plus coûteuse.

Le résultat recherché est un petit nombre de sources maîtrisées. Une action particulière peut disposer de quelques dessins dédiés sans rendre obsolète tout le système du personnage.

## 10. Diagnostic de la méthode actuelle

Les essais Passe-rive ont déjà résolu plusieurs problèmes concrets. La marche sans armes V2 conserve les mêmes pièces que la V1 et corrige notamment le transfert latéral, les longueurs des bras et la continuité du retour des pieds. Son dossier précise que les mesures concernent les repères de construction ; son acceptation artistique reste en attente. [Dossier local V2](../../../art/source/characters/achilles/passe_rive_walk_unarmed_v2/README.md).

**Analyse du projet.** Les difficultés restantes ne se résument pas au choix de Blender, Spine ou d’un générateur. Les premières étapes ont produit des images séduisantes, mais leur prolongement exigeait une représentation du personnage dont chaque partie pouvait être corrigée sans changer le reste. La fabrication des variantes, des vues et des mouvements a parfois avancé avant que ce contrat soit établi.

| Habitude à changer | Effet observé ou risque | Nouvelle règle proposée |
| --- | --- | --- |
| Choisir le design sur une image isolée | Le détail ou les proportions se lisent mal sur la map. | Comparer les silhouettes sur les décors dès la recherche. |
| Régénérer le personnage entier pour une pose | Les formes et l’identité peuvent varier. | Corriger la pièce ou la pose fautive dans une source stable. |
| Assimiler cohérence mécanique et beauté | Un mouvement régulier peut rester artificiel. | Revue des poses et du rythme indépendante des tests. |
| Ajouter des images pour corriger le mouvement | La trajectoire incorrecte devient seulement plus lisse. | Corriger d’abord poses, contacts et intervalles. |
| Généraliser le rig avant un geste accepté | Les contraintes se multiplient sans référence satisfaisante. | Prouver une animation et sa correction locale. |
| Produire plusieurs actions simultanément | Les défauts de base contaminent le kit. | Terminer une animation dans ses quatre vues avant la suivante. |

Ces changements ne garantissent pas automatiquement le niveau artistique d’une équipe expérimentée. Le point à démontrer est la qualité du dessin en mouvement. Si elle stagne malgré un montage éditable, le besoin devient une expertise d’animation ou de dessin ciblée, pas un outil supplémentaire choisi au hasard.

## 11. Contrat de production du nouveau personnage

Cette proposition est propre à Dungeon Draft. Elle conserve l’objectif d’un héros adulte, lisible, adapté à l’isométrie et capable de gestes expressifs. Son apparence définitive reste à choisir ; l’ancien Passe-rive ne constitue plus automatiquement le modèle à reproduire.

### A. Cadrage visuel

Livrer une planche de silhouettes réellement différentes, peu détaillées, posées à l’échelle sur les décors. Donner à chaque proposition une identité par les grandes masses, la posture et le visage. La planche doit permettre de choisir une direction, sans investir déjà dans des ornements ou un kit complet.

**Sortie attendue :** un design retenu et des règles lisibles sur une page. La hauteur à l’écran, le niveau de contraste et les détails qui doivent survivre à la réduction sont fixés à partir du jeu.

### B. Dessin de production

Construire la vue principale, ses pièces cachées, les substitutions nécessaires et les repères de la grille. Préparer ensuite les autres orientations avec les mêmes volumes. Conserver le dessin source, les pièces exportées et le montage ; chaque correction doit avoir un endroit précis où être faite.

**Sortie attendue :** une source qui supporte une jambe fléchie, un bras levé et un buste tourné sans trou ni perte d’identité. Ces poses de vérification ne sont pas trois nouvelles animations à produire.

### C. Une marche, puis ses quatre vues

Ébaucher le mouvement du corps entier avant de finaliser les détails. Soigner une direction en premier, puis reprendre la même marche sous les trois autres angles. Vérifier sur place, en translation sur la grille, à vitesse normale et à la frontière de boucle.

**Sortie attendue :** une marche identifiable comme ordinaire, des contacts convaincants, des passages de jambes lisibles et des silhouettes stables. Les valeurs mesurées complètent le jugement ; elles ne le remplacent pas.

### D. Idle et transitions

Produire ensuite l’idle dans les quatre vues et le relier au déplacement. Vérifier plusieurs moments de départ et d’arrêt, un virage, un changement de destination et une interruption. Le personnage doit terminer debout, au bon endroit, avec une pose intentionnelle.

**Sortie attendue :** un essai jouable marche/idle. Geler une image quelconque de la marche lors de l’arrêt ne suffit pas.

### E. Équipement témoin et action expressive

Ajouter un accessoire simple pour éprouver les attaches et les masquages. Choisir ensuite une seule action ample qui vérifie une difficulté nouvelle : rotation du buste, extension importante ou changement de silhouette. Elle passe par les mêmes quatre vues avant la suivante.

**Sortie attendue :** un personnage dont l’expressivité dépasse la marche et dont une correction locale reste possible. La bibliothèque de sorts ne s’étend qu’après cette preuve.

### F. Livraison et entretien

Conserver une source éditable, un manifeste des vues et animations, un export reproductible et une scène de revue. Distinguer le personnage, ses effets et les points d’attache, même si certaines sorties finales sont assemblées. Chaque version doit indiquer son statut : ébauche, à corriger, prête à intégrer ou acceptée.

Les contrôles portent sur les contours, volumes, orientations, attaches, ordre de dessin, appuis, temps, interruptions, mémoire et taille en jeu. Une modification de pièce déclenche la revue des gestes concernés. Une simple modification de documentation ne nécessite pas de relancer tous les tests du moteur.

## 12. Choix des outils et connaissances durables

**Recommandation immédiate.** Réutiliser les outils présents pour prouver le dessin et la qualité du mouvement. Le nouvel élément indispensable est une source artistique réellement corrigeable, accompagnée d’une revue des poses. La présence d’un serveur MCP ne constitue pas une méthode d’animation.

| Outil | Usage utile | Décision pour le pilote |
| --- | --- | --- |
| Animate | Symboles, dessin vectoriel, chronologie ; outil attesté pour Dofus/Waven. | Option la plus proche de l’atelier étudié, à évaluer sur un aller-retour source/export réel. |
| Krita | Dessins de remplacement, poses, animation image par image. | Utiliser les fonctions disponibles pour les corrections dessinées. |
| Godot | Montage 2D, lecture, effets, mesure et revue sur la carte. | Conserver comme moteur cible et lieu de validation. |
| Blender | Référence de perspective, d’appui ou de mouvement difficile. | Aide ponctuelle ; le rendu final reste une décision artistique. |
| Spine | Éditeur spécialisé de marionnettes. | Trial réservée à l’évaluation ; elle ne sauvegarde ni n’exporte la production. |
| Génération d’images | Exploration visuelle et proposition de formes. | Candidats à sélectionner et reconstruire ; contrôle des vues et corrections toujours requis. |

Les capacités de mélange pièces/dessins de Godot et d’animation raster de Krita sont documentées. La page cutout de Godot signale toutefois qu’elle n’est pas encore entièrement actualisée pour 4.7. Les détails de manipulation doivent donc être éprouvés dans la version du projet. [Godot — S16](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html), [Krita — S17](https://docs.krita.org/en/user_manual/animation.html).

Adobe indique qu’Animate reste disponible, mais en maintenance sans nouvelles fonctionnalités prévues. Il faut en tenir compte avant d’en faire une dépendance durable. La limite de sauvegarde/export de Spine Trial est confirmée par sa page de téléchargement. [Adobe — S15](https://helpx.adobe.com/animate/desktop/kb/maintenance-mode.html), [Spine — S21](https://us.esotericsoftware.com/spine-download).

**Capitalisation proposée.** Conserver une petite bibliothèque commentée : une marche, une action chargée, une rotation et un geste ample, chacun associé à un défaut précis qu’il aide à résoudre. Mémoriser les règles acceptées, les exemples refusés et leurs raisons. Cette mémoire externe reste consultable et améliore la continuité du travail ; elle ne modifie pas les poids du modèle et ne remplace pas une compétence d’animateur.

## 13. Limites documentaires

Le dessin, les gabarits, l’organisation de la personnalisation et plusieurs responsabilités de production sont documentés. Les éléments suivants restent à établir avant de prétendre reproduire leur système exact :

- Le schéma complet du rig Dofus 3, ses contrôles et sa bibliothèque de substitutions.
- Le format intermédiaire, l’exporteur, le lecteur Unity et leurs versions précises.
- Les conventions exhaustives d’événements, de transitions, de sons et d’effets.
- Les budgets actuels de texture, de géométrie, de mémoire et de performance par personnage.
- Le temps de fabrication par type de personnage et le processus complet de validation interne.
- La pipeline actuelle complète de Wakfu MMO, distincte des témoignages de la série.

Le direct officiel **Ankama Live : La direction artistique du portage sur Unity !**, du 6 juin 2024, est une référence complémentaire identifiée. Sa démonstration et sa transcription n’ont pas été analysées intégralement ici ; aucun détail interne n’est attribué à son contenu sans vérification. [Vidéo officielle — S22](https://www.youtube.com/watch?v=Y1bQVoe2Qyg).

L’absence d’un exporteur public n’empêche pas le pilote. Elle impose de qualifier la proposition comme une adaptation à Godot, et d’évaluer celle-ci sur un personnage réellement jouable. L’objectif de la première fabrication est de vérifier que le design reste beau en mouvement et que les corrections deviennent plus simples.

## 14. Sources

Sources consultées le 12 septembre 2026. Les dates ci-dessous désignent la publication ou la période du témoignage lorsqu’elles sont établies. Une date absente n’est pas déduite de la date d’indexation d’un moteur de recherche.

1. **S1 — Julien Druant.** [Charte graphique pour les personnages Dofus 3](https://www.behance.net/gallery/251142101/charte-graphique-pour-les-personnages-Dofus-3). Date de rédaction interne non établie. Planches de forme, couleur, méthode et ColorGray. Publication de l’auteur, source primaire.
2. **S2 — Julien Druant.** [Charte Graphique et Outils de Production](https://www.behance.net/gallery/251141703/Charte-Graphique-et-Outils-de-Production). Date interne non établie. Gabarits et exemples d’équipements Dofus 3, source primaire.
3. **S3 — Dofus Mag / Julien Druant.** [Sprites & Interview](https://www.behance.net/gallery/55601787/DOFUSMAG-SPRITES-INTERVIEW). Entretien recueilli par Xan et Vérol, hors-série 10, pages 58–61, 2014. Le même portfolio contient aussi des pages sur les visages portant des repères de fabrication de 2012 ; l’ensemble n’est pas un document homogène de 2014.
4. **S4 — Nicolas Détrain.** [Dofus Unity — Universal Puppet/Rig — Animation](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation). Présentation de son travail sur le portage, date interne non établie. Explication et animations publiées par l’intervenant.
5. **S5 — Nicolas Détrain.** [Profil professionnel Malt](https://www.malt.com/profile/nicolasdetrain). Page évolutive ; expériences Ankama jusqu’en septembre 2024 et Triskell à partir d’octobre 2024. Témoignage de carrière, pas documentation d’export.
6. **S6 — Ankama.** [Lead Animateur.trice 2D](https://recrutement.ankama.com/jobs/7446962-lead-animateur-trice-2d). Offre accessible à la consultation, date de publication exacte non établie. Missions pour Dofus et Waven.
7. **S7 — Christophe Bulteel.** [Publication de recrutement Waven sur son profil](https://fr.linkedin.com/in/christophe-bulteel-88580066). Phase alpha, date exacte non affichée dans le texte disponible. Source primaire relayant le travail attendu.
8. **S8 — Romain « Sephy » Pergod.** [NINDASH — How to create a mobile game in 3 months with a (core) team of 3](https://sephyka.com/game-post-mortem/ankama-nindash/). Bilan de la production 2017 et du lancement 2018 ; date de publication non établie. Auteur de la direction artistique.
9. **S9 — Romain « Sephy » Pergod.** [Journal de développement Nindash](https://openclassrooms.com/forum/sujet/jeu-mobile-nindash-skull-valley). Messages d’août 2017, notamment l’édition du 28 août sur l’animation. Témoignage direct.
10. **S10 — Logan / JeuxOnLine.** [Interview de la quinzaine avec Logan, Producer sur Dofus](https://dofus.jeuxonline.info/actualite/56783/interview-quinzaine-logan-producer-dofus). 2019. Réponses directes sur l’optimisation, dont Tiphon ; accès textuel partiel via indexation.
11. **S11 — Ankama Support.** [Dofus 3.0 : préinscriptions](https://support.ankama.com/hc/fr/articles/29422009505937--DOFUS-DOFUS-3-0-pr%C3%A9-inscriptions). Mise à jour du 26 novembre 2024. Calendrier officiel du portage.
12. **S12 — Adobe.** [Create and duplicate symbols in Animate](https://helpx.adobe.com/animate/desktop/multimedia-and-video/symbols.html). Documentation évolutive.
13. **S13 — Adobe.** [Use frames and keyframes in Adobe Animate](https://helpx.adobe.com/animate/desktop/animation/frames-keyframes.html). Documentation évolutive.
14. **S14 — Adobe.** [Export animations for mobile apps and game engines](https://helpx.adobe.com/animate/desktop/exporting-and-publishing/create-sprite-sheet.html). Mise à jour du 9 juin 2026. Formats et options Adobe ; aucune attribution automatique à Ankama.
15. **S15 — Adobe.** [Animate maintenance mode FAQs](https://helpx.adobe.com/animate/desktop/kb/maintenance-mode.html). Politique consultée en septembre 2026.
16. **S16 — Godot Engine.** [Cutout animation](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html). Documentation stable avec avertissement d’actualisation pour 4.7.
17. **S17 — Krita.** [Animation with Krita](https://docs.krita.org/en/user_manual/animation.html). Manuel 5.3.0.
18. **S18 — Guillaume Dubois, entretien par Edward Hartley / Toon Boom.** [Studio Unagi sur BESTIALE](https://www.toonboom.com/fr/studio-unagi-sur-la-combinaison-de-lanimation-traditionnelle-et-de-lanimation-avec-marionnettes-dans-bestiale). 26 juillet 2025. Témoignage direct d’un studio prestataire.
19. **S19 — CGWire.** [Présentation de Kitsu](https://www.cg-wire.com/). Page évolutive ; mention d’Ankama Animations uniquement.
20. **S20 — Julien Druant, entretien par Mathys / Millenium.** [Dofus : refonte graphique des personnages ?](https://www.millenium.org/news/287947.html). 14 février 2018. Les réponses de l’artiste sont utilisées, pas les conjectures éditoriales.
21. **S21 — Esoteric Software.** [Spine Trial Download](https://us.esotericsoftware.com/spine-download). Restrictions de la trial, documentation officielle évolutive.
22. **S22 — DOFUS / Ankama.** [Ankama Live : La direction artistique du portage sur Unity !](https://www.youtube.com/watch?v=Y1bQVoe2Qyg). 6 juin 2024. Référence complémentaire, contenu non analysé intégralement.

Les documents internes du projet cités dans le diagnostic décrivent des essais locaux. Ils ne constituent pas des preuves sur Ankama. Les créations d’Ankama restent des références d’étude ; le nouveau personnage et ses ressources seront originaux.
