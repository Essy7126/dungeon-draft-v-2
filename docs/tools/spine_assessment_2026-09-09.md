# Spine — apports et essai proposé

Recherche documentaire du 9 septembre 2026. Les chapitres pertinents ont été
consultés, pas l'intégralité du manuel. Aucun essai local de Spine, achat,
installation ou export Spine n'a été réalisé pour cette évaluation.

## Décision proposée

Utiliser la documentation et les projets pédagogiques Spine dès maintenant
comme références de méthode. Considérer l'éditeur comme candidat pour une
production 2D articulée avec remplacement de dessins, à confirmer par un essai.
Ne pas déclarer la qualité acquise : les variantes du pilote Sentinelle ont été
rejetées pour leur mécanique corporelle et leurs directions.

Le pipeline `tools/catabase_monster_sprite_pipeline/` possède déjà une hiérarchie
articulée et de l'IK des pieds. Le gain à démontrer avec Spine concerne donc
l'édition des poses, les raccords, les déformations et la facilité de correction.
Ajouter des os ne suffit pas à résoudre le défaut artistique.

## Index ciblé de documentation

| Problème | Documentation primaire | Usage et limite |
| --- | --- | --- |
| Bras animé sans engagement du corps | [Animating](https://esotericsoftware.com/spine-animating), [Bones](https://esotericsoftware.com/spine-bones) | Poses majeures du corps entier, puis corrections par passes ; la hiérarchie transmet les transformations, mais ne conçoit pas la mécanique du mouvement. Le manuel avertit explicitement du risque de mouvements déconnectés avec les passes séparées. |
| Pieds qui glissent, main mal placée | [IK constraints](https://esotericsoftware.com/spine-ik-constraints) | Cibles de mains/pieds avec résolution d'un ou deux os. Ne résout pas automatiquement l'équilibre ou les contre-rotations du corps entier. |
| Épaules disjointes, silhouette instable | [Weights](https://esotericsoftware.com/spine-weights) | Dessins réutilisés, maillages pondérés et raccords à régler. Hypothèse pour la Sentinelle : conserver surtout l'armure et l'arme rigides pour éviter un aspect caoutchouc. |
| Raccourcis et parties cachées lors d'une rotation | [Alien example](https://esotericsoftware.com/spine-examples-alien), [Demos](https://esotericsoftware.com/spine-demos) | Combiner articulation, dessins de remplacement et ordre d'affichage. Alien démontre la combinaison image par image/maillage ; ce n'est pas un modèle complet de retournement isométrique. Les nouvelles vues restent à dessiner. |
| Variantes de personnages | [Skins](https://esotericsoftware.com/spine-skins), [Import](https://esotericsoftware.com/spine-import) | Réutilisation sur une structure compatible ; l'import d'animation dépend des noms des éléments et, pour les déformations, du nombre de sommets. Pas de transfert automatique entre morphologies différentes. |
| Cape, cheveux, accessoires | [Physics constraints](https://esotericsoftware.com/spine-physics-constraints) | Mouvements secondaires après validation du geste principal. Faible priorité pour notre premier essai. |

Pour économiser du contexte : conserver cet index problème → chapitre → exemple,
puis de petites recettes éprouvées sur nos personnages. Consulter les chapitres
complets utiles à chaque opération ; ne pas injecter tout le manuel à chaque fois.

## Ressources complémentaires prioritaires

1. [Projets officiels Spine](https://esotericsoftware.com/spine-examples) : ouvrir
   les fichiers sources pour examiner les clés, hiérarchies et poids. Spineboy
   pour l'articulation ; Alien pour les dessins de remplacement ; Mix-and-match
   pour les variantes. Leur existence ne prouve pas leur adéquation à notre caméra.
2. Les vidéos **Animating with Spine**, accessibles depuis le chapitre Animating,
   pour l'anticipation, les arcs et la propagation du mouvement.
3. [Animation Mentor — Body mechanics](https://www.animationmentor.com/animation-program/body-mechanics/)
   et [The Animator's Survival Kit — Richard Williams](https://us.macmillan.com/books/9780865478978/theanimatorssurvivalkit/)
   pour étudier les appuis, le poids et le rythme indépendamment du logiciel.
4. Les références par personnage de
   [notre sélection](sprite_motion_references_2026-09-09.md) : lancier pour l'estoc,
   combattant lourd pour la masse, quadrupède pour le molosse, et la ruée d'Achille
   comme référence interne. Les ressources externes restent à examiner en mouvement.

Les [asset packs officiels](https://esotericsoftware.com/spine-asset-packs)
fournissent aussi des projets éditables. Hitman et Gunman sont des exemples de
profil : ce ne sont pas des bases directement validées pour notre lancier isométrique.

## Contrôle et intégration proposés

Chemin initial : référence animée → poses complètes → dessins séparés et
remplacements nécessaires → animation Spine → séquence PNG → Sprite Workshop →
SpriteFrames Godot. Garder les événements de combat et leurs contrôles dans notre
pipeline : une séquence PNG ne transporte pas à elle seule les événements Spine.

La [CLI](https://esotericsoftware.com/spine-command-line-interface),
l'[import](https://esotericsoftware.com/spine-import) et l'[export](https://esotericsoftware.com/spine-export)
permettent d'envisager un adaptateur de fichiers et de commandes. Spine documente
le traitement externe de JSON suivi d'un réimport. Conserver le projet `.spine`
comme source et vérifier les allers-retours, notamment les données d'édition.
L'export d'images nécessite un environnement graphique/OpenGL.
Cet adaptateur et notre capacité à produire des poses convaincantes par ce moyen
ne sont pas testés. Aucun connecteur Spine dédié n'est exposé dans cette session.

Le [runtime Godot officiel](https://esotericsoftware.com/spine-godot) existe en
GDExtension et en module moteur ; leurs capacités diffèrent. La GDExtension ne
prend actuellement pas en charge AnimationPlayer. La compatibilité avec notre
Godot 4.7.1 reste à tester. Ce runtime n'est pas nécessaire au premier essai PNG.

Les maillages et l'IK nécessitent **Professional**. La
[version d'essai](https://esotericsoftware.com/spine-download) permet d'explorer
les fonctions, mais pas de sauvegarder ni d'exporter notre travail : elle ne suffit
pas à livrer un pilote personnel complet dans Godot.

## Essai qui déciderait de l'adoption

- Un personnage : Sentinelle ; une action : estoc ; une direction frontale d'abord.
- Construire garde, préparation, engagement, contact et retour avec bassin,
  thorax, tête, appuis, arme et bouclier définis ensemble ; inspecter sans interpolation.
- Régler ensuite timing, interpolation et raccords avec la référence visible.
- Contrôler à taille de jeu : poids lisible, pieds stables, proportions, direction
  de la pointe et continuité du bouclier. Ne pas confondre des tests d'import réussis
  avec une validation artistique.
- Ajouter une vue arrière pour éprouver les parties masquées et l'ordre d'affichage.
- Mesurer temps et nombre de corrections, dessins supplémentaires nécessaires,
  export reproductible et contrôles Godot. Si le geste reste mauvais, réexaminer
  poses/référence/rig avant d'étendre l'outillage à tous les personnages.

Statut : proposition documentée ; aucune supériorité visuelle de Spine démontrée
sur nos sprites à ce stade.

## Complément — extensions Godot et connecteurs MCP

Recherche complémentaire du 9 septembre 2026. Aucun connecteur officiel
ChatGPT/Codex pour Spine d'Esoteric Software n'a été trouvé dans les sources
consultées. Plusieurs serveurs MCP communautaires existent cependant. Aucun
n'est connecté dans cette session ; aucun n'a été installé, exécuté ou validé
sur Windows/Godot pour ce projet. La lecture de documentation et de quelques
fichiers sources ci-dessous constitue une présélection, pas un audit complet.

| Candidat | Apport documenté | Limite et décision proposée |
| --- | --- | --- |
| [spine-motion-mcp — nihatcagri44](https://github.com/nihatcagri44/spine-motion-mcp) | Inspection d'un rig existant, clés et courbes, modèles de mouvements, aperçu web/GIF, import/export CLI. Serveur MCP HTTP local ; format et lecteur Spine 4.2. | Premier candidat à essayer pour modifier et observer un mouvement. Version 0.1 ; création de maillages/déformations et construction du rig depuis PSD encore prévues. Le fichier TESTING.md précise que les paramètres CLI restent à tester sous Windows. |
| [spine-mpc-attrom — Attrom](https://github.com/Attrom/spine-mpc-attrom) | Le README décrit une documentation de squelette, des sondes d'influence des os, un corpus d'exemples, des transformations JSON et comparaisons après réimport. | Piste pour la documentation et les contrôles. Plus large que notre besoin initial ; le qualificatif « production-grade » appartient à l'auteur et n'est pas une validation de notre part. Il précise ne pas contrôler les mécanismes internes de l'éditeur ni garantir la conservation de tout son état. |
| [spine-mcp — egorfedorov](https://github.com/egorfedorov/spine-mcp) | Construction depuis pièces PSD/PhotoshopToSpine, atlas et conversion CLI. | Le code server.py limite actuellement la génération à une structure corps/tête et aux animations idle/win/blink/pop. Ce n'est pas une base validée pour nos attaques articulées. Chemin CLI macOS par défaut, configurable. |
| [spine_anim_mcp — K-ulucay](https://github.com/K-ulucay/spine_anim_mcp) | Le README propose des générateurs paramétriques de marche/course/saut/attaque et un rig humanoïde. | Le même README laisse l'extraction réelle des pixels des pièces vers l'atlas et la confirmation dans Spine/runtime en travaux. Les aperçus utilisent un moteur de rendu indépendant. Ne pas assimiler les exemples affichés à une intégration Spine/Godot validée. |

Lectures techniques ciblées :

- [spine-motion-mcp : checklist Windows](https://github.com/nihatcagri44/spine-motion-mcp/blob/main/TESTING.md),
  [adaptateur CLI](https://github.com/nihatcagri44/spine-motion-mcp/blob/main/src/spine/cli.ts),
  [serveur](https://github.com/nihatcagri44/spine-motion-mcp/blob/main/src/server.ts)
  et package.json. Les appels passent par les fichiers et la CLI officielle ;
  cela ne démontre pas le pilotage interactif de l'éditeur Windows.
- [egorfedorov : outils exposés](https://github.com/egorfedorov/spine-mcp/blob/main/server.py)
  et spine_cli.py ; le périmètre réel est plus étroit que le titre général du dépôt.
- Attrom : README et package.json uniquement ; les fonctions annoncées restent
  à confronter au code et à un essai avant sélection.

### Documentation à relier à notre chaîne

1. [Scripts officiels d'export graphique](https://github.com/EsotericSoftware/spine-scripts)
   pour les dessins en calques et leurs positions.
2. [Méthodes d'animation](https://esotericsoftware.com/spine-animating) et
   [projets d'exemple](https://esotericsoftware.com/spine-examples) pour les poses,
   rigs et raccords.
3. [Format JSON](https://esotericsoftware.com/spine-json-format),
   [import](https://esotericsoftware.com/spine-import) et
   [CLI](https://esotericsoftware.com/spine-command-line-interface) pour la
   modification contrôlée et les exports reproductibles.
4. [Guide Godot officiel](https://esotericsoftware.com/spine-godot) pour la
   GDExtension et ses exemples : 01-helloworld, 02-animation-state-listener,
   03-mix-and-match, 06-bone-following et 07-slot-node.

Le chemin direct envisageable est : dessins préparés → projet Spine →
modifications par MCP et vérification visuelle → export JSON/binaire + atlas →
GDExtension officielle → scène de contrôle Godot. L'export PNG reste une sortie
possible pour notre lecteur existant. La GDExtension lit et manipule les animations
dans le jeu ; elle n'embarque pas l'éditeur de création Spine dans Godot.

Avant adoption : choisir une combinaison cohérente de versions éditeur/JSON/
lecteur/GDExtension, vérifier un exemple officiel sur Godot 4.7.1, puis modifier
une pose via le connecteur et comparer avant/après réimport dans Spine et Godot.
Le premier test de connexion/format doit précéder l'essai artistique Sentinelle.
Conserver le projet `.spine` original et les données d'édition lors des exports.
Ne pas lancer l'indexation de toutes les ressources pour commencer : une fiche
de rig et quelques exemples adaptés suffisent pour éprouver la méthode.
