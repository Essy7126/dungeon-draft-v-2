# Politique du gate d'intégration Arena

Statut : **WORKTREE_CANDIDATE**

## Principe

`ArenaIntegrationGatePolicy` est l'unique autorité qui décide si une arène
peut être intégrée. La couleur ou la sévérité visuelle d'un diagnostic ne
détermine plus implicitement le blocage.

Le rapport contient séparément :

- `blocking_errors` : risques techniques empêchant une transaction sûre ;
- `acknowledgement_warnings` : choix de design visibles et confirmables ;
- `information` : métriques et résultats ne demandant aucune action ;
- `automatic_actions` : contrôles exécutés automatiquement ;
- `ready_to_integrate` : vrai si et seulement si `blocking_errors` est vide.

## Contrôles automatiques

Le bouton **Vérifier et intégrer** exécute sans navigation obligatoire :

1. la validation pure ;
2. la parité topologique ;
3. la parité du rendu ;
4. un smoke runtime automatique ;
5. le plan de destination ;
6. la conservation du gameplay lors d'un UPDATE ;
7. le prévol de sauvegarde, rechargement et rollback.

Le smoke crée une copie isolée sous
`user://dungeon_draft_studio/integration_gate/automatic_smoke/`, la recharge
avec `CACHE_MODE_IGNORE_DEEP`, construit `GridData`, `Pathfinder` et
`ArenaVisualAssembler`, puis compare les ensembles exacts de dalles.

Le test manuel reste recommandé mais n'est plus bloquant.

## Erreurs bloquantes

Les familles suivantes bloquent toujours :

- divergence de topology hash ou d'ensembles de cellules ;
- case retirée encore rendue ;
- dalle manquante, inattendue ou dupliquée ;
- spawn ou objectif obligatoire invalide ;
- échec de `GridData`, `Pathfinder`, sauvegarde ou rechargement ;
- asset runtime obligatoire absent ;
- conflit de destination ou changement externe de la source ;
- dérive gameplay lors d'un UPDATE ;
- violation d'isolation de run ;
- schéma/champ runtime sans politique ;
- transaction sans rollback vérifiable.

Chaque blocage est affiché immédiatement sous :

```text
Pourquoi l'intégration est-elle indisponible ?
```

## Avertissements et acceptation

Les corridors étroits, articulations, bordure absente, cellule isolée sans
élément obligatoire, alignement artistique non confirmé et test manuel absent
ne désactivent pas le bouton.

Avant l'écriture, le Studio demande une justification. L'acceptation stocke :

- la clé du warning ;
- la cellule ou le sujet ;
- le fingerprint exact de l'arène ;
- la justification ;
- la date d'acceptation.

Une modification du fingerprint invalide automatiquement l'acceptation.
Cette donnée appartient à l'état d'éditeur, jamais aux règles de gameplay.

## Profils

- **Brouillon** : bloque uniquement les documents techniquement impossibles ;
- **Run de test** : ajoute parité runtime et destination ;
- **Production** : mêmes garanties, warnings confirmables ;
- **Release stricte** : profil volontaire pouvant promouvoir explicitement
  certains codes de warning.

Aucun warning n'est promu universellement par défaut.

## Agrégation des informations

Les overrides de terrain justifiés sont agrégés en une seule information :

```text
7 overrides de terrain vérifiés et cohérents.
```

L'absence de foreground reste une information. Les documents modifiés dans un
autre domaine du Studio sont signalés mais ne bloquent pas une transaction
Arena isolée.
