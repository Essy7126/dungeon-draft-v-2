# Spine — dossier de reprise local

## Kit complet de la Sentinelle — essai courant

Le kit `sentinelle_kit_v5` contient 24 clips dans quatre directions.
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
