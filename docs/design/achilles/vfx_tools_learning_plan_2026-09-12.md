# Outils et compétences pour les effets de Catabase

Le premier investissement doit porter sur une compétence de fabrication vérifiable : produire quelques poses, conserver leur rythme et reprendre une correction. Le [dossier de recherche](vfx_pipeline_research_2026-09-12.md) documente les studios, les techniques et les limites du moteur existant. Ce plan propose un ordre d'apprentissage ; les exercices restent à réaliser.

## Choix des outils

| Outil | Décision proposée | Rôle précis | Limite ou point à éprouver |
| --- | --- | --- | --- |
| **Godot 4.7.1 + Studio du projet** | Conserver | Composition, lecture, événements de jeu et revue | Publication Studio limitée aux tests ; certaines capacités VFX restent rudimentaires |
| **Krita** | Premier outil d'auteur à évaluer | Poses peintes, retouches, pièces et exports PNG | Installation non retrouvée aux emplacements examinés ; aller-retour natif non démontré |
| **Blender 5.1** | Utiliser lorsqu'un besoin de volume apparaît | Rubans, masques, caméra, rendu en séquence, Grease Pencil | Exécutable présent ; aptitude à produire notre effet peint non démontrée |
| **Adobe Animate** | Option si une vraie compétence Animate est disponible | Animation vectorielle, symboles, export de sprites | Ne pas l'adopter uniquement parce que Dofus l'a utilisé ; maintenance annoncée par Adobe |
| **Scripts d'export existants** | Réutiliser et adapter au besoin | Atlas, dimensions, alpha, provenance et contrôles | Un exporteur ne doit pas devenir un éditeur de dessin improvisé |
| **FFmpeg** | Facultatif pour les revues vidéo | Captures et encodage d'une séquence | Le PNG reste la source d'échange ; une vidéo de revue n'est pas un asset de jeu |
| **EmberGen** | Reporter | Simulation de fumée/feu avec sortie en images | Ne résout ni la direction artistique ni le timing d'un contact simple |
| **Houdini / Substance Designer / IlluGen** | Hors du premier pilote | Besoins procéduraux avancés à définir plus tard | Aucun besoin actuel ne justifie d'apprendre simultanément plusieurs générateurs |
| **Spine / outil de marionnette dédié** | Ne pas ajouter pour ce pilote | Pertinent si un futur effet comporte de nombreuses pièces articulées | Une rupture de peinture demande des poses ou des masques, pas nécessairement des os |
| **Unity / Unreal** | Supports d'étude seulement | Comprendre les exemples de studios | Les graphes et packages ne sont pas des assets Godot directement utilisables |

Krita est gratuit et open source ; sa documentation décrit l'animation raster, la timeline et les transformations animées.[^1] Blender propose une voie de dessin et d'animation 2D dans un environnement 3D.[^2] L'intérêt de ces deux outils réside ici dans les sources éditables et leurs usages complémentaires.

Adobe indique au 8 juin 2026 qu'Animate reste disponible et pris en charge, avec corrections et sécurité, mais sans nouvelles fonctionnalités prévues.[^3] Il demeure utilisable ; l'historique des pratiques d'Ankama n'oblige cependant pas à en faire une dépendance nouvelle. Son export distingue spritesheets et atlas avec données d'animation : ces sorties ne sont pas interchangeables avec notre grille de flipbook.[^4]

Les sorties d'EmberGen en atlas ou séquences RGBA rendent cet outil techniquement envisageable plus tard.[^5] Aucune comparaison locale n'a démontré qu'il serait plus efficace pour Catabase. Un achat se justifierait après un exercice montrant que la génération de volume, et non le dessin ou le rythme, constitue le principal obstacle.

## Compétences, ordre d'acquisition et preuves

| Priorité | Compétence | Exercice | Preuve attendue |
| --- | --- | --- | --- |
| 1 | Observer et décomposer | Étudier trois effets courts : contact, dissipation, protection ; noter l'information transmise et les couches supposées | Distinguer ce qui est observé de ce que l'on suppose sur la technique |
| 2 | Timing et espacement | Animer une silhouette simple selon trois rythmes, sans changer sa durée totale | Les trois versions donnent des sensations identifiables à vitesse réelle |
| 3 | Forme et valeurs | Réduire le contact à sa taille de jeu et le regarder en niveaux de gris | Direction et cible lisibles sans s'appuyer sur la teinte |
| 4 | Matière peinte | Traiter un seul pic avec deux ou trois grands groupes de valeurs et les accents Catabase | La peinture rejoint le décor sans faire disparaître le point de contact |
| 5 | Continuité des poses | Corriger la rupture ou la disparition d'une masse sur quelques images | Pas de changement involontaire de volume, de pivot ou de texture |
| 6 | Alpha et export | Exporter, importer, modifier une pose et réexporter | Durée identique, correction retrouvée, autres poses conservées |
| 7 | Pièces et particules | Ajouter trois éclats d'abord dirigés, puis comparer à une émission paramétrée | L'ajout renforce le contact sans attirer davantage l'œil |
| 8 | Matériau simple | Comparer fondu et érosion d'une même poussière | Disparition dirigée, pause/replay identiques, absence de clignotement |
| 9 | Intégration | Jouer l'effet sur une cible réellement touchée dans plusieurs orientations | Aucun doublon, point d'impact exact et règles inchangées |
| 10 | Qualité et coût | Comparer avec/sans effet, première lecture et répétitions | Rendu acceptable, mesures et nettoyage sans erreur |

Ces preuves ne sont pas obtenues par le visionnage d'un tutoriel. Chaque exercice demande une production, une critique et au moins une correction. Le dossier précédent d'Éclat de fresque couvre une recherche statique ; il ne valide pas encore les compétences 2, 5 ou 9.

## Parcours pratique

### Exercice A — lire un effet avant de le construire

Choisir une référence Dofus publiée par son auteur, un exemple de matériau RiME et un effet répondant à une règle comparable de Catabase. Observer début, maximum, rupture et fin. Relever la silhouette dominante, la direction, le point focal, la quantité de secondaires et ce qui reste visible derrière l'effet.

Noter séparément les mécanismes établis par l'auteur et les hypothèses visuelles. Une forme douce peut être une texture, une simulation rendue ou un shader : le seul aspect de l'image ne tranche pas. Livrable : une fiche d'une page par effet, avec lien, repères temporels relevés sur la vidéo réellement examinée et trois principes transférables.

### Exercice B — réussir le rythme sans texture

Construire un contact de faible complexité. Garder un point fixe et produire trois variantes : ouverture immédiate, ouverture après compression, pic tenu plus longtemps. Comparer à même durée totale sur le même fond. Le nombre de dessins est un moyen ; il ne constitue pas le critère de réussite.

Le pic « Éclat de fresque » peut servir d'intention, mais une forme plus simple peut être préférable pour cet apprentissage. Le résultat doit déjà évoquer la bonne action avant de recevoir sa peinture. Si les versions semblent identiques, travailler les espacements et les maintiens avant d'ajouter des images.

### Exercice C — éprouver l'outil d'auteur

Importer ou créer les quelques poses dans Krita, garder une source native, corriger une seule pose, puis exporter une séquence PNG avec les répétitions temporelles. Le fichier OpenRaster déjà préparé est une source en calques statiques, pas un projet d'animation terminé.

La documentation de scripting Krita permet l'import d'images dans la timeline mais indique des limites à l'export automatique configurable.[^6] Il faut donc vérifier l'aller-retour réel plutôt que promettre une automatisation complète. Les actions de retouche au pinceau et le pilotage de l'application ne sont pas encore démontrés dans cette chaîne.

Si cette étape demeure trop difficile, essayer des pièces peintes à transformations contrôlées et un masque animé. Si cette méthode ne permet pas le mouvement recherché, réduire la complexité ou faire réaliser les poses clés et une critique par un animateur FX. La capacité graphique de l'équipe doit être évaluée par l'exercice, sans supposer qu'elle est absente ou déjà acquise.

### Exercice D — premier aller-retour jusqu'au moteur

Créer un atlas conforme au lecteur actuel, accompagné de son manifeste. Employer le laboratoire existant pour vérifier les poses et le temps. Revenir à la source, modifier la pose choisie et refaire exactement le même export.

Conserver les noms de source, dimensions, pivot, cadence, ordre et versions de l'outil. Le contrôle décisif : pouvoir retrouver la différence voulue à un instant précis, sans modification involontaire ailleurs. Avant de déclarer cet exercice validé, résoudre l'échec strict de fermeture actuellement observé sur les tests de flipbooks.

### Exercice E — enrichissement et essai joueur

Ajouter un seul type de secondaire, puis une éventuelle érosion. Comparer avec et sans chaque couche. Enfin, brancher l'effet sur les événements réels et le regarder pendant un combat, avec le HUD, les nombres et les autres unités.

L'essai doit vérifier la lecture spontanée : où le coup est parti, quelle cible a été touchée, s'il s'agit d'une frappe, d'un soin ou d'une protection. Une réponse correcte après une explication ne vaut pas une lecture immédiate. Une fois ce pilote satisfaisant, produire un second effet de même famille pour mesurer ce que la recette permet réellement de réutiliser.

## Répartition réaliste du travail

| Travail | Assistance technique / automatisation | Décision ou savoir-faire artistique |
| --- | --- | --- |
| Références | Rechercher, dater, ranger et rapprocher les sources | Choisir les caractéristiques compatibles avec Catabase |
| Conception | Préparer des variantes d'intention et des fiches | Sélectionner une silhouette et le sens du mouvement |
| Mouvement | Construire des courbes et des comparaisons à paramètres constants | Juger le poids, les pauses et la rupture |
| Dessin | Préparer des calques et des explorations visuelles | Créer ou corriger les poses cohérentes et les contours |
| Export | Répéter, assembler, valider dimensions et provenance | Vérifier les pertes de matière et la lecture à petite taille |
| Intégration | Écrire l'adaptateur, tester événements et nettoyage | Juger le rendu en situation avec l'ensemble du jeu |

La génération d'images est une aide possible à l'exploration. Son résultat doit devenir une source que l'on peut corriger ; produire de nouvelles images à chaque étape sans continuité contrôlée ne constitue pas une méthode fiable d'animation.

## Ressources d'apprentissage ciblées

| Ressource | À en tirer | Limite |
| --- | --- | --- |
| [Riot — Visual Effects](https://www.riotgames.com/en/artedu/visual-effects) | Articuler information de jeu et cohérence du kit | Ne fournit pas notre implémentation Godot |
| [Pingault — Huppermage](https://www.behance.net/gallery/74754737/2D-ANIMATION-FX-Dofus-GAME-Huppermage) et [Xélor](https://www.behance.net/gallery/75090073/2D-ANIMATION-FX-Dofus-GAME-Xlor-) | Étudier les formes, variantes et révisions | Productions historiques, fichiers internes absents |
| [Deeamo — Masterclass Explosion 2D](https://dojo.deeamo.fr/index.php/en/explosion2d/) | Option de formation courte centrée sur une fabrication et des sources | Programme commercial seulement consulté ; cours non suivi, efficacité non évaluée |
| [VFX Apprentice — Foundations](https://www.vfxapprentice.com/courses/vfx-foundations-artistic-principles) | Programme de principes et de vocabulaire | Ne pas confondre durée de leçon et acquisition du savoir-faire |
| [Krita — Animation](https://docs.krita.org/en/user_manual/animation.html) | Fabriquer et corriger les poses | Demande un vrai exercice dans l'éditeur |
| [RiME — Simon Trümpler](https://simonschreibt.de/gat/stylized-vfx-in-rime/) | Comprendre matériau, masque et particules | Transposer les mécanismes, pas les fichiers Unreal |
| [Godot — Particules 2D](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html) | Apprendre l'émission et le cycle de vie | Certains passages signalés comme non actualisés pour 4.7 |
| [Real-Time VFX — Getting Started](https://realtimevfx.com/t/getting-started-in-real-time-vfx-start-here/3415) | Vocabulaire, exemples et lieux de critique | Ressource communautaire ancienne et évolutive ; anciens outils cités |

Le programme Deeamo annonce des explications image par image, des fichiers sources et une méthode transposable au-delà d'Animate.[^7] Cette correspondance avec le besoin justifie de l'examiner ; elle ne justifie pas un achat automatique. Commencer par les ressources publiques et l'exercice B permettra d'identifier la lacune précise à combler.

## Budget et décisions

La proposition n'impose aucun nouvel abonnement pour démarrer. Aucun achat, installation ou contact externe n'est effectué dans ce plan. Une tablette graphique est à envisager si la peinture manuelle devient la voie retenue ; la disponibilité et la préférence matérielles ne sont pas établies ici.

Ne pas annoncer « un sort par jour » avant d'avoir produit et corrigé deux effets. Pour chaque exercice, mesurer temps de dessin, réglages, traitement, attente, nombre de reprises et temps de validation. Ces chiffres permettront de décider entre apprentissage interne, construction paramétrique et apport ponctuel d'un spécialiste.

L'ordre recommandé reste : **lecture → rythme → source corrigible → export → composition → combat**. Le prochain travail concret est l'exercice de rythme, accompagné d'une vérification de la retouche native et du diagnostic des ressources restantes à la fermeture. La production d'un kit complet vient ensuite.

## Sources complémentaires

Consultation : 12 septembre 2026. Les sources sur les studios et les rapports locaux figurent dans le dossier principal.

[^1]: Krita, [site officiel](https://krita.org/) et [Animation with Krita](https://docs.krita.org/en/user_manual/animation.html), manuel consulté ; gratuité et capacités d'auteur.
[^2]: Blender Foundation, [Story Artist](https://www.blender.org/features/story-artist/), page officielle non datée.
[^3]: Adobe, [Animate maintenance mode FAQs](https://helpx.adobe.com/animate/desktop/kb/maintenance-mode.html), mise à jour du 8 juin 2026. État actuel retenu face aux annonces contradictoires plus anciennes.
[^4]: Adobe, [Export animations for mobile apps and game engines](https://helpx.adobe.com/animate/desktop/exporting-and-publishing/create-sprite-sheet.html), mise à jour du 9 juin 2026.
[^5]: JangaFX, [EmberGen — Getting Started](https://docs.jangafx.com/embergen/pages/getting_started.html), documentation consultée.
[^6]: Krita Scripting School, [Animation](https://scripting.krita.org/lessons/animation), page non datée, import de séquences et limites de l'export configurable.
[^7]: Julien Pingault / Deeamo, [Masterclass Explosion 2D](https://dojo.deeamo.fr/index.php/en/explosion2d/), page commerciale non datée ; description du programme, sans validation indépendante du cours.
