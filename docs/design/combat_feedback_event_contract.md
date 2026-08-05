# Contrat événementiel du feedback de combat

## Principe

L'UI reçoit uniquement des `CombatEventFact` créés après l'application du résultat. Elle ne relit aucune statistique, ne refait aucune mitigation, ne déduit pas le bouclier et ne calcule ni soin effectif ni critique.

`CombatEventFact` est immuable par convention. Les références runtime `source` et `target` servent uniquement pendant la scène ; `to_metadata()` n'exporte que des identifiants stables et jamais des `Node`.

## Champs

Les faits partagent : `event_id`, `event_type`, `action_id`, `cast_id`, `impact_id`, `sequence_index`, `source`, `target`, `ability_id`, `status_id`, `amount_resolved`, `amount_applied`, `amount_absorbed`, `overheal`, `is_critical`, `damage_type`, `element`, `is_periodic`, `logical_order` et `anchor_offset`. `amount_resolved` est le coup post-défenses avant bouclier/plafond de PV, réservé au rapport overkill-aware ; le feedback de PV utilise toujours `amount_applied`.

Un `impact_id` explicite constitue la clé d'idempotence métier dans `Unit` pour les dégâts, soins et boucliers. Sans identifiant, les appels historiques conservent leur comportement répétable — nécessaire notamment pour des ticks logiques successifs.

## Faits V2

| Signal | `event_type` | Sémantique |
|---|---|---|
| `hit_resolved` | `hit_resolved` | Résumé final du coup après bouclier et PV |
| `shield_absorption_resolved` | `shield_absorbed` | Delta réellement retiré au bouclier |
| `hp_damage_taken` | `hp_damage_taken` | Perte réelle de PV |
| `heal_received` | `heal_received` | Soin effectif ; `overheal` séparé |
| `shield_granted` | `shield_granted` | Delta de bouclier réellement gagné |
| `attack_dodge_resolved` | `attack_dodged` | Attaque esquivée, aucun montant à afficher |
| `attack_immune` | `attack_immune` | Contrat préparé pour une immunité métier future |
| `status_tick` | fait de dégâts périodique | Vue typée du même fait de perte de PV, pas un second dégât |
| `status_added` | `status_added` | Statut réellement ajouté |
| `combat_status_refreshed` | `status_refreshed` | Durée/charge réellement rafraîchie |
| `combat_status_expired` | `status_expired` | Statut réellement expiré |

Le contrôleur visuel écoute `hp_damage_taken` pour un DoT et n'écoute pas `status_tick` en plus : il n'affiche donc jamais deux fois le même tick.

## Ordre garanti

Pour un coup touché : calcul → mutation du bouclier → `shield_absorption_resolved` → mutation de `current_hp` → `hp_damage_taken` → signal legacy `health_damage_taken` → éventuel `status_tick` → `hit_resolved` → compatibilité `damage_dealt`/`critical_hit` → mort éventuelle.

Lors du callback `hp_damage_taken`, `current_hp` contient déjà sa valeur finale. Les observateurs de statistiques et de vue consomment la perte réelle de PV.

Exemple contractuel : coup mitigé 50, bouclier 20, PV 100. Les faits portent `shield_absorbed.amount_absorbed = 20` et `hp_damage_taken.amount_applied = 30`. Le résumé porte 30/20. L'UI affiche bouclier 20 puis `−30`, jamais `−50` comme perte de PV.

Pour un soin : cible 88/100, soin demandé 30. La mutation donne 100/100, puis le fait porte `amount_applied = 12`, `overheal = 18`. L'UI normale affiche `+12`.

## Multi-impact et AOE

`SpellCaster` crée un `action_id`/`cast_id` par cast et un `impact_id` par cible résolue. `sequence_index` est monotone dans l'ordre de résolution. Un multi-impact possède donc des faits distincts et ordonnés. Une AOE produit un fait par cible ; aucune valeur globale n'est inventée au centre de la zone.

## Compatibilité

Les signaux historiques restent disponibles : `damage_dealt`, `health_damage_taken`, `shield_absorbed`, `unit_healed`, `shield_gained`, `attack_dodged`, etc. `damage_dealt` est explicitement déprécié et conserve son ancien montant post-mitigation/pré-bouclier pour éviter une régression silencieuse.

Les abonnés actifs précédents ont été migrés :

- `CombatReportTracker` écoute `health_damage_taken` pour les dégâts réellement subis et `hit_resolved.amount_resolved` pour sa statistique historique de dégâts infligés, qui inclut bouclier et overkill sans dépendre de `damage_dealt`.
- `UnitView` écoute `health_damage_taken` pour le flash de PV ; l'absorption complète conserve son flash via le signal de bouclier.
- `CharacterIsoUnitView` écoute `hit_resolved` pour la réaction d'impact du personnage 3D projeté.
- `CombatFeedbackController` écoute exclusivement les faits V2 appropriés.

## Limite d'immunité

Le dépôt n'expose actuellement aucune règle de combat produisant une immunité. Le signal, le style et la galerie sont prêts, mais aucun chemin métier artificiel n'a été ajouté. Lorsqu'une vraie immunité sera introduite, le moteur devra muter zéro ressource puis émettre exactement un `attack_immune` avec l'identifiant d'impact.
