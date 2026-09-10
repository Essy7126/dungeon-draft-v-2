# Sentinelle — diagnostic de méthode après la V7

10 septembre 2026. Base Git observée : `2473c335`, avec modifications locales en cours.
Demande : expliquer le manque de cohérence et rechercher quoi changer, avant une nouvelle production.

## Conclusion

La priorité est de reconstruire la référence spatiale du personnage, ses poses et les pièces dessinées qui doivent les permettre. Continuer à régler les amplitudes du générateur actuel risque surtout de déplacer les défauts.

La V7 démontre une chaîne de lecture Spine/Godot et une génération reproductible. Elle ne démontre pas une méthode de production artistique satisfaisante. L'utilisateur juge toujours le personnage incohérent. Aucun nouveau kit n'a été produit pendant cet audit.

Le passage à Spine a essentiellement changé le format de sortie et les lecteurs. La chaîne effective reste :

**Illustrations fixes indépendantes → découpe automatique → remplissage des zones cachées → recettes de transformations 2D → clés JSON échantillonnées → lecteurs Spine.**

Les étapes de construction artistique et d'édition native dans Spine restent insuffisamment éprouvées. Une licence ou un autre connecteur ne concevra pas les poses à notre place.

## Défauts observés et causes

| Priorité | Observation et preuve locale | Conséquence et changement proposé |
| --- | --- | --- |
| 1 — Directions | Sur la [planche source](../../art/source/characters/catabase_monsters/sentinelle_airain/fixed_views_contact.png), E et S montrent presque le même trois-quarts frontal. La recette dirige pourtant E vers le bas-droite et S vers le bas-gauche. | L'arme et les pieds changent de direction sans une construction équivalente du corps. Valider les quatre orientations avec caméra, sol et cible visibles. Les noms E/S ne prouvent pas l'orientation des dessins. |
| 1 — Pièces dessinées | Les entrées du kit sont quatre PNG aplatis. Aucun PSD/KRA/ORA/XCF/BLEND/SPINE n'a été trouvé dans le dossier source de ce personnage. Les parties cachées sont reconstruites par lignes épaisses, disques et polygones colorés. La V7 sépare les épaules à une hauteur fixe de 24 pixels sous leur pivot. | Ces remplissages dépannent une petite oscillation, mais exposent des raccords et des volumes inventés quand le membre se déploie. Refaire des pièces complètes en calques : bras sous l'épaule, articulations, torse derrière le bouclier, jambes et pieds. |
| 1 — Estoc | Dans la [planche d'attaque](../../art/source/spine/sentinelle_kit_v7/review/sheet_attack.jpg), E à 0,40 s ramène le bras et la lance en travers du ventre et du bouclier ; W les fait passer devant la zone du casque. Des découpes saillent aux articulations. | L'alignement de la pointe ne suffit pas : position de l'épaule, passage du coude, prise, retrait du bouclier, engagement du corps et cible doivent former une pose complète. Les changements de profondeur demandent parfois un autre dessin. |
| 2 — Construction du rig | Le JSON contient un seul `torso` auquel sont rattachés jambes, épaules et tête. Aucun contrôle séparé bassin/thorax. Les 28 pièces du corps sont des régions rigides, sans maillage. Aucun remplacement d'image ni changement animé de l'ordre d'affichage. | Le buste reste une plaque peinte qui tourne dans le plan. Séparer bassin, thorax, tête et épaules ; conserver l'armure rigide, autoriser les raccords souples utiles, dessiner les raccourcis et régler les passages devant/derrière. |
| 2 — Marche | La [planche de marche](../../art/source/spine/sentinelle_kit_v7/review/sheet_walk.jpg) conserve une garde très écartée et les orientations des bottes peintes. Les pieds bougent autour de cette pose ; le transfert de poids reste peu lisible. | Choisir explicitement une marche alternée ou une avancée en garde. Construire ses appuis, passages et poussées depuis cette intention. Vérifier ensuite sur une trajectoire dans le jeu. |
| 2 — Sort | La [planche de sort](../../art/source/spine/sentinelle_kit_v7/review/sheet_cast.jpg) montre davantage de mouvement du bouclier, mais la charge et la libération ne définissent pas encore clairement le pouvoir. | Écrire l'intention : canaliser, protéger, projeter ? Composer préparation, pose de libération et récupération avec le VFX associé. Une amplitude plus grande n'est pas un critère suffisant. |

La quasi-similitude E/S est une observation visuelle ; nous n'avons pas reconstruit la caméra réelle à partir des dessins. Le mannequin proposé sert précisément à lever cette incertitude. Des longueurs différentes à l'écran ne prouvent pas seules une erreur anatomique : le raccourci en perspective les modifie.

## Ce que le nouvel audit mesure réellement

Le [rapport JSON](../../artifacts/dev/sentinelle-method-audit-20260910/report.json) provient d'une lecture des quatre JSON V7 conservés, avec empreintes SHA-256. Le [script d'audit](../../artifacts/dev/sentinelle_method_audit_20260910.py) est conservé pour reproduction.

- Chaque direction : **16 os de corps, racine comprise**, plus 18 os pour l'effet de disparition. Le chiffre total de 34 os surestime donc la richesse du rig corporel.
- Chaque direction : **28 régions de corps + 17 instances de fumée** ; aucun maillage, aucune contrainte IK native, aucun remplacement d'image animé, aucune piste de déformation ou d'ordre d'affichage.
- L'IK existe dans notre code Python, puis son résultat est converti en rotations/translations. Son absence du JSON ne signifie donc pas absence de calcul IK.
- **11 882 clés de transformation par direction**, effets compris, soit 47 528 pour le kit. Ce volume résulte notamment de l'échantillonnage autour de 60 Hz. Il ne représente pas autant de décisions d'animation et ne remplace pas quelques bonnes poses.
- Le solveur préserve des longueurs **projetées en 2D** et impose un sens de flexion par direction. Il ne reconstruit pas la profondeur du coude ou du genou. Des contraintes mathématiques cohérentes peuvent ainsi produire une anatomie visuellement erronée.

Mesure exploratoire de marche, sur 145 instants : écart pied gauche moins pied droit projeté sur l'axe écran déclaré par la recette :

| Direction | Intervalle en pixels source |
| --- | ---: |
| E | +100,75 à +140,78 |
| S | −120,19 à −80,18 |
| W | +56,47 à +96,49 |
| N | −93,35 à −53,34 |

Le signe ne change jamais : dans cette projection, les pieds gardent leur ordre avant/arrière. Cela étaye la lecture de petits pas en garde autour d'une pose très décalée. **Ce n'est pas une mesure biomécanique du sol** : les axes isométriques projetés ne sont pas orthogonaux et le pied levé introduit une composante verticale. Une avancée en garde peut conserver le même pied devant. Il faut choisir la démarche et calibrer le sol avant d'en faire un test d'acceptation.

## Ce qui a échoué dans notre manière de travailler

Le [bilan du premier pilote](../tools/sentinelle_attack_pilot_2026-09-09.md) recommandait déjà une référence adaptée et quelques poses du corps entier avant les quatre directions. Le [dossier Spine initial](../tools/spine_assessment_2026-09-09.md) distinguait explicitement ajout d'os et progrès artistique. Cette étape n'a pas été validée avant l'extension à 24 clips. Les révisions ont surtout corrigé des paramètres et des raccords autour d'une base contestée.

J'ai donné trop de poids à la réussite des contrôles techniques pour décider de poursuivre. Les contrôles restent utiles, mais leur périmètre est limité :

- Pointe alignée, avance monotone et événement à 0,40 s : cela ne valide ni silhouette ni transmission de l'effort.
- Appui stable à la vitesse simulée de 40 pixels source par cycle : cela ne valide pas la vitesse et l'échelle réellement utilisées dans le combat. Les ressources de combat n'ont pas été remplacées par ce kit.
- Sens des genoux imposé : cela valide la convention choisie par le code, sans prouver que cette convention correspond au volume dessiné.
- Bouclier déplacé de plus de 15 pixels : cela ne prouve pas que le sort est compréhensible.
- Chargement, boucle et disparition : cela valide le fonctionnement du fichier, avec une portée plus directe pour la disparition complète.

Le changement de méthode doit donc porter sur le **critère qui autorise la suite** : poses et mouvement jugés convaincants, puis expansion du kit. Compter les clips, les clés ou les tests ne suffit pas.

## Recherches utiles et rôle des outils

Le manuel Spine recommande de commencer par les poses majeures et signale que des passes séparées sur les parties peuvent produire des mouvements déconnectés. Notre prochaine tentative doit appliquer cette recommandation avec des silhouettes complètes et une lecture sans interpolation, puis régler les transitions. [Esoteric Software — Animating](https://esotericsoftware.com/spine-animating).

La mécanique corporelle doit représenter les forces : quel appui initie la poussée, comment le corps suit, comment il freine et revient. L'analyse de référence doit donc relever ces relations, pas simplement copier des positions de main. [Animation Mentor — Body mechanics](https://www.animationmentor.com/blog/animation-tips-tricks-what-makes-or-breaks-a-good-body-mechanics-shot/).

| Outil / méthode | Usage pertinent pour nous | État et limite |
| --- | --- | --- |
| **Blender, mannequin simple** | Construire une seule masse corporelle, une lance et un bouclier ; éprouver les poses et les orientations depuis une caméra orthographique calibrée sur notre scène. Utiliser les rendus comme guides pour le dessin. | **Blender 5.1.2 confirmé localement** par `--version`. Le contrôle de connexion MCP répond qu'il ne peut pas joindre Blender : liaison interactive non opérationnelle lors de l'audit. Un mannequin ne reproduira pas automatiquement notre style peint. |
| **Krita ou éditeur de calques existant** | Produire les pièces complètes et les dessins de remplacement. Conserver un fichier source éditable ; échanger des PNG et, selon la version de Spine, un PSD. | Krita sait lire/écrire des calques PSD, avec des limites de compatibilité. Son installation n'a pas été trouvée dans le PATH ni les dossiers Program Files inspectés ; ce n'est pas un inventaire exhaustif du poste. |
| **Spine, rig éditable** | Contrôles de bassin/thorax, cibles de main/pied, retouche des poses et courbes ; maillages localisés, remplacement des dessins et ordre d'affichage lorsque nécessaire. | Trial présente, édition signalée 4.3.26 lors de la préparation ; les données et lecteurs du kit sont en 4.2. L'aller-retour éditeur reste non vérifié. |
| **Connecteur Spine et scripts existants** | Inspecter, modifier des valeurs ciblées, produire des aperçus et vérifier les sorties. | L'adaptateur actuel réutilise notre découpe et notre solveur. Il n'a pas démontré la création et l'édition d'un rig artistique complet dans Spine. Ajouter un second MCP n'a pas de bénéfice établi pour les défauts observés. |
| **Atelier Godot existant** | Comparer référence et candidat, à vitesse normale et au ralenti, sur le sol et à l'échelle du jeu. | La comparaison de clips existe ; la piste distincte de référence animée décrite dans nos notes reste à construire. Réutiliser les services de l'atelier. |

Blender documente la projection orthographique et les cibles IK. L'intérêt proposé ici est d'obtenir des volumes et des vues issus de la **même géométrie** ; c'est une recommandation déduite de nos défauts, pas un résultat déjà obtenu sur la Sentinelle. [Manuel Blender — Caméras, extrait indexé](https://docs.blender.org/manual/sl/4.5/render/cameras.html), [Manuel Blender — IK](https://docs.blender.org/manual/en/latest/animation/armatures/posing/editing/inverse_kinematics.html).

Pour les dessins, Spine attend une image par partie mobile et propose l'import PSD ou des scripts d'export par calques. Conserver le format natif de l'éditeur graphique et vérifier les pixels lors de l'échange PSD. Le script Photoshop officiel nécessite Photoshop ; Krita peut fournir un PSD pour la voie d'import correspondante, sans exécuter ce script. [Spine — Images](https://esotericsoftware.com/spine-images), [Krita — PSD](https://docs.krita.org/en/general_concepts/file_formats/file_psd.html), [Script Photoshop officiel](https://github.com/EsotericSoftware/spine-scripts/blob/master/photoshop/README.md).

Les maillages peuvent déformer une image, et leurs poids répartir l'influence des os. Nous devrions les réserver aux zones qui en bénéficient : déformer toute l'armure risque de créer un effet caoutchouc. Les cibles IK facilitent les appuis et la pose de la main ; elles ne décident pas de l'équilibre. [Spine — Meshes](https://esotericsoftware.com/spine-meshes), [Weights](https://esotericsoftware.com/spine-weights), [IK constraints](https://esotericsoftware.com/spine-ik-constraints).

L'exemple officiel Alien combine quelques dessins successifs et des déformations. Il confirme qu'une approche mêlant dessins de remplacement et articulation est prévue par Spine ; ce n'est pas une démonstration de notre estoc isométrique. [Spine — Alien](https://esotericsoftware.com/spine-examples-alien).

La trial expose les fonctions Professional mais ne sauvegarde pas, ne fait pas le packing et n'exporte pas les données/images/vidéos. Elle reste adaptée à l'évaluation. Un travail durable dans l'éditeur devra disposer d'une voie de sauvegarde autorisée ; entre-temps, les références et dessins se conservent dans Blender et l'éditeur graphique. L'achat éventuel ne corrigera pas les directions ou les poses. [Spine — Trial](https://esotericsoftware.com/spine-download).

La version majeure/mineure des exports doit correspondre à celle du runtime. Il faut aussi conserver la source `.spine`, les exports JSON ne préservant pas nécessairement toutes les données d'édition. Corriger ce contrat avant une production native ; il n'explique pas à lui seul les incohérences visuelles déjà présentes dans les PNG. [Spine — Versioning](https://esotericsoftware.com/spine-versioning).

Référence d'action ciblée : le **Spearman de Bleed** propose marche, attaque et parade en huit directions. Sa page a été revérifiée ; le clip n'a pas été importé ni comparé pendant cet audit. Il reste un candidat à examiner pour le geste et la projection, avec une morphologie et une arme différentes. [Source de l'auteur sur OpenGameArt](https://opengameart.org/content/spearman-bleeds-game-art).

## Choix de méthode recommandé

| Option | Intérêt | Coût / risque |
| --- | --- | --- |
| Dessins en calques et poses entièrement en 2D, puis Spine | Contrôle direct du style et de la silhouette ; peu d'outils nouveaux. | Les vues et raccourcis reposent sur la construction du dessinateur. Les quatre orientations restent un travail important. |
| **Mannequin 3D de référence → dessins en calques → Spine** | Base spatiale commune pour nos quatre vues ; contrôle du geste avant de repeindre. Recommandation pour le prochain pilote. | Étape de référence supplémentaire ; le mannequin doit respecter les proportions trapues, le bouclier et la lance courte. Aucun transfert automatique parfait vers le rig 2D n'est supposé. |
| Personnage 3D complet, animations puis rendu en sprites | Réutilisation naturelle d'un même volume sur plusieurs vues et actions. | Travail de modèle, matériaux et rendu pour retrouver le style ; perte de l'édition squelettique 2D après rendu. À comparer sur un seul clip si les rotations exigent trop de redessin. |

L'IA d'image peut aider aux recherches et retouches d'une pièce, sous contrôle visuel. Nos propres essais montrent qu'elle ne doit pas être la seule garantie d'identité et de continuité entre poses. Les [générations du premier pilote](../tools/sentinelle_attack_pilot_2026-09-09.md) ont déjà modifié le corps, la longueur de lance et les fonds. Automatiser davantage cette étape sans référence géométrique ne traite pas la cause identifiée.

## Prochain essai, avec critères de sortie

1. **Fixer le personnage et la caméra.** Une planche montrant clairement les quatre directions, le sol, la cible, la même main porteuse et des proportions constantes. Corriger en priorité l'ambiguïté E/S. Un mannequin rudimentaire suffit pour examiner le volume.
2. **Construire un seul estoc, dans une direction vérifiée.** Environ cinq poses complètes : garde, préparation, engagement, extension/contact, récupération. Le nombre reste adaptable. Lire d'abord les silhouettes sans interpolation ; la lance doit atteindre une cible visible sans traverser le corps ou le bouclier. Vérifier le pied porteur, le déplacement du bassin et la place de la tête.
3. **Préparer uniquement les pièces requises par ce geste.** Ajouter les faces cachées et les raccourcis révélés par les poses extrêmes. Un essai de flexion doit garder des épaules, coudes et genoux continus ; les plaques rigides conservent leur volume apparent.
4. **Animer puis vérifier dans le contexte de jeu.** Conserver les contraintes d'événement du combat. Examiner à taille de jeu, en silhouette, au ralenti et image par image. Le jugement artistique est consigné séparément du verdict technique.
5. **Éprouver une vue arrière et une vraie translation de marche.** La vitesse du cycle est liée à la distance parcourue dans Godot. Distinguer une avancée en garde d'une marche alternée. Fixer un repère au sol et suivre le pied en appui.
6. **Décliner le kit seulement après ces validations.** Concevoir le sort depuis son effet et son intention. Garder l'explosion noire comme élément indépendant, à revoir à l'échelle finale.

Si les poses sur mannequin sont bonnes et que l'habillage 2D les dégrade, le problème restant est le dessin/rig : retoucher les pièces ou comparer le rendu 3D en sprites. Si les poses simplifiées sont déjà mauvaises, revenir à la référence et au mouvement avant tout habillage.

## Ce qu'on conserve et ce qu'on automatise

Conserver la direction artistique approuvée, les sources, la V5/V7 pour comparaison, l'effet de disparition, les lecteurs, événements et vérifications. Les générateurs actuels restent des expériences reproductibles, pas une base artistique approuvée.

Concentrer l'outillage sur une fiche courte par mouvement : référence réellement examinée, caméra, poses approuvées, pièces nécessaires, contraintes d'appui et d'arme, événements, capture de revue et verdict utilisateur. Indexer ces fiches pour reprendre avec peu de contexte. Garder les milliers de clés calculées comme sortie de compilation plutôt que comme principal support de conversation. Aucune économie chiffrée de tokens n'est démontrée par cet audit.

## Preuves et limites de cette recherche

- Nouveau : inspection des quatre JSON V7, hachages, hiérarchie, types d'attachements, pistes et mesures exploratoires des pieds ; revue des planches source, estoc, marche et sort ; recherche documentaire ciblée ; version Blender et essai de connexion MCP.
- Les pages Spine, Krita, Animation Mentor et OpenGameArt ont été consultées. Pour la caméra Blender, l'extrait du manuel indexé par la recherche a été accessible, l'ouverture complète de la page a échoué.
- Les [contrôles web V7](../../artifacts/dev/spine-kit-web-1789039495389/report.json), [géométriques V7](../../artifacts/dev/sentinelle-motion-1789039465822680600/report.json) et [natifs Godot V7](../../artifacts/dev/20260910-132453-sentinelle-kit-godot-bafd963e/preview.json) sont des preuves des essais précédents, **non réexécutés pour ce rapport**. Leur réussite ne constitue pas une approbation artistique.
- L'import et la sauvegarde dans l'éditeur Spine, le transfert du mannequin vers nos dessins, la qualité d'un rig révisé et l'intégration du nouveau kit au combat restent à démontrer. Aucun nouveau mouvement ni outil artistique n'a été installé ici.
