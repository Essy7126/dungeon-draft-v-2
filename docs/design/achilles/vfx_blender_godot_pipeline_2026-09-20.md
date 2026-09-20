# VFX Catabase — chaîne Blender → Godot reproductible

Recherche du 20 septembre 2026. Proposition de production, sans nouvel effet fabriqué ni validation artistique. Complément à [la recherche du 12 septembre](vfx_pipeline_research_2026-09-12.md) et à [l'étude du contact du Péléide](vfx_feasible_construction_2026-09-12.md).

## Décision proposée

Employer **Blender comme atelier de formes et de mouvements**, puis **Godot comme compositeur et lecteur de combat**. Pour la présentation peinte de Catabase, privilégier les rendus transparents en atlas, complétés par quelques éléments paramétrables. Réserver la 3D temps réel aux effets dont la profondeur ou la rotation apporte un bénéfice visible.

Cette chaîne est une adaptation au projet. Les sources consultées n'établissent pas la pipeline complète des sorts de Dofus 3. Une référence au Dofus historique, à Waven ou à un autre jeu Ankama ne prouve pas le procédé interne de Dofus 3.

## Sources de production et portée

| Source primaire consultée | Ce qu'elle établit | Application proposée |
| --- | --- | --- |
| [Julien Pingault — DOFUS Eniripsa](https://deeamo.artstation.com/projects/d8l94Q), et [sa présentation DOFUS](https://deeamo.fr/dofus-x-deeamo-lanimation-de-fx-dans-le-jeu-dankama/) | Travail personnel d'animation FX 2D pour plusieurs classes. Les pages ne décrivent pas leur conversion actuelle dans Unity. | Étudier les silhouettes et les phases du mouvement ; construire des sources dont les poses restent corrigibles. |
| [Jérémie Segura — profil professionnel](https://fr.linkedin.com/in/jeremie-segura) | Témoignage sur les nouveaux rendus et effets de Dofus lors du portage Unity ; compétences en shaders, éclairage et outils. Texte accessible dans l'index, ouverture directe bloquée. | Considérer les matériaux et l'intégration comme du travail de production à part entière. Cela ne renseigne pas l'outil d'auteur de chaque sort. |
| [Romain Pergod — Cosmobot, post-mortem](https://sephyka.com/game-post-mortem/ankama-cosmobot/) | Usage explicite de Unity Shuriken pour les FX ; exemple distinct de shader de vortex, avec lien vers son code. | Composer un effet avec plusieurs éléments et un matériau spécialisé. Transposer les mécanismes dans Godot. |
| [Riot — concours VFX 2023](https://www.riotgames.com/en/news/vfx-contest-league-valorant-2023) | Décomposition lancement, projectile, explosion de zone, sortie ; critères de couleur, valeur, timing et formes. | Donner un rôle à chaque phase ; juger le rythme et la silhouette avant les embellissements. |
| [Riot — guide VFX 2017](https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/) | Guide centré sur lisibilité, encombrement, thème et plaisir visuel. Texte consultable par indexation ; l'URL redirige actuellement à l'ouverture. | Proportionner la présence visuelle à l'importance de l'action. |
| [Simon Trümpler — Stylized VFX in RiME](https://simonschreibt.de/gat/stylized-vfx-in-rime/) | Présentation de trois effets, publication autorisée de ressources de matériaux et compléments techniques. La page mêle ensuite RiME et d'autres contributions. | Étudier l'érosion et les matériaux spécialisés ; ne pas attribuer toutes les techniques de la page à RiME. |
| [GodotCon 2025 — Making Stylized 3D Games in Godot](https://talks.godotengine.org/godotcon-us-2025/talk/QXD8TR/) | Les auteurs de Skull Scavenger annoncent un procédé associant personnages Blender, shaders et cadence réduite par asset. Page de présentation consultée, conférence non analysée intégralement. | Le duo Blender/Godot peut servir une esthétique dessinée ; une cadence artistique distincte du jeu est une option. |

Le portfolio Waven de Benjamin Philippot confirme son rôle et ses compétences, sans établir une recette complète. « Waven Execution VFX » de Romain Maquoi est un test de recrutement. Les résultats de recherche sur « Waven Spells VFX » de Sylvain Guerrero renvoient à une publication dont le texte n'a pas été récupéré directement : ne pas la présenter comme un breakdown vérifié ici.

## Choisir le bon support

| Voie | Intérêt | Limite | Place proposée |
| --- | --- | --- | --- |
| Blender → PNG RGBA → flipbook Godot | Perspective et silhouettes stables ; animation inspectable image par image ; rendu indépendant du shader Blender | Mémoire des atlas, vues précalculées, modifications nécessitant un rendu | Voie principale pour contact, poussière, protection, apparition |
| Texture/forme → sprite, particules et shader Godot | Durée, trajet, taille et dispersion ajustables en jeu | Demande une gestion du temps, des ancrages et du nettoyage | Projectiles, secondaires, sceaux, érosion |
| Blender → GLB → matériau Godot | Rotation, volume et attachement à un objet 3D | Profondeur, transparence et raccord avec le plateau 2D à résoudre | Option ciblée pour un dôme, des rochers ou une invocation |

Godot documente les flipbooks de particules précalculés dans Blender : [particules 2D](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html). Le GLB est une voie d'échange recommandée pour la 3D : [formats importés](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html). Les matériaux procéduraux Blender, Geometry Nodes et simulations ne constituent pas un effet Godot directement transportable : rendre leurs résultats en images ou exporter une géométrie compatible, puis reconstruire le matériau et le comportement nécessaires dans Godot.

## Recette reproductible

1. **Fiche d'effet.** Définir action, cible, direction, point d'ancrage, instant de contact, durée, dimensions en cellules et information à préserver. Distinguer silhouette principale, résidus et marque au sol. Conserver une palette Catabase : bronze, terre cuite, ivoire ponctuel, ombre pétrole.
2. **Scène Blender native.** Caméra orthographique fixe, repère de sol, proxy d'Achille et calibration sur la projection effective. Construire rubans, anneaux, fragments et trajectoires avec des maillages, courbes ou paramètres explicites. Grease Pencil peut fournir des accents dessinés et des poses : [présentation officielle](https://www.blender.org/features/grease-pencil/). Les simulations lourdes restent optionnelles.
3. **Rythme contrôlé.** Concevoir ouverture, pic, rupture et disparition. Comparer trois variantes avec la même géométrie. Pour un effet déclenché après confirmation des dégâts, commencer au contact ; l'anticipation appartient au geste de l'attaquant. Évaluer sans glow à taille de jeu.
4. **Rendu transparent.** Exporter une séquence PNG RGBA, cadrage constant et pivot commun. Séparer les plans avant/arrière lorsqu'un effet entoure un personnage. Fixer explicitement gestion des couleurs, moteur, cadence, graines et version Blender. Vérifier le mélange sur fonds clairs et sombres avant de figer la convention d'alpha.
5. **Assemblage déterministe.** Un script d'export produit atlas réguliers, aperçu, manifeste compatible et empreintes des sources. Préserver les cases carrées attendues par le validateur ; les marges transparentes restent à l'intérieur de chaque case. Ne pas employer un packing arbitraire avec rotation ou recadrage par image.
6. **Composition Godot.** Le flipbook porte le mouvement principal. Quelques sprites dirigés ou `GPUParticles2D` ajoutent débris et poussière ; un shader peut éroder une texture ou déplacer ses UV. Piloter sa progression avec l'horloge de l'effet pour pause/replay. Séparer le projectile mobile de l'impact fixe et de l'empreinte au sol.
7. **Intégration réelle.** Réutiliser `VFXManager`, les scènes/profils et les faits de présentation. Respecter victimes résolues, annulation, pause et fin de combat. Les effets ne calculent aucun dégât. La transformation de la source à l'export ne doit pas changer la chronologie du gameplay.
8. **Aller-retour de correction.** Modifier un paramètre visible, relancer le même export et vérifier le changement en combat. Une correction retrouvée sans décaler les autres phases est la preuve utile de reproductibilité.

Une hypothèse initiale de 16 images à 30 images/s donne environ 0,53 s, pas une norme à appliquer à tous les effets. Avec 16 cases de 256 pixels, un atlas 4 × 4 représente 1024 × 1024 pixels : **4 Mio en RGBA8 non compressé, sans mipmaps**. Quatre directions occupent 16 Mio dans les mêmes conditions. Le poids PNG sur disque ne mesure pas la mémoire GPU ; dimensions, compression et nombre de vues doivent être décidés ensemble.

La projection locale est un losange 2:1, avec des dimensions par défaut de 128 × 64. Une onde sur le sol doit respecter ce plan. Un impact face à la caméra garde ses proportions propres. Une rotation d'image 2D ne remplace pas toujours une nouvelle vue d'un volume asymétrique. Le calibrage doit éviter d'aplatir deux fois un rendu déjà projeté.

## Pilote conseillé : Balayage d'airain

Choisir une nouvelle variante de présentation de l'action de balayage existante. Elle éprouve le ruban Blender, l'orientation, le contact, les secondaires et l'ancrage, avec moins de complexité qu'une simulation volumique.

| Couche | Construction | Fonction |
| --- | --- | --- |
| Croissant principal | Ruban effilé animé dans Blender, matière mate avec accent ivoire court ; rendu en vues nécessaires | Donner direction et largeur au geste |
| Contact | Petite ouverture anguleuse, distincte du croissant | Marquer uniquement les victimes réellement touchées |
| Fragments | Trois à six éclats aux trajectoires courtes ; bake ou sprites dirigés | Donner du poids et rappeler le bronze |
| Poussière au sol | Texture/flipbook discret, ancré sur le plan du plateau | Relier l'action au décor sans couvrir la grille |

Réglage exploratoire : contact immédiatement lisible, expansion sur environ 30–60 ms, rupture dans les 100–180 ms, résidus terminés vers 350–500 ms. Ces valeurs sont une proposition à juger dans le jeu, pas une mesure de Dofus. Ne pas ajouter une attente de préparation après une résolution déjà effectuée.

Livraison attendue : fichier `.blend` corrigible, script de construction/export, recette paramétrée, PNG/atlas, manifeste, profil ou scène Godot, aperçu animé et captures en combat. Le paramètre de largeur du ruban et la durée des résidus doivent pouvoir être corrigés séparément.

Après ce pilote, **Garde d'airain** teste une autre difficulté : activation, maintien jusqu'à fin de l'état, réaction au coup, extinction. Le maintien ne doit pas être une durée arbitraire gravée dans une longue vidéo. Prévoir les parties devant/derrière le héros ou une intégration 3D dédiée si nécessaire.

## Ce que je peux produire

| Famille | Résultat envisageable | Partie à éprouver |
| --- | --- | --- |
| Lance, épée, balayage | Rubans effilés, contact peint, éclats de bronze | Accord exact avec le geste et les directions |
| Garde, rempart | Arcs de protection, motifs de métal, pulsation au coup, fragmentation finale | Occlusion et cycle de vie de l'état |
| Feu des Enfers | Langues de feu stylisées, braises, impact, résidu de cendre | Formes vivantes et lecture sur fonds chauds |
| Styx, onde, portail | Rubans liquides, cercles déformés, tourbillon, écume | Silhouette et raccord avec le plan du sol |
| Foudre | Ramification dirigée, flash local, fissure ou marque brève | Hiérarchie des branches et intensité confortable |
| Invocation, mort | Assemblage de fragments, montée de poussière, érosion d'une silhouette | Identité figurative et interaction avec le personnage |

Je peux écrire les scripts Blender Python, fabriquer des géométries et animations paramétrées, réaliser les exports et écrire shaders/scènes GDScript. Cette capacité technique ne promet pas automatiquement la finesse d'un animateur FX spécialisé dans le dessin image par image. Les effets très figuratifs ou les transformations organiques demandent davantage de poses conçues et corrigées. La qualité doit être jugée sur un effet joué, à sa taille réelle, puis sur une correction réussie.

## Raccord au dépôt et vérification

Lecture au HEAD `6542c427ae54f36b9e146fdef28ec32af308a2a1`. Le worktree contient de nombreuses modifications d'autres travaux ; cette recherche ajoute seulement le présent document. Blender **5.1.2** confirmé avec `--version`. Godot **4.7.1** est la version prescrite par `tools/dev/toolchain.json` ; moteur et import non exécutés pour cette recherche.

- [VFXFlipbookAsset](../../../vfx/data/vfx_flipbook_asset.gd) : cadence, pivot, taille nominale, alpha, qualité, statuts et variantes déjà présents.
- [Validateur de manifeste](../../../vfx/services/vfx_flipbook_manifest_service.gd) : champs, dimensions et checksums à réutiliser.
- [Lecteur flipbook](../../../vfx/modules/vfx_flipbook_visual.gd) : atlas régulier via `hframes/vframes`, rotation fixe par module, lecture à cadence source ou ajustée à la durée. Les variantes sont actuellement choisies par graine : **elles ne constituent pas une sélection automatique de direction**. Celle-ci doit être décidée explicitement lors du pilote.
- [VFXManager](../../../core/vfx_manager.gd) et [contrat du kit Achille](../../../vfx/achilles_kit/README.md) : trajets, confirmation des impacts et nettoyage existent. La production proposée doit s'y raccorder, sans supposer que chaque profil est déjà relié à chaque sort.
- [Projection](../../../battle/iso/iso_projection.gd) : base métrique à lire au runtime.
- `project.godot` désactive l'import automatique des `.blend` : conserver les sources natives et livrer des PNG ou GLB explicites.

Le rapport du 12 septembre signalait des ressources encore actives à la fermeture de tests. Ce résultat est historique : il faut le reproduire sur le candidat d'implémentation avant de décider d'une correction. Aucun test n'a été relancé ici et aucun nouvel atlas n'a été produit.

Pour le pilote : import Godot, tests ciblés VFX/kit, lecture des rapports complets en cas d'erreur, revue des directions, fonds clair/sombre, petite taille, pause/replay, annulation et fin de combat ; mesure comparative de 1/4/10 instances et contrôle du premier lancement. Conserver les validations CI obligatoires lors de l'intégration ; élargir la suite si le moteur commun change. Les passages documentaires Godot signalés comme non actualisés pour 4.7 demandent une vérification locale lors de l'implémentation.

Prochaine étape concrète : fabriquer le pilote Balayage d'airain, le corriger depuis sa source puis mesurer le coût de cette boucle. Aucun délai de production par sort ni qualité finale de studio n'est établi par cette recherche.
