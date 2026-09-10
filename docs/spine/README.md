# Spine — dossier de reprise local

## Dernière livraison — six sorts Passe-rive V1

La [palette de six gestes](../../art/source/characters/achilles/passe_rive_spells_v1/README.md)
contient 24 poses peintes, leurs PNG/atlas, les chronologies et un laboratoire
jouable dans le navigateur et Godot. [Ouvrir l’essai](http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html).
Quatre familles du jeu et deux propositions, une seule direction ; aucun
remplacement de la campagne. Les entrées, déclenchements et imports sont vérifiés,
la qualité artistique reste à juger. Les poses sont produites en 2D avec ImageGen,
sans nouveau rig, puis détourées avec Birefnet.

## Livraison précédente — marche peinte Passe-rive V3

La [marche peinte V3](../../art/source/characters/achilles/passe_rive_walk_v3/README.md)
contient douze PNG transparents, un atlas, un aperçu animé et une ressource
SpriteFrames vérifiée dans Godot. [Ouvrir la revue](http://127.0.0.1:8734/files/passe_rive_walk_v3/review.html).
Le résultat provient d'ImageGen guidé par les poses Blender ; il attend la revue
artistique, notamment les contacts peints. Aucun job Higgsfield ou Ludo n'est
revendiqué comme exécuté pour cette livraison.

## Dernière décision — recherche de production, 10 septembre 2026

La [marche Blender V2](../../art/source/blender/passe_rive_walk_v2/README.md)
a reçu un retour positif sur le raccordement des pieds. Elle reste un mannequin,
sans validation d'un kit peint final. Le [dossier de recherche](../design/achilles/sprite_generation_research_2026-09-10.md)
compare les méthodes de studios, les générateurs spécialisés et les références
réutilisables. Il recommande un essai limité de Ludo avant de nouveaux travaux
d'infrastructure ; aucun essai Passe-rive avec ce service n'est encore validé.

Pour reprendre avec peu de contexte, lire la [mémoire courte d'animation](../ai/animation_memory.md),
puis seulement les preuves nécessaires. Les sections suivantes conservent
l'historique des essais.

## Étape précédente — Passe-rive, marche et idle V1, 10 septembre 2026

L'utilisateur a choisi le nouvel Achille Passe-rive et demande d'abord une seule
direction soignée. Le [socle de mouvement](../../art/source/characters/achilles/passe_rive_motion_v1/README.md)
contient huit dessins de marche RGBA, un idle sur la référence originale, une
revue interactive et un projet Godot autonome vérifié. Le détourage logiciel
local est explicitement autorisé. **La marche reste un essai non validé** :
appuis, transfert de poids et constance des motifs sont à corriger avant les
autres actions. La réparation du sandbox a rétabli ImageGen avec référence.

Le [dernier audit de marche](../design/achilles/passe_rive_walk_audit_2026-09-10.md)
mesure désormais le défaut sur les dessins et relève aussi deux erreurs dans
le guide. Il documente les références professionnelles et le prochain test :
brouillon animé validé en déplacement, puis preuve de transfert de l'habillage.

## Méthode retenue avant ce socle — dessin guidé par Blender

L'utilisateur valide le gain de cohérence du mannequin, mais rejette l'habillage
`sentinelle_armor_v1`, trop éloigné du sprite original. Il propose désormais
Blender comme référence des poses et des appuis, avec génération des dessins
complets depuis le sprite original. Le kit initial apprécié est celui d'Achille.

La [fiche de l'essai guidé](../../art/source/sprite_workshop/sentinelle_guided_v1/README.md)
contient quatre poses techniques de l'estoc E et le prompt. La génération a été
bloquée par une erreur d'accès aux images du bac à sable Codex, résolue depuis.
Cet ancien essai n'a pas reçu de validation artistique. Les sections suivantes
conservent l'historique ; l'armure 3D n'est pas la référence artistique à poursuivre.


## Retour utilisateur — cohérence du pilote

Le 10 septembre 2026, après consultation de la revue Blender :
> C'est vraiment beaucoup plus cohérent

Conserver `sentinelle_blocking_v1` et son estoc comme référence de mouvement pour
la suite. Ce retour confirme le gain de cohérence perçu. L'habillage peint,
les autres actions et leur intégration au combat restent à produire et à revoir.
Ne pas repartir des recettes V7 pour remplacer cette base de mouvement.


## Pilote Blender commencé — 10 septembre 2026

Blender et sa connexion MCP sont maintenant configurés. Le
[guide du pilote Blender](../../tools/blender_sentinelle/README.md) donne le fichier
éditable, le panneau de revue, les versions et les preuves. Un mannequin commun
aux quatre vues et un premier estoc sont construits. **Les poses attendent la
revue artistique** avant toute préparation des pièces peintes ou déclinaison du kit.


## Priorité après revue de la V7 — 10 septembre 2026

L'utilisateur juge encore les mouvements incohérents. Lire le
[diagnostic de méthode et le prochain pilote proposé](diagnostic_methode_2026-09-10.md)
avant une nouvelle production. L'audit distingue directions et dessins sources,
rig, mécanique corporelle et validations techniques. La V7 reste une expérience
à comparer, sans approbation artistique. Le prochain essai recommandé commence
par une référence spatiale et quelques poses complètes validées.


## Kit complet de la Sentinelle — essai courant

Le kit `sentinelle_kit_v7` contient 24 clips dans quatre directions.
[Guide, galerie et reprise](sentinelle_kit.md).
Commande : `./tools/spine_trial/kit.ps1 start`.
Les sections suivantes conservent l’historique de la préparation Spine.

Point d'entrée pour poursuivre la production d'animations 2D depuis une autre
tâche locale dans ce projet Godot. Mis à jour le **9 septembre 2026** ; base Git
initiale : `main`, `6d99bfff`. Pour l'état actuel, lire la reprise locale ci-dessous.
Relire `git status --short` avant d'intervenir et conserver les travaux en cours.

## État actuel : premier essai installé

Le [guide de l'essai installé](../../tools/spine_trial/README.md) est maintenant
le point d'entrée opérationnel : connecteur, runtime Godot, Sentinelle E/N
converties et contrôles. L'utilisateur reste sur Spine Trial pour ce premier
essai. Les sections suivantes conservent les décisions de la recherche initiale.

## Reprise locale vérifiée

La [fiche de reprise locale](reprise_locale_2026-09-09.md), basée sur `1b5cedb0`,
complète la recherche initiale : chemins Godot et Spine Trial, restauration des
outils, contrôles exécutés et anciens rapports absents de cette copie.

## Objectif et décisions

Produire des mouvements cohérents du corps entier et des orientations correctes,
avec des corrections reproductibles et peu de contexte à recharger. Le prochain
essai proposé utilise **Spine directement comme outil d'animation**.

- Spine + son extension Godot officielle constituent une piste documentée,
  mais aucune animation de notre projet n'a encore été validée avec Spine.
- Premier connecteur à évaluer : **nihatcagri44/spine-motion-mcp**, pour inspecter
  un rig, modifier ses clés et regarder un aperçu animé. Ses imports/exports
  Windows, sa connexion à Codex et ses limites sont à vérifier.
- **Attrom/spine-mpc-attrom** est une piste complémentaire pour documenter les
  squelettes et indexer des exemples. Ne pas installer plusieurs connecteurs
  avant d'avoir éprouvé le premier.
- Les versions éditeur, données et runtime doivent correspondre. Les candidats
  examinés ciblent notamment Spine 4.2 ; ne pas supposer une compatibilité avec
  une autre version. Godot de référence : **4.7.1**.
- Sortie possible : JSON/binaire + atlas vers la GDExtension officielle, ou
  séquence PNG vers notre atelier existant pour une première comparaison.
- Installation et licence Spine sont à constater sur la machine. L'essai gratuit
  ne sauvegarde/exporte pas notre travail ; les maillages et l'IK demandent Pro.

## Documents à lire selon le besoin

| Document | Contenu |
| --- | --- |
| [Évaluation Spine et connecteurs](../tools/spine_assessment_2026-09-09.md) | Recherche principale, liens officiels, candidats MCP, fonctions réellement examinées, limites et protocole proposé. |
| [Références de mouvement](../tools/sprite_motion_references_2026-09-09.md) | Références par morphologie/action/caméra, convention des directions, poses complètes et futur panneau de référence animée. |
| [Bilan du pilote Sentinelle](../tools/sentinelle_attack_pilot_2026-09-09.md) | Résultats techniques, rejet artistique, rapports et problèmes non résolus. |
| [Atelier Godot existant](../../tools/sprite_workshop/README.md) | Ouverture, documents, comparaison de clips et exports. |
| [Implémentation de l'atelier](../tools/sprite_workshop_implementation_2026-09-09.md) | Fichiers et vérifications de l'outillage déjà réalisé. |

La recherche détaillée reste dans `docs/tools/` pour préserver les liens
existants ; ce dossier centralise sa reprise sans dupliquer les documents.

## État artistique et technique à préserver

Les variantes A/B/B2 de l'estoc de Sentinelle ont été **rejetées par l'utilisateur** :
le bras bouge sans coordination convaincante du buste, de la tête et du corps ;
les directions sont incorrectes. Ne pas les traiter comme une base artistique
validée. La ruée d'Achille appréciée par l'utilisateur reste la référence interne.

Le pipeline de monstres dispose déjà d'articulations et d'IK : l'ajout d'un
squelette ne prouve pas un gain de qualité. Les références doivent correspondre
à la morphologie, à l'arme et à la caméra ; les directions opposées ne sont pas
à fabriquer par miroir. Commencer par des poses du corps entier avant les détails.

Le pilote précédent compte 231 contrôles fonctionnels réussis, mais son verdict
strict est en échec à cause d'objets/ressources retenus à la fermeture de Godot.
Ce problème n'est pas corrigé et ne constitue pas une validation globale.
Les preuves et chemins des rapports sont dans son bilan, lié ci-dessus.

Les sources du pilote sont dans
`art/source/sprite_workshop/sentinelle_attack_pilot_2026-09-09/` ; son
[comparatif local](../../artifacts/sprite_workshop/sentinelle_attack_pilot_2026-09-09/comparaison.html)
permet de revoir les essais. Aucun connecteur MCP Spine ni runtime Spine-Godot
n'a été installé ou testé dans le cadre de ce dossier.

## Prochain travail concret

1. Vérifier l'état local, l'installation/licence Spine et les versions disponibles.
2. Examiner le connecteur choisi, puis éprouver connexion, lecture et aperçu
   sur une copie d'un exemple officiel ; consigner les commandes et résultats.
3. Modifier une pose, réimporter dans Spine et comparer l'export. Vérifier
   images, clés, courbes et données d'édition ; préserver le `.spine` source.
4. Vérifier ce même exemple dans Godot 4.7.1 si la sortie native est retenue.
5. Faire ensuite le pilote artistique : Sentinelle, un estoc, une vue frontale
   puis une vue arrière. Évaluer appuis, bassin, torse, tête, lance, bouclier et
   direction à taille de jeu. Rapporter séparément qualité visuelle et tests.

L'intégration complète et les gains de temps/tokens restent à mesurer. Un
rapport d'import réussi ne suffit pas à qualifier le mouvement de production.

## Message pour reprendre dans une autre tâche

> Lis `docs/spine/README.md` et reprends le dossier Spine. Consulte ensuite les
> documents liés selon le besoin. Commence par vérifier notre environnement et
> la faisabilité du connecteur retenu, puis prépare un essai reproductible sur
> un exemple officiel avant la Sentinelle. Préserve les modifications locales
> et la ruée d'Achille ; distingue les vérifications exécutées de celles à faire.
