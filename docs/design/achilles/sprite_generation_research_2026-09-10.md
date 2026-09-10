# Produire les animations de Passe-rive sans reconstruire une pipeline à chaque geste

Recherche du 10 septembre 2026. Cible : personnage peint et stylisé, adulte et élancé, dans une vue trois-quarts, avec lance et bouclier. Priorité : marche et idle ; conservation du design et facilité de correction avant multiplication des actions.

## Décision proposée

**Tester d'abord un outil spécialisé qui possède déjà ses mouvements et son export de sprites.** Ludo est le candidat le plus pertinent trouvé pour notre direction artistique. Comparer son mouvement prédéfini à notre marche Blender comme référence, puis demander une correction précise sur chaque résultat. Le coût de cette correction compte autant que la première génération.

Cette priorité est une recommandation issue des capacités documentées, pas un classement de qualité mesuré. Aucun des nouveaux services étudiés n'a encore réussi le test Passe-rive. Les démonstrations de Ludo montrent plusieurs styles et mouvements, mais ne prouvent ni les appuis de notre personnage ni la conservation de sa lance.

Conserver Blender comme référence et outil de réparation du mouvement. Réutiliser l'atelier de sprites pour le montage, le rythme, la comparaison et l'export Godot. Différer une nouvelle installation lourde, un entraînement ou une intégration MCP jusqu'à ce qu'une animation peinte ait survécu à une correction.

## 1. Pourquoi notre méthode demande trop d'efforts

Le [dernier audit](passe_rive_walk_audit_2026-09-10.md) distingue les défauts des dessins de ceux du guide. La [marche Blender V2](../../../art/source/blender/passe_rive_walk_v2/README.md) a amélioré les appuis : retour utilisateur positif sur leur raccordement. Cette validation porte sur ce point du mannequin, pas sur un kit peint final.

| Constat dans le projet | Conséquence | Changement proposé |
| --- | --- | --- |
| Des dessins séduisants sont produits avant de disposer d'une séquence stable. | Chaque correction doit rétablir simultanément pose, proportions, accessoires et style. | Générer ou adapter une séquence conditionnée par un mouvement existant ; conserver un original immuable. |
| Une mécanique particulière est reconstruite pour chaque essai. | Une marche devient un chantier d'outillage. | Constituer une petite bibliothèque de mouvements et de poses sources réutilisables. |
| Des contrôles portent sur le mannequin ou la livraison technique. | Un export correct peut contenir des pieds peints qui glissent. | Évaluer le sprite final en déplacement, puis la transition avec l'idle. |
| L'habillage 3D de la Sentinelle s'éloigne de l'illustration. | Le résultat cohérent mécaniquement reste refusé artistiquement. | Garder la référence peinte comme autorité de silhouette et de palette. |
| On cherche une génération qui réussit tout le personnage et tous ses détails. | Un pied réparé peut s'accompagner d'un autre bouclier. | Tester la possibilité de corrections localisées, de pièces stables ou de poses de remplacement. |

La première réussite d'Achille montre que nous pouvons obtenir rapidement une proposition expressive. Elle ne démontre pas que les images constituent une animation paramétrable : modifier un appui sans modifier la cape demande un contrôle absent d'une série de générations indépendantes. Il faudrait comparer les sources exactes du premier kit avant d'affirmer qu'il était mécaniquement exempt de défauts.

Notre objectif doit donc devenir : **obtenir un personnage animé que l'on peut corriger et décliner**, avec un temps de travail décroissant pour les actions suivantes. Ajouter un outil ne constitue un progrès que si cette opération devient plus courte.

## 2. Ce que font réellement les jeux bien animés

Les jeux mobiles visibles à l'écran utilisent plusieurs techniques. Une illustration animée de sélection, un combattant 3D et une attaque dessinée ne constituent pas le même problème de production. Les exemples suivants disposent de témoignages directs des équipes ou de crédits de fabrication.

| Exemple documenté | Fabrication confirmée | Enseignement pour Catabase |
| --- | --- | --- |
| **Brawl Stars / Supercell** | Les crédits de Gene distinguent concept, sculpture, modèle/textures, rig et animation. Le moteur Titan dispose d'une timeline visuelle pour composer mouvements et effets avec aperçu dans le jeu. | Un personnage stylisé à l'écran peut être un modèle animé. Réutiliser des sources éditables et composer les effets permet d'enrichir une action. [Crédits Gene](https://supercell.artstation.com/projects/aRLqa0), [Supercell — Titan](https://supercell.com/en/news/titan-game-engine/). |
| **Azur Lane / Manjuu** | L'équipe décrit ses modèles Live2D, ses préréglages d'animation et ses techniques réutilisées entre personnages. | Le volume devient possible par capitalisation. Le témoignage concerne les illustrations et tenues Live2D ; il ne prouve pas que les sprites de combat utilisent cette technique. [Entretien officiel](https://www.live2d.com/en/business/interview/azurlane/). |
| **Epic Seven / Super Creative** | Le moteur YUNA optimise l'affichage et la compression d'animations 2D ; l'entretien décrit une production destinée à restituer le dessin animé sur mobile. | La technologie facilite l'exploitation de dessins élaborés. Elle n'en fournit pas automatiquement les poses et le jeu d'acteur. [Entretien publié par Smilegate](https://newsroom.smilegate.com/game/Epic_Seven_YUNA_Engine). |
| **Dead Cells / Motion Twin** | Thomas Vasseur décrit des personnages 3D animés, rendus en images 2D pour le jeu. | Une source 3D simple et réexportable peut réduire le coût des variantes. Son esthétique pixelisée ne transfère pas automatiquement notre peinture. [Retour de production](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-). |
| **Skullgirls / Mariel Cartwright** | La conférence montre des attaques améliorées en supprimant des dessins redondants : un exemple passe de 45 à 29 images. Les poses fortes et leur rythme structurent le geste. | Une attaque spectaculaire peut demander moins de dessins, mieux choisis. Ajouter des intermédiaires ne remplace pas anticipation et impact. [GDC 2014, notamment pages 29–34](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf). |
| **Guilty Gear Xrd / Arc System Works** | Les poses 3D sont volontairement déformées et leur interpolation limitée pour conserver une lecture dessinée. | Le squelette permet des gestes complexes. Il faut pouvoir exagérer, remplacer une silhouette et diriger le rythme. [Junya Motomura, GDC 2015](https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf). |
| **Never's End / Hypersect** | Ce RPG tactique emploie des techniques 3D pour une apparence de sprites dessinés, avec réglages de poses et de projection. | La direction tactique stylisée est compatible avec un rig. Le retour montre aussi un investissement artistique important ; ce n'est pas un raccourci prêt à installer. [Ryan Juckett, GDC 2026](https://media.gdcvault.com/gdc2026/Slides/Juckett_Ryan_HowWeDrawA3DSpriteWorldTheStylizedArtOfNeversEnd.pdf). |

Le point commun utile est une base conservée d'une animation à la suivante : personnage, poses, courbes, dessins ou conventions de mouvement. Les effets peuvent ensuite être ajoutés sur une timeline sans demander au corps d'accomplir à lui seul tout le spectacle. C'est une synthèse des exemples, pas une affirmation selon laquelle tous les studios partagent la même pipeline.

Pour Passe-rive, une disparition en éclats sombres, un estoc avec traînée spectrale ou un sort avec onde au sol peuvent chacun combiner un geste lisible et des effets indépendants. Il faut d'abord regarder le corps sans effets pour vérifier que l'ensemble ne masque pas une pose incohérente.

## 3. Les outils qui peuvent raccourcir la production

Statuts : **documenté** signifie que la capacité apparaît dans une source primaire ; **démonstration observée** signifie seulement que des exemples publics ont été regardés ; **test Passe-rive** exige un résultat avec notre référence. Ce dernier statut est absent pour tous les nouveaux outils du tableau.

| Outil | Apport documenté | Adéquation et limites pour Passe-rive |
| --- | --- | --- |
| **Ludo Sprite Generator** | Image importée, texte, poses clés, vidéo de référence, mouvements prédéfinis, export de sprites. Le site annonce 641 presets et montre du dessin peint, du cel shading et du pixel art. | Premier candidat à essayer. Plusieurs moments de démonstrations publiques ont été observés, dont un robot qui marche ; aucun contrôle complet de contacts ni test de notre personnage. [Fonctions et galerie](https://ludo.ai/features/sprite-generator). |
| **PixelLab — Animate with Skeleton** | Squelette repris d'un modèle ou d'une animation, édition de poses, conservation de dessins déjà satisfaisants, réutilisation du squelette. | Excellent principe de contrôle réutilisable. Fonction orientée pixel art, canevas carrés proposés de 16 à 256 pixels : ne pas dégrader notre direction artistique pour entrer dans l'outil. [Documentation](https://www.pixellab.ai/docs/tools/animate-with-skeleton). |
| **Retro Diffusion** | Génération de sprites pixel art et animations depuis une image ; exports GIF ou planche. L'API distingue les routes historiques et avancées. | Alternative spécialisée pour un éventuel test pixel art. Ne pas extrapoler les anciennes limites de résolution à toutes les fonctions actuelles. [Produit](https://retrodiffusion.ai/), [API officielle](https://github.com/Retro-Diffusion/api-examples/blob/main/README.md). |
| **Scenario + génération vidéo** | Le guide sprites utilise une image de personnage, produit une vidéo puis sélectionne des images et les assemble avec des outils externes. | Compatible avec notre peinture, mais extraction, alignement et boucle restent du travail. Choisir une caméra fixe pour notre essai, sans recopier tous les réglages de l'exemple. [Guide sprites](https://help.scenario.com/articles/9088582240-create-spritesheets-with-scenario). |
| **Kling Motion Control / Seedance via Scenario** | Kling propose un transfert guidé par une image et une vidéo ; Scenario documente plusieurs modèles Seedance pour la vidéo. | Sources possibles de séquences, sans garantie de contact exact, de boucle ou d'accessoire constant. Un nom de modèle vidéo ne constitue pas un export de personnage prêt à jouer. [Kling](https://help.scenario.com/articles/2242372122-kling-v3-motion-control-the-essentials), [Seedance](https://help.scenario.com/articles/5480884735-seedance-models-the-essentials). |
| **EbSynth** | Propage la peinture de poses clés sur un clip guide. Sa documentation explique que les formes peintes doivent correspondre à la vidéo pour éviter des déformations parasites. | Bon candidat pour conserver une peinture sur un mouvement déjà bon. Un mannequin trop différent de Passe-rive limite cette correspondance. Export PNG avec alpha proposé dans l'offre Pro ; la formule gratuite exporte du MP4. [Documentation et offres](https://ebsynth.com/). |
| **FLUX Kontext / IP-Adapter + ControlNet** | Édition d'image depuis une référence ; combinaison d'une indication d'apparence et de conditions de structure, pose ou profondeur. | Utiles pour le canon visuel ou quelques poses décisives. Un contrôle spatial d'image ne verrouille pas les contacts pendant toute une séquence. [FLUX Kontext](https://bfl.ai/models/flux-kontext), [Hugging Face Diffusers](https://huggingface.co/docs/diffusers/using-diffusers/ip_adapter). |
| **Layer** | Service de génération de sprites avec références et modèles adaptés à une production. | À considérer si l'enjeu devient une série de personnages ; aucune preuve trouvée d'une supériorité sur nos appuis ou notre coût de correction. [Présentation de l'éditeur](https://layer.ai/use-cases/sprite-generation). |

### Les réserves de Ludo à connaître avant l'essai

Sa documentation recommande Forge pour les presets et Tango pour une vidéo importée. Le transfert est limité à 36 images ; la boucle reste incertaine. Une retouche régénère toute la séquence et les retouches empilées peuvent faire dériver le personnage. Repartir de l'original après un échec. Le mode True Size conserve le format de l'entrée ; le compte gratuit ajoute un filigrane aux images exportées. Ces limites empêchent de promettre un résultat immédiatement exploitable. [Documentation du générateur](https://ludo.ai/docs/sprite-generator).

L'API et le MCP existent, mais sont réservés aux offres Pro et Studio. La page annonce Pro à 50 USD/mois avec 1 000 crédits, et les appels consomment des crédits. Le test via l'interface précède donc raisonnablement toute automatisation payante. Prix et accès à revérifier au moment d'une souscription. [API/MCP de Ludo](https://ludo.ai/api-mcp-integration).

## 4. La recherche récente rejoint notre idée, avec des limites concrètes

| Projet | Ce qui est intéressant | Ce que cela ne prouve pas |
| --- | --- | --- |
| **ToonComposer — Tencent ARC** | Images colorées, poses dessinées à certains instants et masques pour guider une séquence. Le dépôt donne une voie vers des intermédiaires cohérents. | L'exécution standard annoncée pour 61 images en 480p demande environ 57 Go de VRAM. Le poste actuel n'est pas adapté à cette configuration. [Dépôt officiel](https://github.com/TencentARC/ToonComposer). |
| **ToonCrafter** | Interpolation générative entre dessins, avec guidage par croquis. | Ce n'est pas une bibliothèque d'actions depuis une seule image. La configuration présentée utilise environ 24 Go de VRAM. [Dépôt des auteurs](https://github.com/Doubiiu/ToonCrafter). |
| **Wan-Animate / Wan 2.2** | Transfert de mouvement et d'expressions depuis une vidéo vers un personnage. | La disponibilité du code et de variantes optimisées ne démontre pas un débit utilisable sur notre GPU ni la fidélité d'une lance. [Projet](https://humanaigc.github.io/wan-animate/), [Wan 2.2](https://github.com/Wan-Video/Wan2.2). |
| **Spiritus** | Combine décomposition du personnage, rig unifié, mouvements et export Spine. | Travail de recherche prometteur ; ni adaptation ni qualité contrôlée sur Passe-rive. [Article des auteurs](https://arxiv.org/html/2503.09127v1). |
| **Qwen Image Layered** | Décomposition d'une illustration en couches RGBA manipulables. | Les couches sémantiques ne constituent pas automatiquement une anatomie articulée : dos des pièces, articulations et parties cachées restent à résoudre. [Dépôt officiel](https://github.com/QwenLM/Qwen-Image-Layered/blob/main/README.md). |
| **Meta Animated Drawings** | Détecte et articule des dessins humanoïdes puis applique du mouvement BVH ; annotations et retarget peuvent être corrigés. | Le domaine initial est le dessin de personnages simples. La cape, l'arme et les occlusions de Passe-rive demanderaient une adaptation. [Code et documentation](https://github.com/facebookresearch/AnimatedDrawings). |

Le matériel mesuré sur ce poste est une RTX 4070 Laptop avec 8 188 Mio de VRAM et environ 31,7 Gio de RAM système. Cela permet le travail Blender actuel, mais ne rend pas immédiatement confortables les gros modèles vidéo. Une variante quantifiée ou déportée peut changer la faisabilité ; son temps réel et ses artefacts devraient être mesurés avant de construire notre production dessus.

Des intégrations ouvertes existent déjà. [ComfyUI 2D Character Pipeline](https://github.com/mor-o/comfyui-2d-character-pipeline) assemble pose, génération vidéo et séparation de couches ; son auteur cible 24 Go de VRAM et indique une validation sur un seul personnage. [SpriteMaker](https://github.com/JohnKinyanjui/sprite-maker) propose génération guidée par des images voisines et rig 2D natif. Ces dépôts peuvent fournir des idées ciblées. Les installer ne prouverait pas qu'ils animent mieux que notre atelier ; leurs descriptions ne constituent pas des essais comparatifs.

## 5. Utiliser des mouvements déjà faits

La [Universal Animation Library de Quaternius](https://quaternius.com/packs/universalanimationlibrary.html) annonce plus de 120 animations dans le pack complet, avec des squelettes humanoïdes et des formats utilisables dans les moteurs courants. La licence affichée est CC0. Une partie est gratuite ; l'ensemble Pro et les sources ne le sont pas tous. Il faut vérifier la présence de la marche, de l'idle et des prises d'armes souhaités dans la variante retenue avant un achat.

[Mixamo](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) fournit également des animations de personnages bipèdes. Cela peut éviter de recréer les mouvements courants. Leur adaptation à une lance, à un bouclier, à nos proportions et à notre projection reste un travail distinct. L'accès à des clips pour un jeu ne doit pas être confondu avec la constitution d'un corpus d'entraînement.

Pour les sprites directement comparables, le [catalogue existant](../../tools/sprite_motion_references_2026-09-09.md) contient déjà le lancier de Bleed et un guerrier orc. Ces références sont repérées, pas encore adaptées ni approuvées. Le catalogue doit conserver ce statut tant qu'une lecture image par image n'a pas établi leur intérêt réel.

Commencer par quelques familles suffit : marche calme, marche armée, garde, estoc, recul et incantation. Pour chacune, conserver la source éditable et les phases importantes. Une animation peut fournir une trajectoire de bassin ou un passage de jambe sans imposer son costume, sa musculature ou son rythme exact.

## 6. Quatre combinaisons créatives à essayer dans cet ordre

Ces propositions sont des hypothèses de production. Elles ne sont pas présentées comme des résultats obtenus.

### A. Canon peint + mouvement prêt à l'emploi + export spécialisé

Utiliser le PNG Passe-rive retenu, choisir une marche prédéfinie proche de sa garde, puis comparer à un transfert depuis notre clip Blender. C'est la voie la plus courte : elle mesure si un service a déjà résolu une partie du problème que nous tentions de programmer. Son test décisif est une correction ciblée sans altération du reste du personnage.

### B. Corps animé + accessoires stables + effets séparés

La lance et le bouclier sont des indices très visibles de continuité. On peut essayer de conserver leurs dessins sur des couches, liés à des points de prise, pendant que le corps et les tissus utilisent une animation peinte. Il faut des masques pour les passages devant/derrière, des mains correctement dessinées et plusieurs vues de l'accessoire lorsqu'il tourne. Coller une lance rigide à un poignet erroné ne corrige pas une prise.

Cette solution paraît particulièrement adaptée aux gestes avec peu de rotation. Une attaque qui présente l'envers du bouclier nécessite une pose ou un dessin supplémentaire. La décomposition en couches est donc une façon de réduire les zones à régénérer, avec un domaine d'emploi explicite.

### C. Quelques poses expressives + séquence guidée ou propagation

Retenir les poses qui racontent l'action : garde, compression, engagement, impact et récupération pour un estoc. Les dessiner ou les générer avec le même canon, puis produire les transitions avec des poses guides, un clip ou une propagation. Pour un geste rapide, une pose tenue et une déformation de transition peuvent être plus efficaces qu'une longue interpolation uniforme.

EbSynth demande des formes déjà compatibles avec la vidéo ; les approches ToonComposer demandent davantage de guidage et de ressources. La bonne expérience serait donc un segment court dont l'occlusion est connue, avant toute ambition de kit complet.

### D. Un exemple réalisé par un animateur comme référence de production

Si les deux premières voies demandent toujours des réparations lourdes, commander une seule marche ou un seul estoc à un animateur 2D expérimenté peut fournir une base fiable : poses, timing, source éditable et conventions d'accessoires. Aucun prestataire ni tarif n'est sélectionné ici. L'intérêt serait de mesurer ce qu'exige réellement un résultat final sur notre design, puis de réutiliser ces décisions dans les autres actions.

Ce serait aussi un meilleur matériau de référence qu'un grand dossier d'animations hétérogènes dont ni les appuis ni la perspective ne correspondent à notre jeu.

## 7. Ce qui peut devenir permanent dans notre apprentissage

Lire ou examiner beaucoup d'animations ne réentraîne pas l'assistant en cours de conversation. Trois choses différentes doivent être distinguées :

| Niveau | Ce que nous pouvons conserver | Limite |
| --- | --- | --- |
| **Mémoire du projet** | Règles courtes, sources, erreurs, décisions utilisateur et liens vers les preuves. | Doit être relue et mise à jour ; son existence ne garantit pas un résultat visuel. |
| **Bibliothèque exploitable** | Clips, poses, contacts annotés, repères d'armes, corrections déjà réussies. | Demande un classement pertinent et une adaptation à la morphologie. |
| **Entraînement d'un modèle distinct** | Adaptateur de style ou modèle de génération temporelle, avec données et protocole de mesure. | C'est un chantier séparé ; mémoriser le costume ne suffit pas à apprendre un transfert de poids. |

Le travail [Sprite Sheet Diffusion](https://arxiv.org/html/2412.03685v1) est instructif : il étudie 75 séquences issues de 16 personnages, avec séparation entre personnages d'entraînement et de test. Les auteurs signalent une cohérence du sujet en dessous de leurs attentes et évoquent le surapprentissage. Le [code existe](https://github.com/chenganhsieh/Sprite-Sheet-Diffusion), mais l'article ne constitue pas une preuve qu'un petit entraînement local résoudrait notre marche.

Une bibliothèque utile pourrait commencer avec une dizaine d'exemples bien choisis. Chaque fiche conserverait : action, angle, morphologie, équipement, durée, phases, pied d'appui, trajectoire du bassin et de l'arme, points d'occlusion, défauts observés, statut de validation, source et droits. Une série connue pour échouer doit rester dans le catalogue : elle permet de vérifier qu'une nouvelle méthode corrige effectivement l'erreur.

Les cas initiaux de notre mémoire sont déjà disponibles : la marche peinte V1 comme contre-exemple documenté, la marche Blender V2 comme amélioration des appuis et la ruée d'Achille conservée dans l'atelier comme référence interne appréciée. Aucun de ces trois statuts ne doit être étendu à toutes les qualités de l'animation.

La [mémoire compacte d'animation](../../ai/animation_memory.md) centralise les décisions réutilisables. Le [catalogue de mouvements](../../tools/sprite_motion_references_2026-09-09.md) centralise les références. Le panneau de comparaison avec une piste de mouvement distincte est déjà proposé dans l'atelier, mais reste à implémenter : inutile de créer un second outil qui ferait la même chose.

## 8. Le prochain test doit mesurer le temps gagné

**Question à trancher : pouvons-nous obtenir et corriger une marche peinte de Passe-rive avec moins d'interventions que la méthode actuelle ?** Le banc d'essai ci-dessous est prêt à appliquer ; il ne constitue pas une autorisation de dépense.

### Entrées communes

Utiliser la [référence choisie](../../../art/source/characters/achilles/passe_rive_v1/reference_choisie.png), la même vue trois-quarts et le même cadrage. Garder lance à droite anatomique, bouclier à gauche, masque ivoire, silhouette élancée et palette retenue. Une grande résolution de fichier ne doit pas conduire à enrichir les détails du costume.

Prendre un cycle gauche + droite complet. Le guide V2 dure 1,2 seconde par cycle et sa vidéo contient plusieurs répétitions ; choisir un segment utile plutôt que compresser toutes les répétitions. Adapter la pose initiale et la direction du guide à celles de l'image. Garder une copie native de chaque sortie avant découpage ou détourage.

### Comparaison minimale

| Candidat | Entrée de mouvement | Ce qu'il permet de décider |
| --- | --- | --- |
| **A : mouvement prédéfini** | Preset de marche du service, proche de la pose armée. | Le service suffit-il pour les actions courantes ? |
| **B : mouvement fourni** | Segment de la marche Blender V2. | Le gain d'appui du guide se retrouve-t-il dans la peinture ? |
| **Contrôle** | V1 peinte et V2 mannequin déjà disponibles. | La nouvelle sortie améliore-t-elle le vrai défaut sans perdre le personnage ? |

Commencer par A. Si ses appuis et sa garde sont satisfaisants, B peut devenir inutile pour la marche ; il restera pertinent pour des gestes plus spécifiques. Si A échoue, essayer B avec le mode recommandé pour une vidéo importée. Limite de travail proposée : trois tentatives par voie avant bilan, afin d'éviter une boucle indéfinie de prompts.

### Examiner ce qui sera réellement affiché

1. **Mouvement final.** Regarder les pieds peints en déplacement sur une grille. Pendant l'appui, leur vitesse relative au sol doit être proche de zéro. Dans un cycle sur place, le pied doit au contraire reculer relativement au corps : une image immobile dans le canevas n'est pas une preuve de contact.
2. **Identité.** Suivre les deux pieds et mains, la longueur des membres, le masque, la broche et la prise d'arme pendant un cycle complet. Examiner les croisements de jambes et les zones derrière le bouclier.
3. **Style à taille jeu.** Regarder sur un décor représentatif, à la hauteur utilisée par la caméra du jeu, puis agrandir pour inspecter les contours. Une jolie grande vignette ne suffit pas.
4. **Boucle et transition.** Lire plusieurs cycles puis idle → marche → idle. Une coupe sans saut de position peut encore cacher une rupture de vitesse ou une jambe qui change de rôle.
5. **Une correction imposée.** Demander une seule modification observable, par exemple diminuer le glissement du pied d'appui ou maintenir la diagonale du bouclier. Vérifier les zones qui devaient rester stables.
6. **Livraison.** Contrôler alpha, ombre, cadrage commun, marges de la lance, timing et import dans l'atelier existant. Ces vérifications arrivent après la cohérence du mouvement.

Noter le temps de préparation, le nombre de générations, les crédits consommés, le temps de nettoyage et surtout celui de la correction. Une voie devient intéressante si elle passe ces critères avec moins de reprises ; une génération spectaculaire mais impossible à modifier reste un brouillon utile, pas notre base de production.

Si la marche réussit, faire un idle court dans la même garde, puis un seul estoc avec ses effets sur des pistes séparées. Ce troisième clip éprouvera l'expressivité et les occlusions que la marche ne teste pas. La déclinaison dans d'autres directions vient ensuite, conformément au choix utilisateur d'une direction soignée d'abord.

## 9. Portée des preuves

Les liens ci-dessus privilégient les documentations des éditeurs, publications des auteurs, conférences des animateurs et témoignages des équipes. Les capacités commerciales peuvent changer ; elles sont rapportées à la date de consultation. Les chiffres matériels proviennent du poste local. Les conclusions sur notre production proviennent des fichiers et retours utilisateur cités, puis de recommandations explicitement formulées comme telles.

La recherche couvre jeux mobiles, animation dessinée, rendu 3D en sprites, logiciels spécialisés, génération d'images et de vidéos, bibliothèques de mouvements et publications récentes. Elle n'est pas un classement exhaustif des meilleurs services. Les exemples promotionnels ne remplacent pas un essai avec notre silhouette, nos armes et une correction demandée. Aucun nouvel entraînement, achat ou résultat généré n'est revendiqué par ce dossier.
