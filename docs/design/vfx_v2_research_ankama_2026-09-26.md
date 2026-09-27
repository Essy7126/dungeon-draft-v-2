# VFX après la V1 cel — recherche Ankama et suite réalisable

26 septembre 2026. Périmètre : **run Cartes uniquement**. La V1 cel est conservée comme base, conformément au retour utilisateur. Ce document propose la suite ; il ne constitue ni une nouvelle validation artistique ni une modification du jeu.

**Décision proposée : conserver la DA cel et travailler le mouvement de trois sorts pilotes.** Donner à chaque élément sa propre chronologie, améliorer le contact et dessiner les transformations de matière qui manquent. La déclinaison aux 112 cartes vient après une comparaison convaincante en combat.

**Ce que les sources permettent réellement d'affirmer**

| Source primaire consultée | Fait documenté | Portée pour notre travail |
| --- | --- | --- |
| [ToT, WAVEN note 18, 13 septembre 2018](https://totaime.wordpress.com/2018/09/13/waven-note-18-les-icones-et-fx-de-sorts/) | Présente des recherches d'icônes, leur confrontation au décor, puis des FX de Sylvain et Sébastien. La cohérence entre nom, icône et effet guide les essais. | Une référence historique de production, pas la description du client WAVEN actuel. |
| [Deeamo / Julien Pingault, ses FX DOFUS](https://deeamo.fr/dofus-x-deeamo-lanimation-de-fx-dans-le-jeu-dankama/) | L'artiste présente son travail chez Ankama, sa spécialisation en FX et des animations par classe, dans une pratique d'animation 2D traditionnelle. | Le dessin animé est une compétence de production déterminante. La page ne donne pas les fichiers sources ni toute la chaîne d'intégration actuelle. |
| [ToT, DOFUS CUBE note 06, 25 octobre 2017](https://totaime.wordpress.com/2017/10/25/dofus-cube-note-06-les-animations-de-personnages/) | Explique le choix de personnages 2D, les compétences de l'équipe et des outils Unity internes issus de Krosmaga. | Leurs choix dépendent de leur équipe et de leur outillage. Ce texte concerne les personnages du prototype ; il ne prouve pas que tous les FX utilisent la même chaîne. |
| [Romain Maquoi, Waven Execution VFX](https://rplm.artstation.com/projects/K3x6bX) | Décrit un effet conçu et produit en cinq jours pour un test technique de recrutement, à partir d'une consigne de 20 dégâts. | Un exemple du travail consacré à un seul effet. Ce n'est ni un sort confirmé en production, ni un délai moyen Ankama, ni une estimation pour nous. |

La piste « Waven Spells VFX » de [Sylvain Guerrero](https://www.artstation.com/artwork/1x4qeG) a été retrouvée. Une collection tierce en conserve une description mentionnant Unity/Shuriken ; le contenu original n'a pas pu être vérifié directement. **Ce détail n'est donc pas retenu comme preuve technique.** Aucun document consulté ne permet de reconstituer intégralement le pipeline actuel d'Ankama ou de promettre son rendement.

**Les observations concrètes que nous pouvons réutiliser**

Les séquences suivantes ont été regardées lors de l'[étude du 22 septembre](vfx_reference_studies_2026-09-22.md). Leurs observations sont reprises ici, avec leur ancienneté ; elles n'ont pas été remesurées pendant cette recherche.

| Référence | Détail observé | Application proposée à Catabase |
| --- | --- | --- |
| Deux Doigts, prototype WAVEN de la note 18 | La main d'eau jaillit puis s'effondre en éclaboussures et en flaque. | Pour **Braise tenace**, produire une vraie fin de flamme : les langues se détachent, diminuent et laissent quelques braises. Cette transposition au feu est notre proposition. |
| [Épée céleste, démonstration DOFUS Unity de 2024, vers 00:39](https://www.youtube.com/watch?v=Dw2tuzw_CJk&t=39s) | Une lame suspendue chute ; contact clair, éclats et trace au sol terminent le geste. Vidéo de démonstration tierce, pas documentation interne. | Pour **Sentence du rempart**, séparer le marteau, sa traînée, l'éclat du contact et les débris afin que leur mouvement ne soit pas lié à une seule image. |
| [Iop WAKFU, vidéo officielle de 2015, vers 00:38](https://www.youtube.com/watch?v=DoTwvemkBYE&t=38s) | L'objet identifié comme l'Étendard reste posé pendant que le personnage se déplace. | Pour **Bastion vivant**, distinguer déploiement, protection active et rupture. Notre bouclier reste attaché à son porteur : la référence ne justifie pas d'inventer un objet tactique sur une case. |

Ce sont des observations et des hypothèses de transposition. Elles ne démontrent pas que ces animations sont unanimement appréciées. L'effet sur la satisfaction devra être jugé sur nos propres comparaisons.

**Ce qui limite actuellement notre V1**

Lecture du code et des contrats existants, le 26 septembre :

- Les 17 planches contiennent chacune six poses. Dans [recipes.gd](../../vfx/class_cards/cel/recipes.gd), `frame_at()` répartit ces poses avec les mêmes seuils temporels pour la plupart des animations. Les durées globales varient déjà ; les changements de pose restent largement communs. Donner plus de temps à un sort peut donc prolonger les mêmes dessins sans enrichir son action.
- Dans [class_card_vfx_player.gd](../../vfx/class_cards/class_card_vfx_player.gd), les plans avant/arrière représentent essentiellement les parties d'une même planche. Un marteau, ses éclats et son souffle ne disposent pas chacun d'une animation indépendante. Cela favorise une lecture de grande illustration qui apparaît puis s'efface.
- Les états utilisent déjà une rangée compacte, et les ticks/absorptions/expirations ont déjà des lectures réduites. Il faut préserver ces acquis. L'amélioration utile serait une silhouette de badge dédiée, lisible à 21 pixels, et un ancrage adapté à la hauteur du personnage plutôt que la hauteur commune de 106 pixels.
- Le son existe déjà : [catabase_battle_audio.gd](../../battle/audio/catabase_battle_audio.gd) et le système de feedback réagissent aux faits de combat. La piste est d'ajouter une identité sonore adaptée au matériau et à la puissance, puis de la synchroniser avec le contact visuel.
- Les VFX se branchent sur les résultats réels du combat. Une nouvelle anticipation jouée après le résultat ferait arriver le chiffre ou le son avant le coup. Une chronologie commune de présentation est donc un chantier distinct, à traiter explicitement.

Les [contrats V1](achilles/cards_vfx_cel_contracts_2026-09-22.md) restent la référence des effets et des durées de gameplay. Une durée en activations ne devient pas une minuterie en secondes.

**Chaîne de production proposée pour nous**

1. **Écrire une fiche de geste par sort.** Définir ce qui apparaît, d'où il vient, ce qu'il touche et ce qu'il devient. Décrire séparément lancement, application, entretien et fin. Pour un bouclier : assemblage → verrouillage → badge actif → petit retour d'absorption → rupture si réellement épuisé.
2. **Faire une courte ébauche animée à taille de combat.** Trois à cinq poses de travail suffisent pour choisir direction, silhouette et rythme. Vérifier la lisibilité sur le terrain avant de produire les détails. La référence sert à étudier un mouvement ; nos dessins et symboles restent ceux de Catabase.
3. **Produire les éléments séparément.** Un objet principal, une trace de mouvement, un contact, quelques fragments, éventuellement un résidu. Animer un objet rigide avec déplacements/rotations ; réserver le dessin image par image aux transformations qui en ont besoin. Tester six à douze poses utiles sur les pilotes, sans imposer ce nombre à tout le catalogue.
4. **Nettoyer et exporter.** Vérifier continuité des contours, palette, transparence, pivot, échelle et marge autour de chaque image. Conserver la source éditable et les paramètres d'export. Une variation involontaire du pivot crée du tremblement ; un agrandissement ne corrige pas un dessin confus.
5. **Assembler dans Godot.** Définir durées par pose, trajectoires et décalages des éléments. `SpriteFrames` permet une durée relative propre à chaque image ; notre lecteur peut aussi recevoir ces données pour conserver le routage existant. Les pistes d'`Animation` permettent de synchroniser propriétés et audio. Sources : [SpriteFrames](https://docs.godotengine.org/en/stable/classes/class_spriteframes.html), [Animation](https://docs.godotengine.org/en/stable/classes/class_animation.html).
6. **Raccorder aux événements réels.** Partager un repère de contact entre VFX, son et réaction visuelle. Pour l'anticipation, séparer le résultat logique et sa présentation sans retarder arbitrairement les règles. Gérer interruption, mort et destruction de la cible. Les petites particules doivent utiliser leur propre aléatoire, sans consommer celui du gameplay.
7. **Comparer en combat et corriger.** Même carte, même cible, même caméra, V1/V2 côte à côte ou successivement. Tester son activé puis désactivé, plusieurs cibles, plusieurs états et une carte claire/sombre. Le nombre de cartes couvertes ne mesure pas la qualité du mouvement.

**La place réaliste de Blender et de la génération d'images**

Blender est pertinent pour un marteau, une lame, des morceaux de rempart ou une chaîne dont la perspective doit rester stable. Proposition : modèle simple, mouvement animé, caméra orthographique alignée sur le jeu, rendu en séquence avec transparence, puis intégration comme sprites. La [documentation des caméras Blender](https://docs.blender.org/manual/en/4.4/render/cameras.html) décrit la projection orthographique ; ce workflow est notre adaptation, pas un procédé attribué à Ankama.

Pour un objet qui ne tourne pas en profondeur, un sprite découpé et bien animé peut suffire. Les fluides simulés et les effets 3D complexes augmenteraient beaucoup les réglages, sans garantie de mieux correspondre à notre DA.

La génération d'images peut fournir concepts, poses principales et éléments originaux. Elle ne garantit pas la cohérence temporelle de toutes les images d'une gerbe de feu ou d'une métamorphose. Je peux préparer l'outillage, assembler les couches, régler les chronologies et vérifier l'intégration. Des dessins intermédiaires complexes demanderont des reprises artistiques ; atteindre la finesse d'un animateur FX spécialisé ne peut pas être promis par automatisation.

**Trois pilotes et leur critère de réussite**

| Carte | Proposition visuelle | Travail nécessaire | Ce qui doit être visible en combat |
| --- | --- | --- | --- |
| Sentence du rempart — `g_crash` | Masse d'airain lisible, accélération vers le contact, éclat bref, deux ou trois fragments lourds qui retombent. | Objet détouré ; chronologie dédiée ; éventuellement Blender pour une rotation ; coordination de la présentation pour l'anticipation. | On comprend où frappe la masse. Le coup et son retour sonore coïncident. Le personnage réapparaît rapidement après le contact. |
| Bastion vivant — `g_bastion` | Éléments de rempart qui se dressent avec un léger décalage puis se verrouillent ; transfert vers un écu compact ; fragment ou fissure au vrai événement de rupture. | Éléments séparés et animation de déploiement ; badge propre ; raccords aux faits existants. | Une protection active se distingue d'un bouclier épuisé. Le maintien suit l'effet réel : une activation, deux si améliorée, ou consommation anticipée. |
| Braise tenace — `t_burn` | Ignition localisée, langues de feu qui se déchirent et braises qui s'éteignent ; petite pulsation à chaque vrai dégât de brûlure. | Poses de transformation cohérentes et petit clip de tick ; travail artistique plus exigeant que le rempart. | On reconnaît le feu sans masquer la cible. Le badge subsiste pendant les deux activations prévues ; l'ignition complète ne se rejoue pas à chaque tick. |

L'objectif du lot est de valider trois problèmes différents : poids, protection et matière. Une fois les solutions convaincantes, décliner leurs composants dans les cartes compatibles, en conservant un geste propre aux sorts importants.

**Priorités et limites de faisabilité**

| Priorité | Chantier | Appréciation |
| --- | --- | --- |
| 1 | Chronologie propre à chaque clip, éléments séparés, pivots stables, terminaisons lisibles | Réalisable avec notre architecture ; travail d'outillage puis réglages par sort. |
| 2 | Son au contact, réactions adaptées au personnage, coordination des lancements | Réalisable, mais touche une présentation commune : intégration et validation plus délicates que le seul lecteur VFX. |
| 2 | Badges dédiés et ancrages selon les personnages | Périmètre limité, bénéfice direct sur la lisibilité des états. |
| 3 | Nouvelles poses de feu/eau/fumée et quelques objets Blender | À concentrer sur les pilotes : la continuité artistique est le principal risque. |
| Plus tard | Refaire les 112 cartes avec de longues séquences entièrement dessinées, simulations complexes, effets très dépendants de chaque squelette | Volume et dépendances non chiffrés ; attendre une cadence de production réellement mesurée sur les pilotes. |

Pas d'estimation en jours annoncée avant un premier pilote terminé. Mesurer le temps de dessin, de corrections et d'intégration séparément permettra de dimensionner la suite.

**Vérification prévue pour une future implémentation**

- Contrôle visuel à la caméra normale, pas seulement dans une galerie agrandie : compréhension de la direction, point de contact, matériau, puissance relative et maintien de la lecture tactique.
- Contrôle technique : carte annulée, cible disparue, impacts multiples, expiration et consommation de bouclier, durée exacte des états, débordement de la rangée de badges, absence de modification de l'aléatoire ou des résultats de combat.
- Mesure des coûts avec plusieurs effets réels simultanés : textures chargées, recouvrement transparent et temps de frame. Une capture forcée à fréquence fixe ne prouve pas la performance.
- Tests VFX/cartes et validations du feedback commun si son ou séquençage sont modifiés. L'avis artistique vient d'une comparaison en jeu ; des tests unitaires ne l'établissent pas.

**État de cette recherche :** sources consultées, contraintes du lecteur relues, recommandations formulées. Aucun code ni asset du jeu modifié, aucun test moteur relancé. Les modifications en cours sur les personnages, la sélection et le routeur VFX ont été préservées.
