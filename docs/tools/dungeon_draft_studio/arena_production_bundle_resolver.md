# Arena Production Bundle Resolver

Statut : **WORKTREE_CANDIDATE**

## Objectif

Arena Studio conserve la protection contre l'écrasement d'un dossier dont la
propriété n'est pas prouvée, mais ne laisse plus l'utilisateur devant un simple
message de conflit. Le plan de production contient désormais un rapport
`bundle_resolution` lisible et actionnable.

Le résolveur ne modifie jamais automatiquement un bundle. L'inspection, la
recommandation et le choix d'un chemin versionné sont en lecture seule. Toute
écriture, archive ou sortie de `res://` exige une action explicite confirmée.

## Services

- `ArenaBundleInspectionService` classe les fichiers, le manifeste et les
  hashes ;
- `ArenaBundleReferenceService` agrège les usages du
  `StudioReferenceGraphService`, les RunData avec index de salle et les
  transactions de production actives ;
- `ArenaBundleOwnershipService` archive par copie, vérifie les SHA-256, écrit
  un reçu, puis seulement retire la source ;
- `ArenaBundleVersioningService` choisit un chemin `_v2`, `_v3`, etc. sans
  renommer l'identifiant de l'arène ;
- `ArenaBundleResolutionService` recommande et exécute les actions explicites ;
- `ArenaProductionTransactionService` reste l'unique publication atomique du
  nouveau bundle ;
- `ArenaIntegrationService` reste l'unique orchestration production → run.

## Actions proposées

### Reprendre une production interrompue

Disponible uniquement si toutes les preuves suivantes sont réunies :

- bundle structurel incomplet sans manifeste reconnu ;
- aucune Resource, run ou transaction active ne le référence ;
- aucun fichier inattendu ;
- `arena_id` identique à la working copy ;
- fingerprints identiques ;
- rechargement, validation et assemblage visuel valides.

Après confirmation, le Studio sauvegarde `arena.tres` sous `user://`, normalise
ses références internes, écrit le manifeste, recharge le bundle et vérifie la
transaction. En cas d'échec, l'octet original est restauré et le manifeste
nouveau est retiré.

### Archiver puis reconstruire

Disponible seulement sans référence canonique ni transaction active. Le bundle
est copié sous :

```text
user://dungeon_draft_studio/abandoned_productions/
```

Les fichiers archivés sont comparés par SHA-256 avant le retrait du dossier de
destination. Le reçu conserve l'état source, la justification et le rapport de
références. Le plan est ensuite recalculé ; la production atomique normale peut
reconstruire la destination devenue vide.

### Créer une nouvelle version à côté

Cette action ne déplace rien. Elle sélectionne automatiquement le premier
chemin libre (`_v2`, `_v3`, …), l'affiche dans le Studio et conserve
`arena_id`. C'est l'action recommandée lorsqu'une run, une autre Resource ou
une transaction active rend le déplacement dangereux.

### Retirer les anciens fichiers du projet

Le retrait est une archive récupérable, jamais une suppression silencieuse. Il
utilise les mêmes contrôles de références et de SHA-256 que l'archivage.

### Examiner ou annuler

`Examiner les fichiers` ouvre le dossier sans mutation. `Annuler` ne modifie ni
le chemin, ni le manifeste, ni les fichiers.

## États expliqués

Le panneau distingue notamment : destination vide, production Studio complète,
production interrompue, bundle référencé, hashes divergents, manifeste
corrompu, `generated_by` inconnu, contenu étranger et bundle legacy. Il affiche
la liste des fichiers, tailles, SHA-256, usages, run, index de salle et
transactions actives.

## Sécurité du bundle forêt

Les tests automatiques utilisent exclusivement des fixtures sous `user://`.
`res://data/arenas/produced/room_01_forest/` est uniquement inspecté par les
tests UI. Aucune action de reprise, archive ou retrait n'est déclenchée sans un
clic utilisateur confirmé dans Arena Studio.
