# Construction d’un effet de sort peint pour Catabase

La construction recommandée est une petite animation composée dans Godot à partir de calques peints, puis exportée en flipbook pour le lecteur VFX existant. Le premier pilote est le contact de la **Frappe du Péléide** : une empreinte principale, trois éclats, une impulsion brève et une disparition. La création reste modifiable ; le jeu reçoit un asset simple à rejouer.

Une étude animée accompagne cette proposition. Elle fonctionne dans Godot 4.7.1 avec Forward+ et utilise les quatre calques du concept existant. Elle établit la faisabilité de cette construction, sans valider la peinture comme effet définitif. Les exports de production et le branchement au combat constituent les étapes suivantes.

## Techniques et méthodes documentées

« VFX », « sprite » et « shader » désignent des niveaux différents. VFX est le résultat visuel ; un sprite porte une image ; un shader détermine comment sa surface est dessinée. Un système de particules peut déplacer des sprites, éventuellement animés par flipbook et rendus par shader. Il faut choisir l’assemblage qui rend le geste lisible et permet de le corriger rapidement.

| Source primaire | Ce qu’elle établit | Transposition proposée pour Catabase |
| --- | --- | --- |
| Julien Pingault, FX Huppermage de DOFUS, 2019 | L’auteur présente des animations réalisées avec Flash/Animate, dont des variantes non retenues. Cette source concerne une production historique, pas tout DOFUS Unity. [^1] | Une silhouette et son évolution temporelle sont des objets de création. L’exploration comprend des essais rejetés. |
| Sephy, post-mortem de Nindash | Le compte rendu décrit des choix différents selon le contenu : animation exportée, assemblage dans Unity et intervention spécialisée pour les VFX. L’accès direct à cette page reste irrégulier ; ce cas était documenté dans le dossier précédent à partir du contenu indexé. [^2] | Réserver le travail spécialisé aux besoins qui le justifient ; adopter une chaîne courte pour le premier effet. |
| Oli McDonald, *Maya Attack Swipes* | Deux courbes suivent les bords du geste de l’arme ; une surface est construite entre elles. Les courbes restent éditables. Des UV orientés dans la longueur permettent d’y faire défiler une texture masquée. [^3] | Séparer la forme, le mouvement et l’effacement. Conserver une source dont on peut changer le profil après observation dans le moteur. Le pilote de contact ne nécessite pas de mesh. |
| Geri, *Venom Slash*, 2022 | Décomposition personnelle : mesh annulaire immobile, multiplication de textures, déplacement d’un bruit, rampe de couleur et éclaboussures tirées d’un atlas. Le billet présente aussi un outil commercial ; ce n’est pas une pipeline officielle de studio. [^4] | Une surface peut sembler animée sans redessiner chaque image. Reprendre la séparation des fonctions ; les couleurs, le bloom et le style de cet exemple ne correspondent pas à Catabase. |
| VFX Apprentice, article sur le timing, 2025 | L’article recommande de régler le mouvement avec des formes simples avant les textures et matériaux détaillés. Il distingue notamment des impulsions immédiates des effets qui montent en intensité. [^5] | Comparer trois rythmes avec la même forme. Pour un contact déclenché après résolution des dégâts, l’impulsion commence immédiatement. |
| Riot, espace pédagogique VFX | La ressource met l’accent sur la cohérence visuelle et les compétences artistiques, avec des exemples de construction. Elle ne fournit pas une recette unique applicable à tous les sorts. [^6] | Juger l’effet au milieu des unités et des informations tactiques, puis au sein du kit. La réussite d’une démonstration agrandie ne suffit pas. |

Ces sources ne permettent pas de reconstituer « exactement la pipeline Ankama actuelle » pour tous ses jeux. Elles permettent de reconstruire des procédés explicites et de choisir ceux qui conviennent au projet. Le [dossier général](vfx_pipeline_research_2026-09-12.md) conserve les autres cas, les dates, les limites d’accès et les distinctions entre travail professionnel, exercice et test de recrutement.

### Portée des références

Le document de McDonald contient une méthode Maya et mentionne un export vers un moteur. Cette recherche utilise son explication textuelle ; elle ne prétend pas avoir exécuté ses fichiers ou analysé une animation intégrée au PDF. Ses nombres de triangles sont des recommandations de ce document, pas des budgets à imposer à notre jeu 2D.

Le billet *Venom Slash* explique directement les opérations qui produisent son apparence. Il apporte une preuve plus exploitable qu’une simple vidéo finale, mais n’établit ni la performance de notre implémentation ni l’intérêt d’acheter son outil. Le shader du pilote est écrit pour Godot ; aucun asset de cet exemple n’est repris.

## Choix de production

Trois chemins sont possibles. Le dessin image par image offre le plus de liberté pour transformer la matière, mais demande une compétence d’animation FX encore non démontrée dans ce projet. Une animation entièrement procédurale est facile à paramétrer, mais ses primitives n’apportent pas spontanément la qualité de peinture attendue. Des calques peints animés par des courbes constituent un point de départ plus maîtrisable.

**La recommandation est donc : peinture séparée → composition temporelle dans Godot → capture transparente → atlas → lecteur flipbook existant.** Le shader sert à travailler la disparition pendant la création ; sa complexité n’a pas besoin de rester dans le jeu. Cette décision limite les modifications du moteur et conserve un rendu reproductible.

Le compromis est explicite. Un calque étiré reste le même dessin ; il ne remplace pas une déformation artistique image par image. Cette construction convient à un impact bref, des fragments, un trait ou un sceau. Une flamme vivante, une fumée qui se replie ou une vague qui se brise pourra exiger quelques poses dessinées, une autre surface ou un autre procédé. Chaque besoin sera évalué à partir d’un pilote distinct.

## Pilote : contact de la Frappe du Péléide

La [définition du sort](../../../data/spells/achilles/peleid_strike.tres) décrit une frappe physique de portée 1, coûtant 3 PA. L’effet doit communiquer un contact local et énergique. Il ne doit pas suggérer un projectile, une explosion de zone ou un nouvel état persistant.

L’image recherchée est une **entaille de pigment et de bronze au point de frappe**. Un trait tendu arrive visuellement au contact ; une ouverture anguleuse très brève exprime l’énergie ; quelques fragments prolongent le mouvement pendant que la cible redevient immédiatement lisible. La surface principale reste attachée au point touché.

La présente étude commence au contact. Le mouvement de l’arme et l’éventuelle anticipation appartiennent à l’animation de l’attaquant. Les ajouter après que les dégâts ont été résolus introduirait un décalage. Le branchement devra respecter l’événement réel, puis synchroniser séparément le geste et le son.

### Composition et palette

| Élément | Fonction | Fabrication et comportement |
| --- | --- | --- |
| Empreinte principale | Faire comprendre la frappe et son axe | Un calque transparent ; ouverture par mise à l’échelle autour du point de contact ; disparition par masque. |
| Éclat supérieur | Prolonger l’impulsion | Un fragment peint ; trajectoire courte ascendante puis ralentie. |
| Éclat central | Renforcer la direction | Un petit fragment ; déplacement principalement horizontal. |
| Éclat inférieur | Casser la symétrie | Un fragment avec une fin de trajectoire légèrement descendante. |

Il y a quatre sprites dans l’étude. Les trois éclats remplissent la fonction de particules, mais leurs trajectoires sont explicitement calculées. Un émetteur GPU n’est pas nécessaire pour trois éléments déterminés. Après export, le lecteur de jeu pourra afficher leur composition avec un seul sprite animé.

La [direction artistique du projet](catabase_direction_artistique_v1.md) fixe le vocabulaire : bronze `#B48A4E`, accent terre cuite `#B5503F`, ivoire `#DDD7BD`, ombre pétrole `#24565A`. Le bronze doit porter la matière, la terre cuite rappeler la doctrine, l’ivoire concentrer l’attention au contact et le pétrole préserver les contours. Les valeurs sont des références de dessin, pas une obligation de recolorer uniformément tous les pixels.

La peinture utilisée dans l’étude reste trop dominée par une plage ivoire très claire. Les fines bordures colorées peuvent aussi attirer l’œil comme un liseré lumineux. La prochaine correction artistique doit redistribuer ces masses dans le calque maître : davantage de bronze/terre cuite, moins d’ivoire continu, des contours plus sobres. Une simple multiplication de couleur assombrirait également les ombres ; elle ne remplace pas ce travail.

Le mélange choisi est `MIX`, avec alpha droit. L’étude ne produit ni bloom ni lumière dynamique. Un éclairage ajouté ne peut pas réparer une silhouette ou une palette insuffisante. Les modes de fusion et le comportement de `COLOR` sont ceux documentés pour les CanvasItem Godot. [^7]

### Partition temporelle de référence

Tous les temps ci-dessous sont des **réglages de travail**, pas des valeurs mesurées chez Ankama ni des seuils universels de satisfaction. La recette complète est dans [recipe.json](../../../tools/labs/peleid_contact_study/recipe.json).

| Temps depuis le contact | Empreinte | Éclats | Information pour le joueur |
| --- | --- | --- | --- |
| 0 ms | Déjà visible, largeur 70 %, hauteur 22 % | Absents | Le contact a eu lieu ; aucun délai visuel ajouté. |
| 0–33 ms | Ouverture rapide vers 100 % ; ralentissement de l’ouverture en fin de segment | Premier départ à 25 ms | Impulsion principale. |
| 33–65 ms | Hauteur revient progressivement à 90 % | Départs à 35 et 45 ms | Séparation du contact et de ses conséquences. |
| 65–155 ms | Effacement irrégulier ; le point d’ancrage ne se déplace pas | Trajectoires qui ralentissent | La masse principale libère la cible. |
| 155–320 ms | Absente | Disparition échelonnée à 255, 285 et 320 ms | Résidu bref, sans deuxième impact. |

Trois variantes multiplient tous les temps par `0,7`, `1` et `1,35`, donnant 224, 320 et 432 ms. Elles isolent le choix du rythme ; leur peinture est identique. Les panneaux du bas utilisent tous la variante de référence afin de comparer les fonds sans changer une autre variable.

La variante B est une base de comparaison, pas une victoire artistique déclarée. Si A communique mieux une frappe standard, on conserve A. Si les trois paraissent molles, il faut revoir le geste ou l’attaque initiale avant d’ajouter des couches. Une version plus longue ne signifie pas automatiquement plus puissante.

## Construction dans Godot

Le [laboratoire autonome](../../../tools/labs/peleid_contact_study/README.md) charge les PNG existants et leur manifeste. Il n’importe pas de nouveaux assets de combat, ne charge pas les autoloads du jeu et ne calcule aucun dégât. Ce petit projet séparé permet d’observer le rendu sans confondre les erreurs de fermeture du harnais général avec celles de l’effet.

### Coordonnées et ancrage

Le maître mesure 1536 × 1024 pixels. Son point de contact est `(1195, 518)`. Chaque calque est découpé en mémoire selon ses limites occupées, sans réécriture du fichier source. Le décalage du sprite principal vaut `centre_du_rectangle − point_de_contact` ; son origine devient ainsi le contact, y compris pendant la mise à l’échelle.

La largeur de référence est de 72 pixels pour 831 pixels dans le maître : le facteur initial vaut `72 / 831`. Les panneaux agrandis appliquent ensuite un facteur 3. Ces 72 pixels sont un réglage d’étude, **pas une taille en combat certifiée**. La cible et le décor sont réels, mais leur composition est une fixture de laboratoire.

La projection isométrique du jeu définit par défaut des cases de 128 × 64 dans [iso_projection.gd](../../../battle/iso/iso_projection.gd). Une empreinte située dans le plan de l’écran ne doit pas être aplatie comme un dessin posé au sol. Pour la production, il faudra lire l’échelle effective de la vue et maintenir une échelle uniforme, puis vérifier les zooms du combat.

### Courbes et disparition

La fonction d’échantillonnage reçoit un temps absolu. L’ouverture et les déplacements utilisent une interpolation rapide au début, puis ralentie : `1 − (1 − u)³`. Les éclats ont des rotations déterminées, une petite composante descendante et une diminution progressive d’opacité. Aucun état aléatoire ne s’accumule au fil des images.

Le shader combine une progression dans la longueur et un bruit spatial peu détaillé. Un seuil croissant retire l’alpha ; les couleurs peintes sont préservées. Le premier essai produisait une tranche presque droite. Le mélange a été corrigé pour obtenir une disparition en morceaux, vérifiée dans les captures à 100 ms.

Cette correction a sa propre limite : le bruit peut créer des trous trop ronds pour une matière de fresque. Il sert ici à éprouver le contrôle de l’effacement. Si cet aspect reste visible à l’échelle du jeu, la correction prévue est un **masque d’effacement peint en niveaux de gris**, dont les îlots suivent les coups de pinceau. Ce masque remplace le bruit sans modifier le contrat de temps ni les couleurs.

Le shader ne dépend pas de `TIME`. Dans Godot, cette variable globale ne s’arrête pas avec une pause ; la piloter implicitement compliquerait le retour à une image précise. [^7] Le laboratoire transmet directement le degré d’effacement correspondant au temps demandé.

## Export visé et réemploi du moteur existant

L’export en atlas n’est pas encore réalisé. Le contrat suivant définit précisément l’étape à construire après la revue du rythme et du dessin.

| Propriété | Proposition pour le pilote |
| --- | --- |
| Source du rendu | La même composition, dans un SubViewport transparent, sans décor, cible ou textes. |
| Image de travail exportée | 256 × 256, contact au pixel `(176, 128)`, effet réglé à 144 px de largeur de référence. |
| Cadence | 60 images/s ; 21 images, échantillonnées de 0 à 333,33 ms. |
| Fin | Dernière image totalement transparente ; lecture sur 350 ms. La composition source devient vide à 320 ms. |
| Atlas | 8 colonnes × 3 lignes ; 21 images utilisées et 3 cases vides. |
| Variante détaillée | Atlas 2048 × 768 ; environ 6 Mio en RGBA8 sans mipmaps. |
| Variante basse | Images 128 × 128, atlas 1024 × 384 ; environ 1,5 Mio en RGBA8 sans mipmaps. |
| Lecture | `SOURCE_FPS`, 60 FPS, `loop=false`, alpha droit, `MIX`. |
| Pivot normalisé | `(0.6875, 0.5)` ; même position relative à toutes les résolutions. |
| Échelle dans une projection 128 × 64 | Canvas affiché 128 × 128 ; `nominal_size_in_cells=(1, 2)` dans le contrat actuel, donc largeur visuelle de référence 72 px. À vérifier avec la vue réelle. |

Ces tailles mémoire sont des calculs de stockage RGBA, pas des mesures de VRAM ou de performance. Les mipmaps, la compression, les copies et l’import peuvent modifier le coût réel. Le recadrage de chaque frame à sa silhouette ferait dériver son pivot : les images temporelles doivent garder un canvas constant.

L’atlas échange donc une partie de la souplesse et de la mémoire contre une lecture simple. Conserver 21 copies temporelles coûte davantage qu’un petit ensemble de textures fixes de résolution comparable. Il faudra privilégier l’export basse résolution si la comparaison à l’échelle réelle ne montre pas de perte utile, charger les familles nécessaires et mesurer avant d’étendre le catalogue. Un long effet ambiant ne doit pas hériter automatiquement de cette recette d’impact.

Le lecteur [VFXFlipbookVisual](../../../vfx/modules/vfx_flipbook_visual.gd) sait déjà choisir les images, appliquer un pivot, une échelle et une rotation fixe. Il ne sait pas actuellement animer les transformations décrites dans cette étude. Les calculer pendant la création puis les enregistrer dans le flipbook évite d’ajouter cette fonction au runtime pour le premier pilote.

Il faut mesurer l’alpha réellement capturé avant de déclarer l’export « droit » : rendre sur transparence ne suffit pas à présumer la convention des RGB. Un contrôle sur fonds clair et sombre doit détecter un double assombrissement, une frange ou des couleurs contaminées. Le rendu GPU de la planche actuelle est opaque et ne valide pas ce point.

La dernière frame transparente est également importante : le runtime peut conserver la dernière image d’un module jusqu’à la fin de sa séquence. Elle prévient un résidu visuel, mais ne remplace pas la vérification de libération des instances.

L’import devra employer [VFXFlipbookManifestService](../../../vfx/services/vfx_flipbook_manifest_service.gd), les ressources de flipbook et le laboratoire existant. La publication Studio actuelle vise des fixtures de test. Elle ne doit pas être présentée comme une publication automatique dans le catalogue jouable.

### Branchement futur au contact réel

Dans [VFXManager](../../../core/vfx_manager.gd), `_resolve_achilles_vfx` récupère les positions des impacts résolus et émet actuellement un burst pour la famille `strike`. Le pilote devra remplacer uniquement le contact de `achilles_peleid_strike`, après vérification du résultat de l’action. Il ne faut pas remplacer tous les impacts d’Achille par une même peinture.

La rotation pourra être fixe par instance et calculée depuis l’axe lanceur–cible dans le plan affiché. L’absence d’axe exploitable exige un repli stable. Il faudra éprouver les huit directions utiles, l’ordre de dessin devant/derrière les unités, les cibles multiples et les actions annulées. Ces cas ne sont pas simulés par la présente planche.

Le son de contact, l’animation de frappe, la réaction de la cible et les nombres de dégâts devront partager le même événement de contact. L’étude est silencieuse. Ajouter plusieurs sons ou un arrêt global du jeu avant de vérifier cette synchronisation risquerait de masquer la cause d’un mauvais ressenti.

## Pipeline progressive et critères de passage

| Étape | Travail concret | Condition de passage | État |
| --- | --- | --- | --- |
| 1. Construction minimale | Quatre calques, temps absolu, trois rythmes, activation séparée des couches. | L’effet apparaît, se rejoue et disparaît ; ses couches sont compréhensibles. | Démonstrateur réalisé, vérification GPU effectuée. |
| 2. Revue artistique et rythme | Comparaison à vitesse normale ; correction du calque principal et éventuellement du masque. | Contact net, silhouette de la cible préservée, palette cohérente, rythme retenu. | Ouvert ; peinture actuelle à corriger. |
| 3. Export reproductible | Captures transparentes, atlas, manifeste, tailles et pivots constants. | Export identique à recette identique ; alpha vérifié ; dernière frame vide ; aucune coupe aux bords. | Contrat défini, export à implémenter. |
| 4. Lecture par la fondation VFX | Import via les services existants, pause/relecture, qualité basse/détaillée. | Même apparence et même ancrage que la composition source. | À faire. |
| 5. Un sort en combat | Branche ciblée dans la présentation, événement de contact, direction, son. | Pas de faux impact, ni double effet, ni décalage avec la résolution ; grille et UI lisibles. | À faire. |
| 6. Robustesse | Annulation, changement de scène, répétitions, chevauchement, mesure sur matériel visé. | Nettoyage effectif et coût compatible avec les scènes réelles. | À faire. |
| 7. Réutilisation | Second effet utilisant la même recette et un autre dessin. | La modification d’un asset n’exige pas de réécrire le moteur ; les deux sorts restent distincts. | À faire après le premier pilote. |

Les exercices n’ont pas besoin d’être accompagnés immédiatement d’un grand éditeur. Le fichier de recette expose déjà le temps, la taille, les trajectoires et les variantes. Le Studio reste le lieu de validation et d’association des ressources lorsqu’un export fonctionnel existe.

Une vraie pipeline sera établie lorsque le trajet **source modifiée → nouvel export → revue → effet jouable** aura été effectué puis répété. Le premier prototype ne démontre pas encore ce cycle complet.

## Outils, compétences et limites de capacité

| Besoin | Outil retenu ou prévu | Compétence à exercer | Preuve attendue |
| --- | --- | --- | --- |
| Construire et retimer | Godot installé | Courbes, pivots, séquençage, séparation des couches | Changer le rythme sans refaire la peinture ; rejouer un instant précisément. |
| Corriger la peinture | Éditeur raster à calques ; Krita proposé dans le plan précédent | Simplification de silhouette, répartition des valeurs, contours, alpha | Une correction visible à petite taille, enregistrée dans une source native réouvrable. |
| Diriger l’effacement | Shader Godot, puis masque peint si nécessaire | Niveaux de gris et seuils ; relation entre masque et matière | Modifier la disparition sans altérer la palette. |
| Exporter | Godot pour les frames, assemblage déterministe, services Studio pour la validation | Cadence, atlas, conventions d’alpha, checksums | Un export reproductible et accepté par le lecteur existant. |
| Évaluer le résultat | Vue réelle du jeu, capture et écoute | Hiérarchie visuelle, synchronisation, reconnaissance du geste | Le joueur identifie le contact et garde la lecture tactique. |

Le [plan d’outils et d’apprentissage](vfx_tools_learning_plan_2026-09-12.md) donne les exercices détaillés. Aucune nouvelle installation n’a été nécessaire pour l’étude. La réouverture et la retouche du maître dans Krita restent à prouver sur ce poste. Blender est disponible mais n’apporte pas de besoin indispensable au premier contact. Animate et les outils de simulation ne sont pas requis par cette construction.

L’automatisation sait ici déplacer les éléments, régler les courbes, produire des captures et comparer des pixels. Elle ne démontre pas une capacité à fabriquer automatiquement des dizaines de dessins temporellement cohérents, ni à sélectionner seule une direction artistique satisfaisante. Une aide générative éventuelle concerne des recherches de matière ou de silhouette ; les sources retenues doivent ensuite être séparées, contrôlées et travaillées de manière cohérente.

## Vérifications et réserves

La capture finale a été exécutée avec Godot `4.7.1.stable.official.a13da4feb`, Forward+ / Vulkan et une RTX 4070 Laptop. Le journal final ne contient pas d’erreur moteur ni de diagnostic de ressource restante à la fermeture. Trois contrôles GPU sont positifs : le contact modifie l’image, un retour à 50 ms après passage à 180 ms restitue les mêmes pixels, et les panneaux agrandis à 600 ms sont identiques à leur état vide. Le [rapport](../../../artifacts/dev/peleid_contact_study/report.json) précise ce périmètre.

Sept captures temporelles et 84 frames à 60 FPS ont été produites. Le GIF de revue utilise 42 de ces frames ; sa durée de boucle de 1,4 seconde comprend une pause visuelle après l’effet. Le GIF réduit les couleurs et arrondit les durées à la centiseconde : le rendu interactif et les PNG font foi pour juger finement la palette et le timing.

Les images GPU à 33 et 100 ms ont été inspectées pour la disposition, le contact et la disparition. La composition conserve la tête et les appuis de la cible visibles dans cette fixture. Elle ne démontre pas la lisibilité avec l’interface de combat, plusieurs unités ou toutes les caméras. Le problème de masse trop claire reste ouvert.

La première exécution en Compatibility avait produit les captures, mais signalé des erreurs d’accès Windows au cache de shaders et aux certificats. Ses journaux sont conservés dans `initial_compatibility/`. La capture finale Forward+ a été relancée avec les accès nécessaires. Les contrôles de cette étude ne résolvent pas les fuites signalées précédemment par les tests de la fondation VFX ; ce code n’a pas été modifié ni sa suite relancée ici.

La prochaine action est une revue du rythme et une correction du maître, avec les mêmes panneaux comme référence. Si cette correction ne permet pas un contact convaincant, il faut changer la silhouette ou le procédé à cette étape. L’export et l’intégration ne doivent pas figer un dessin insuffisant.

## Sources

[^1]: Julien Pingault. [2D ANIMATION FX Dofus GAME Huppermage](https://www.behance.net/gallery/74754737/2D-ANIMATION-FX-Dofus-GAME-Huppermage). 12 janvier 2019. Portfolio de l’auteur ; production historique.
[^2]: Sephy. [Ankama — Nindash, post-mortem](https://sephyka.com/game-post-mortem/ankama-nindash/). Sans date affichée vérifiée. Accès direct irrégulier ; contenu indexé exploité dans le dossier général. Ne décrit pas DOFUS Unity.
[^3]: Oli McDonald. [Maya Attack Swipes — Knowledge Share](https://realtimevfx.com/uploads/short-url/8qm4E0B2diapzBckenqBYBUYZDq.pdf). Sans date vérifiée, 29 pages ; notamment pages 7–18 et 28 en numérotation humaine. Explications textuelles consultées.
[^4]: Geri. [Venom Slash — breakdown of the effect included](https://realtimevfx.com/t/venom-slash-breakdown-of-the-effect-included/18903). Real Time VFX, 8 janvier 2022. Travail personnel et présentation d’outil ; décomposition directement publiée par l’auteur.
[^5]: VFX Apprentice. [The Soul of Effects: What is Timing in VFX?](https://www.vfxapprentice.com/blog/the-soul-of-effects-what-is-timing-in-vfx). 20 août 2025. Article pédagogique consulté ; les formations payantes liées n’ont pas été suivies.
[^6]: Riot Games. [Art Education — Visual Effects](https://www.riotgames.com/en/artedu/visual-effects). Sans date affichée vérifiée. Ressource pédagogique officielle, consultée dans le dossier général.
[^7]: Godot Engine. [CanvasItem shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html). Documentation stable consultée le 12 septembre 2026 : modes de fusion, `COLOR`, `TIME` et paramètres de shader.
