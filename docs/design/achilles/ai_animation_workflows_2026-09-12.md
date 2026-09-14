# Workflows IA pour les personnages animés de Catabase

## Décision proposée

**Genjutsu a produit un candidat reconnaissable dans notre DA. La prochaine piste autorisée est Cartwheel, avec Meshy comme alternative ; pour une production précisément corrigeable, conserver un mouvement éditable reste prioritaire.** Une génération vidéo peut fournir un candidat convaincant. Elle ne fournit pas, à elle seule, une garantie de conservation du costume, d'appuis corrects ou de modification locale.

Trois expériences répondent à des questions différentes :

| Priorité | Workflow | Question décisive |
|---|---|---|
| Essai terminé dans ce dossier | Dessin Passe-rive + guide Blender V2 → Higgsfield Genjutsu | DA reconnaissable ; alpha, boucle et correction exacte restent à démontrer. Voir le [bilan de l’essai](../../../artifacts/dev/animation_workflows_20260912/essai_genjutsu.md). |
| Comparateur préparé, sans achat | Personnage canonique → Ludo Transfer Motion / Keyframe Animation → atelier de sprites | Le lancement est bloqué sur ce compte ; aucune qualité mesurée. |
| Base de production à éprouver | Cartwheel / DeepMotion / mouvement licencié → corrections Cascadeur ou Blender → rendu 2D | Peut-on conserver une source dont les poses, les appuis, le timing et les angles restent modifiables ? |

Ce classement est un **jugement d’adéquation au projet**, pas un classement de qualité mesurée entre les fournisseurs. Aucun service non testé ici ne reçoit de validation artistique. Les faits externes ont été consultés le 12 septembre 2026 ; les configurations officielles et tarifs peuvent évoluer.

## 1. Le résultat recherché

Catabase emploie des personnages dessinés et stylisés, lisibles sur des cartes peintes, dans une projection tactique. La référence du test est le Passe-rive original : adulte élancé, masque ivoire, capuche bleu sombre, drapés vert grisé, lance et bouclier. Le Veilleur constitue une autre référence interne, plus compacte, dont la marche dessinée récente avait été jugée acceptable hors passage des pieds.

L’objectif comporte quatre exigences distinctes : conserver le design, produire un mouvement expressif, pouvoir corriger ce mouvement, puis l’exploiter dans Godot. Un outil capable de découper 48 images ou d’importer un atlas ne résout pas nécessairement les trois premières.

Le [diagnostic du Veilleur](animation_reset_2026-09-12.md) identifie notamment un haut du corps trop solidaire, des poses peu contrastées et une progression fondée excessivement sur les contrôles techniques. Le [dossier précédent](sprite_generation_research_2026-09-10.md) proposait déjà le transfert de mouvement. La nouveauté utile est de l’exécuter, de vérifier les outils actuels et d’évaluer la correction, au lieu d’ajouter un nouveau moteur de marche.

### Définir « exactement »

Pour une attaque, cela signifie pouvoir imposer la pose d’anticipation, la direction de l’arme, l’image de contact, le temps de maintien et le retour en garde. Pour une marche, cela signifie distinguer les deux jambes, contrôler le passage et les contacts, et accorder le cycle à la vitesse de déplacement.

Une consigne textuelle peut exprimer cette intention. Une source avec poses, clés, trajectoires et masques permet de la vérifier et de la modifier. La recommandation est donc de choisir les outils selon **les décisions qu’ils permettent de conserver**, et pas seulement selon l’attrait de leur première vidéo.

## 2. Comparaison des workflows prioritaires

### Ludo : le chemin le plus direct vers un essai de sprites

Ludo documente le transfert d’un mouvement vidéo ou d’un preset, ainsi qu’une animation guidée par trois images : début, milieu et fin. Le mode Forge correspond aux dessins ordinaires ; Forge Pixel cible le pixel art. L’export peut fournir les images et les planches nécessaires à notre atelier. La bibliothèque annonce 641 mouvements, plusieurs perspectives et huit directions. [1][2]

La limite documentée est essentielle : une retouche recrée l’animation entière et peut introduire de la dérive. « Fix Loop » tente une réparation sans garantie. **Ce n’est donc pas un éditeur où déplacer uniquement un pied conserve automatiquement tous les autres pixels.** [1]

**Application proposée à Catabase.** Éprouver d’abord une marche non armée du Veilleur avec un preset dont la vidéo est convaincante. Conserver ensuite les résultats avec leurs entrées. Pour Passe-rive armé, comparer à un transfert du guide V2. Une attaque spécifique devrait commencer par trois poses réellement distinctes, plutôt que par une longue description.

Ludo reste intéressant pour un pilote rapide, sous réserve de réussir l'épreuve de correction. Dans cette tâche, l'utilisateur s'est connecté et les entrées Passe-rive ont été chargées. Forge, 2,5 s, coût affiché de 4 crédits, solde de 3 : le lancement a ouvert une offre Premium à 20 $/mois. L'utilisateur a choisi de continuer sans achat. Aucun résultat Ludo n'a été généré ici.

### Genjutsu / Kling : transfert rapide depuis une vidéo

Le connecteur Higgsfield expose Genjutsu comme un transfert d'une vidéo vers un sujet défini par une image. Le test autorisé est terminé : sortie réelle 834 × 1112, 24 images/s, 121 images, 5,041667 s, sans alpha. Le costume et la palette restent reconnaissables ; les passages des pieds, la lance descendant au sol et le raccord du clip demandent une revue. Une partie de ces choix vient du guide fourni. Ses paramètres, entrées, vidéo brute et observations sont consignés dans le dossier d'essai. Le moteur interne exact n'est pas déduit du nom commercial.

Kling Motion Control documente également l’association d’une image du personnage et d’une vidéo de mouvement. Il constitue un comparateur potentiel, mais **le test Genjutsu ne vaut pas un test Kling**. [3]

**Application proposée.** Utiliser ces outils pour produire un premier mouvement peint à partir d’un guide propre. Vérifier le maintien de la projection, les pieds, les mains et les accessoires sur plusieurs cycles. Garder le clip brut avant toute extraction : le découpage ne doit pas cacher une dérive du costume ou de la caméra.

Une vidéo en couleurs reste une vidéo : il faut qualifier son détourage, choisir un cycle, définir une ancre et contrôler le déplacement dans le jeu. Une belle séquence sur fond neutre ne prouve pas encore une marche jouable.

### Cartwheel / DeepMotion + Cascadeur / Blender : conserver une animation éditable

Cartwheel propose génération et capture du mouvement, rigging et export de données 3D. La documentation de son intégration Scenario expose notamment boucle, mouvement sur place et nettoyage des clés. Elle précise que certaines options d’IK des mains et pieds concernent les exports Maya ; leur présence dans un export Blender ne doit pas être supposée. [4]

DeepMotion Animate 3D propose capture depuis vidéo, retargeting, verrouillage des pieds et un éditeur de poses superposé à la vidéo, avec export FBX/BVH/GLB. SayMotion génère du mouvement depuis du texte et permet des opérations d’extension ou de mélange. [5][6]

Cascadeur fournit des outils d’assistance aux poses, aux intermédiaires et au nettoyage du mouvement. Sa mise à jour 2026.2 présente notamment des couches d’animation additives en alpha. Ces outils augmentent la capacité de correction ; ils ne décident pas à notre place du caractère d’une marche. [7][8]

**Application proposée.** Partir d’une animation convaincante, adapter les proportions, puis corriger les contacts, les bras et le rythme dans la source. Reprendre une caméra orthographique fixe. Rendre les orientations depuis le même personnage. Les sprites restent 2D dans Godot ; le fichier 3D devient la source de fabrication.

Le risque artistique déjà rencontré demeure : notre premier habillage Blender était trop éloigné du dessin. Avant un kit, produire un seul rendu stylisé et le comparer au canon à taille de jeu. Si ce rendu échoue, la 3D peut servir uniquement de guide à une seconde étape dessinée. Cette seconde étape doit elle aussi conserver les corrections, ce qui reste à démontrer.

**Autre voie Cartwheel découverte dans sa documentation directe : Mascot.** L'API accepte une vidéo, des références de personnage et un prompt, puis rend une vidéo de remplacement du personnage. C'est donc aussi un comparateur direct de Genjutsu, et pas seulement une source de mouvement 3D. Le site présente cette voie 2D avec un accès en bêta fermée ; la disponibilité sur le compte doit être vérifiée. Les routes de génération de personnage et de mouvement sont également documentées. [28][29][30]

L'utilisateur a autorisé un essai Cartwheel avec ses crédits, ou Meshy. Le premier contrôle API Cartwheel en lecture seule a retourné HTTP 403. L'utilisateur s'est ensuite connecté dans l'interface : **500 crédits affichés et formulaire Mascot accessible sur ce compte**. Après l'accord explicite exigé par le contrôle automatique pour le dessin privé, le même PNG et le même guide V2 ont été soumis à Mascot. Batch `batch-mascot-01M2B71R6RZ9JE5G10B19R16Z3`, en traitement lors de cette rédaction. Le solde est ensuite passé à 465,4 crédits, soit une baisse affichée de 34,6. Le bilan détaillé est à compléter à réception du résultat. Le plugin Meshy installé fournit un script API, mais aucune clé Meshy n'a été détectée dans l'environnement ou les fichiers `.env` de ce projet. Ces états d'accès ne constituent pas des verdicts sur la qualité des outils.

**Contrôles vérifiés dans Motion Editor sur le compte.** L'interface permet de choisir les articulations des pieds, genoux, bassin, colonne ou bras, puis de déplacer ou tourner une pose clé. Elle expose « Lock feet » et « Auto-control motion », décrit comme l'ajout d'images de contrôle pour rester proche de l'original. Une copie d'édition d'un ancien mouvement a été ouverte pour inspecter ces commandes ; aucune pose ni régénération n'a été appliquée. Il s'agit d'une preuve d'accès aux contrôles, pas d'une preuve de correction réussie sur Passe-rive.

Un exemple officiel de juillet 2026 décrit précisément la voie source 3D corrigée dans Motion Editor → rendu de guidage → modèle vidéo avec références de personnage. Cet exemple utilise Seedance 2.0 ; il ne permet pas d'identifier le moteur de notre essai Mascot. Pour le projet, l'expérience décisive serait de corriger le passage d'un pied dans la source, puis vérifier que le rendu final suit ce changement sans dériver sur le costume. [31]

### Wan-Animate et Wan-Animate-2 : davantage de possibilités, une infrastructure lourde

Wan2.2-Animate-14B dispose d’un code d’inférence et d’un workflow image + vidéo. Wan-Animate-2, publié en août 2026, traite directement la vidéo de référence et annonce un contrôle textuel du point de vue. C’est une piste pertinente pour les personnages difficiles à suivre avec un extracteur de poses intermédiaire. [9][10]

**Limite d’exécution.** Le dépôt Wan-Animate-2 indique des paramètres par défaut pour huit A800 en 720p et un essai 480p sur deux A800. Il ne s’agit pas d’un minimum universel démontré, mais cela exclut de présenter l’installation standard comme adaptée d’emblée à notre RTX 4070 Laptop de 8 Go. Une variante quantifiée ou déportée demanderait un essai distinct. [10]

Ces modèles permettent de construire un workflow plus inspectable qu’un service fermé. Ils ne garantissent ni boucles de jeu, ni alpha, ni géométrie exacte des accessoires. Les gains annoncés par les auteurs doivent être vérifiés sur notre dessin.

### ToonComposer / ToonCrafter : faire guider les intermédiaires par le dessin

ToonComposer produit des séquences à partir d’une référence colorée et de croquis clés. Son dépôt indique environ 57 Go de VRAM pour 61 images en 480p. ToonCrafter interpole deux dessins et propose un guidage par croquis ; sa version documentée produit jusqu’à 16 images en 512 × 320, avec des variantes communautaires plus légères. [11][12]

**Application proposée.** Éprouver un segment court comportant une vraie modification de silhouette : passage d’une jambe, compression avant un estoc ou retour en garde. Fournir le croquis qui résout le défaut, plutôt que demander au générateur de l’inventer.

Ce workflow est particulièrement intéressant si les poses clés plaisent déjà. Il devient moins utile si les poses de départ sont elles-mêmes incohérentes. Il demande aussi une gestion explicite des occlusions : une botte cachée puis révélée ne peut pas être traitée comme une simple translation.

### VACE + masques : piste pour une véritable correction locale

VACE accepte vidéo, références et masques pour la génération ou la modification temporelle. Des variantes Wan de plusieurs tailles sont publiées. Cela en fait une piste plus ciblée qu’une régénération globale pour réparer les jambes d’un cycle dont le haut du corps plaît déjà. [13]

**Proposition technique à éprouver, non exécutée ici.** Masquer une région couvrant les jambes et leur mouvement, générer uniquement le correctif, puis recomposer explicitement avec les pixels originaux hors de cette région. Un test de différence peut alors vérifier que les parties protégées restent identiques.

Cette conservation vient de la recomposition finale, pas d’une promesse du modèle. Les contours du masque doivent suivre la nouvelle silhouette ; les raccords, l’ombre et les occlusions restent à contrôler. Protéger le torse ne garantit pas que les nouvelles jambes seront bien animées. Le pilote pertinent consiste à corriger un seul passage, puis à examiner les images voisines.

## 3. Outils complémentaires et pistes moins adaptées

| Outil / famille | Capacité documentée | Décision pour notre DA |
|---|---|---|
| **Scenario Action Sprite Studio** | Assemble une planche de douze images depuis un personnage ; la page nomme GPT Image 2, un découpeur et un assembleur vidéo. [14] | Comparateur possible, mais proche de notre méthode de planche déjà éprouvée. L’assemblage ne prouve pas la cohérence temporelle. |
| **Scenario vidéo → sprites** | Guide de fabrication depuis une image, une vidéo et une sélection des poses. [15] | Utile pour la production et le style ; même besoin de qualifier les poses, le cycle et la retouche. |
| **Meshy** | Rigging et presets 3D, export FBX/GLB ; la documentation renvoie vers un logiciel d’animation pour une chorégraphie spécifique. [16] | Possible source de modèle ou d’animation standard. Il faut éprouver le rendu peint et les accessoires. |
| **HY-Motion 1.0 / Lite** | Génération textuelle de mouvement squelettique ; minima officiels annoncés de 26/24 Go de VRAM. [17] | Source de mouvement à comparer en environnement adapté ; aucun dessin final fourni par ce seul modèle. |
| **PixelLab** | Animation guidée par squelette, images initiales et inpainting ; outil destiné au pixel art, canevas documentés jusqu’à 256 × 256. [18] | Bon type de contrôle, esthétique différente. Ne pas pixeliser Catabase uniquement pour suivre l’outil. |
| **EbSynth** | Propagation de dessins clés par synthèse de textures ; l’éditeur précise que cette propagation n’est pas de l’IA générative. [19] | Intéressant pour transférer un habillage sur un mouvement dont les formes restent compatibles. Ne crée pas le mouvement. |
| **Qwen-Image-Layered** | Décomposition d’une image en couches RGBA. [20] | Aide à la préparation de pièces ; des couches sémantiques ne constituent pas un rig anatomique complet. |
| **Spiritus** | Publication associant création de personnage, rig unifié, mouvement BVH et adaptation dans Spine. [21] | Recherche directement pertinente ; accès à une solution exploitable sur notre personnage non établi ici. |
| **SPRITETOMESH** | Publication sur la génération de maillages de sprites pour animation squelettique. [22] | Traite la préparation du maillage, pas la conception expressive du geste. |
| **Meta Animated Drawings** | Animation de dessins humains simples avec un pipeline ouvert. [23] | Domaine trop éloigné du héros armé et des occlusions complexes pour en faire le premier pilote. |
| **ComfyUI 2D Character Pipeline** | Combine génération vidéo, détourage et couches cosmétiques ; cible une machine de 24 Go de VRAM. [24] | Base à examiner pour les masques et la composition, sans l’installer comme nouvelle usine complète avant un résultat artistique. |
| **Quaternius / bibliothèque de mouvements** | Animations réutilisables, packs et formats décrits par l’auteur. [25] | Témoin utile : comparer un mouvement déjà réalisé à la génération IA. Vérifier le clip et les fichiers inclus dans le pack exact. |

Les grands générateurs de vidéo généraliste restent des fournisseurs possibles d’images animées. Leur présence dans un catalogue ne suffit pas à les sélectionner pour un sprite tactique. Une prestation d’animation courte, livrée avec sa source, reste également un comparateur valable si les essais IA exigent davantage de réparation que de création.

## 4. Protocole de test reproductible

### A. Une marche et une correction

Prendre une seule orientation, un canon figé et un décor représentatif. Conserver la référence, le guide, les paramètres, le clip brut et chaque tentative. Le premier visionnage se fait à vitesse normale, puis à taille de jeu, puis au ralenti pour comprendre les défauts.

La marche doit montrer deux demi-cycles réellement distincts. Vérifier l’identité des jambes à la réception, au passage et à la poussée. Observer aussi le bassin, les épaules et la tête : une marche avec des pieds techniquement corrects peut rester mécanique.

Ensuite demander une correction unique : par exemple, relever davantage la botte pendant son passage sans changer le masque, l’écharpe, la taille du personnage ou le rythme global. Comparer la sortie corrigée à l’original, y compris les régions qui ne devaient pas bouger.

**Règle de décision proposée :** si deux corrections ciblées échouent sur le même défaut, interrompre cette voie pour ce clip. Changer d’entrée de contrôle ou de source de mouvement. Le nombre de tentatives n’est pas une garantie de réussite ; cette limite évite de confondre accumulation et progression.

### B. Une attaque pour tester l’intention

La marche ne teste pas suffisamment les accessoires et les changements de silhouette. Une fois le premier pilote retenu, produire un estoc : garde → anticipation → engagement → contact → récupération. Le contact doit pouvoir être positionné à une image précise ; sa synchronisation avec le gameplay doit rester indépendante de la génération.

Pour les poses contrôlées, conserver une version sans effets. Ajouter ensuite la traînée, l’impact et le son sur des pistes séparées. Évaluer le déplacement de la main, l’axe de la lance et les passages devant/derrière le bouclier. Un effet lumineux ne doit pas masquer une prise d’arme impossible.

### C. Décliner seulement ce qui a réussi

Après la correction témoin : repos, départ, marche, arrêt, deuxième orientation, puis quatre orientations. Une vue arrière exige les formes visibles depuis l’arrière ; retourner horizontalement une vue de face change aussi les mains porteuses et l’asymétrie du costume.

Une source 3D permet de conserver une structure entre les vues. Une méthode dessinée exige des références directionnelles cohérentes. Dans les deux cas, contrôler les virages et les raccords à l’échelle du jeu.

### Grille de décision

| Critère | Preuve attendue | Motif de refus |
|---|---|---|
| Identité | Comparaison référence / images du cycle | Masque, motifs ou proportions qui se transforment |
| Mouvement | Lecture normale, corps entier | Jambes confondues, pose centrale rigide, absence de poids |
| Appuis | Lecture en déplacement sur sol fixe | Glissement gênant, saut vertical ou pénétration |
| Accessoires | Prises et silhouettes sur tout le geste | Arme qui change de côté, longueur ou forme |
| Projection | Cadre et angle constants | Caméra qui tourne, personnage qui change de vue |
| Boucle | Plusieurs répétitions sans raccord masqué | Rupture de pose ou de vitesse au bouclage |
| Correction | Version A/B et source conservée | Défaut déplacé ailleurs, costume dégradé |
| Exploitation | Alpha, ancre, marges, durées et lecture Godot | Contours sales, recadrage variable, import incomplet |

Le verdict visuel appartient au clip observé. Il ne peut pas être extrapolé automatiquement à tout le personnage, à ses autres armes ou à toutes les directions.

## 5. Intégration dans le projet

Réutiliser l’[atelier des sprites](../../../tools/sprite_workshop/README.md) et ses services Studio. Il sait comparer des dessins, régler placement et durée, conserver un original et exporter une revue. Sa documentation précise qu’il ne crée pas automatiquement de nouvelles poses crédibles.

La livraison minimale comprend des PNG RGBA sur un canevas commun, les durées, l’ancre au sol, la direction, le statut de boucle, les éventuels événements d’action et les sources. Une ressource SpriteFrames et AnimatedSprite2D sont un chemin Godot documenté pour les séquences d’images. [26]

Ne pas ajuster chaque image à sa propre boîte englobante : une flexion ne doit pas agrandir le personnage. Ne pas reconstruire une boucle par lecture aller-retour si cela inverse des phases qui ne sont pas réversibles. Ne pas traiter un nombre élevé d’images comme une qualité en soi.

Pour le banc d’essai, l’ancre et la vitesse doivent être réglées ensemble. Sur une marche sur place, le pied porteur recule dans le canevas ; une fois la translation du personnage ajoutée, il doit rester cohérent avec le sol. Ces deux lectures sont complémentaires.

Aucun changement du moteur commun n’est requis pour comparer les premiers candidats. Les validations Godot du projet restent nécessaires lors d’une véritable intégration. Les anciens tests du Veilleur et de Spine ne sont pas des validations de cette nouvelle sortie.

## 6. Coût et faisabilité immédiate

Le GPU interrogé dans cette tâche est une **RTX 4070 Laptop, 8 188 Mio de VRAM**. Les configurations lourdes ci-dessus sont donc des pistes pour un serveur adapté ou des variantes à mesurer, pas des installations locales promises.

Le tarif public Ludo consulté indique **8 crédits pour un transfert**, **4–16 pour une animation de sprite**, **4–8 pour une modification de planche**. [27] **L'interface connectée observée ensuite affiche une tarification différente** : Forge / Forge Pixel, 1,5 crédit/s avec minimum 4 ; Tango, 4 crédits/s avec minimum 4. Notre réglage Forge de 2,5 s affiche 4 crédits. L'estimation du formulaire doit primer sur l'enveloppe calculée depuis la page publique. L'achat Ludo a été explicitement écarté par l'utilisateur.

Pour Higgsfield, le connecteur a indiqué zéro crédit et un essai gratuit Genjutsu disponible. L’essai a été autorisé explicitement et soumis avec le paramètre de gratuité ; aucune génération payante ni souscription n’est demandée. [Informations de plans Higgsfield](https://higgsfield.ai/mcp-pricing).

Le coût de production doit inclure préparation, générations rejetées, correction, détourage, montage et validation. Le nombre de crédits d’une première vidéo est insuffisant pour comparer une bibliothèque entière. Aucun délai fiable par personnage n’est établi avant le pilote de correction.

## 7. Ce que cette recherche permet de décider

**Genjutsu fournit maintenant une preuve de transposition vers notre DA. Cartwheel est le prochain essai autorisé : source de mouvement modifiable, et éventuellement Mascot si le compte y a accès. Ludo reste un comparateur préparé sans exécution. VACE mérite un essai limité si le besoin prioritaire est de réparer localement les jambes d'un clip déjà apprécié.**

Wan-Animate-2 et ToonComposer sont intéressants pour une recherche plus technique avec davantage de ressources. PixelLab est moins adapté à notre esthétique. Spiritus, SPRITETOMESH et la décomposition en couches répondent à une partie du problème ; ils ne démontrent pas une production autonome complète au niveau visuel recherché.

L’investissement à débloquer ensuite est celui qui produit une **animation convaincante et une correction réussie sur le même personnage**. Une démonstration promotionnelle ou une liste de fonctions ne remplace pas cette double preuve.

## Sources

Sources primaires consultées le 12 septembre 2026. Les pages non datées sont des documentations évolutives. Les jugements d’adéquation, recettes de pilote et critères d’acceptation sont des propositions pour Catabase.

1. Ludo. [Sprite Generator — documentation](https://ludo.ai/docs/sprite-generator). Modes, poses clés et limites des retouches.
2. Ludo. [Animate a Sprite from Video](https://new.ludo.ai/tools/animate-sprite-from-video). Page indiquant septembre 2026 ; bibliothèque, perspectives, transfert et sorties.
3. Higgsfield. [Why You Need Kling Motion Control 3.0](https://higgsfield.ai/blog/kling-motion-control-3). Fonction image + vidéo.
4. Scenario. [Cartwheel: The Essentials](https://help.scenario.com/articles/7811597894-cartwheel-the-essentials). Modèles, exports, paramètres et limites. [Site de Cartwheel](https://getcartwheel.com/).
5. DeepMotion. [Animate 3D](https://www.deepmotion.com/animate-3d). Capture, correction et exports.
6. DeepMotion. [SayMotion](https://www.deepmotion.com/saymotion). Texte vers mouvement et modifications temporelles.
7. Cascadeur. [Use of AI Tools](https://cascadeur.com/help/category/285). Rôle des outils d’assistance.
8. Cascadeur. [2026.2 — Animation Layers, Easing, New Languages](https://cascadeur.com/blog/view/cascadeur-2026-2-animation-layers-easing-new-languages). Statut alpha des couches additives.
9. Wan-Video. [Wan2.2](https://github.com/Wan-Video/Wan2.2). Wan-Animate, code et modèles.
10. Wan-Video. [Wan-Animate-2](https://github.com/Wan-Video/Wan-Animate-2). Publication des scripts et poids le 7 août 2026 ; configuration matérielle.
11. TencentARC. [ToonComposer](https://github.com/TencentARC/ToonComposer). Guidage et configuration mémoire.
12. Xing et al. [ToonCrafter](https://github.com/Doubiiu/ToonCrafter). SIGGRAPH Asia 2024 ; interpolation, résolution et limites.
13. Jiang et al. [VACE](https://github.com/ali-vilab/VACE). ICCV 2025 ; référence, vidéo et masques.
14. Scenario. [Action Sprite Studio](https://www.scenario.com/apps/action-sprite-studio). Composition du workflow.
15. Scenario. [Create Spritesheets with Scenario](https://help.scenario.com/articles/9088582240-create-spritesheets-with-scenario). Mise à jour affichée au 17 août 2026.
16. Meshy. [Animate — documentation](https://docs.meshy.ai/en/webapp/guides/animate). Rigging, presets, exports et chorégraphies hors presets.
17. Tencent Hunyuan. [HY-Motion 1.0](https://github.com/Tencent-Hunyuan/HY-Motion-1.0). Modèles publiés fin 2025 ; ressources et paramètres.
18. PixelLab. [Animate with Skeleton](https://www.pixellab.ai/docs/tools/animate-with-skeleton). Contrôles et tailles de canevas.
19. Secret Weapons. [EbSynth](https://ebsynth.com/). Fonctionnement et FAQ sur la propagation.
20. QwenLM. [Qwen-Image-Layered](https://github.com/QwenLM/Qwen-Image-Layered). Décomposition RGBA.
21. [Spiritus: An AI-Assisted Tool for Creating 2D Characters and Animations](https://arxiv.org/html/2503.09127v1). Prépublication, mars 2025.
22. [SPRITETOMESH](https://arxiv.org/abs/2602.21153). Prépublication, février 2026.
23. Meta. [Animated Drawings](https://github.com/facebookresearch/AnimatedDrawings). Code des auteurs.
24. mor-o. [ComfyUI 2D Character Pipeline](https://github.com/mor-o/comfyui-2d-character-pipeline). Description par son auteur ; maturité non auditée.
25. Quaternius. [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html). Packs de l’auteur.
26. Godot. [2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html). Chemin d’intégration par séquences.
27. Ludo. [Pricing](https://ludo.ai/pricing). Coûts par opération consultés à la date du dossier.
28. Cartwheel. [Create mascot — API](https://api-docs.getcartwheel.com/api/create-mascot/). Vidéo, références de personnage et prompt vers vidéo.
29. Cartwheel. [Plateforme officielle](https://getcartwheel.com/). Comic, Swing, éditeur, Mascot et statut de la voie 2D.
30. Cartwheel. [API officielle](https://api-docs.getcartwheel.com/api/external-mogen-orchestration-api). Authentification, personnages, médias et mouvement ; à distinguer du service de livraison cartwheel.tech.
31. Donald Chan, Cartwheel. [Directing AI Video with 3D](https://getcartwheel.com/blog/neural-rendering). Juillet 2026 ; exemple de construction du mouvement, correction et rendu vidéo guidé.
