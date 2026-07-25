# Rang 2 des disciplines de l’Elfe

## Seuil commun

Archer, Assassin, Mage et Soigneur commencent au rang 1 et atteignent le rang
2 à `3 XP` totaux dans leur discipline. Chaque rang 2 contient exactement deux
`SkillUpgradeData` exclusives. La logique de seuil reste exclusivement dans
`DisciplineProgressState`; les ressources de discipline ne font que déclarer
leurs rangs, seuils et choix.

Un cast réussi donne toujours un seul point à la discipline identifiée par
`Spell.discipline_id`. Les choix restent différés jusqu’au flux post-combat et
la sélection est conservée dans le `CharacterRunState` de l’instance exacte du
personnage.

## Les six nouveaux choix

### Archer — Tir précis

- `elf_archer_eagle_eye` — **Œil d’aigle** : ajoute `3` aux dégâts bruts de la
  cible lorsque la distance entre le lanceur et la cellule ciblée est supérieure
  ou égale à `4`. La condition appelle `GridData.manhattan`, soit exactement la
  métrique utilisée par la portée de `SpellCaster`.
- `elf_archer_repel_arrow` — **Flèche de recul** : demande une poussée
  post-impact d’exactement `1` case, sans multiplication par la Force. La
  résolution réutilise `_push_unit` : bord, mur ou case occupée bloquent le
  déplacement, signalent la collision selon la règle existante et n’annulent
  jamais le cast.

### Assassin — Frappe sournoise

- `elf_assassin_backstab` — **Dans le dos** : ajoute `4` aux dégâts lorsque la
  position logique du lanceur est exactement
  `cible.grid_pos - cible.facing_dir`. `Unit.get_behind_grid_cell()` réduit
  d’abord le regard à une direction cardinale. Le calcul ne lit aucune
  orientation visuelle ou projection isométrique; face et côtés ne reçoivent
  aucun bonus.
- `elf_assassin_venomous_blade` — **Lame venimeuse** : applique le statut
  `Poison de Lame venimeuse`, qui inflige `2` dégâts vrais au début de chacun
  des deux prochains tours de la cible. La durée runtime vit dans
  `Unit.active_statuses`, jamais dans la Resource. Une réapplication retrouve
  le même `status_name` et rafraîchit la durée à `2` tours sans créer de cumul,
  conformément à la règle générique de `Unit.apply_status()`.

### Soigneur — Soin sylvestre

- `elf_healer_abundant_sap` — **Sève abondante** : ajoute `3` au montant de
  soin du cast. `Unit.heal()` conserve le plafond de PV; l’Elfe n’ayant pas
  d’énergie ni de conversion d’overheal, l’excédent ne crée aucun bouclier. Le
  montant réellement rendu est émis par `EventBus.unit_healed` et inscrit dans
  `report.healing_by_unit`.
- `elf_healer_protective_bark` — **Écorce protectrice** : ajoute une demande de
  bouclier de `3` à la cible alliée, résolue après le soin dans l’impact normal.
  `Unit.add_shield()` applique la règle historique de remplacement : le nouveau
  bouclier remplace seulement une valeur inférieure; il ne s’additionne pas et
  une valeur supérieure est conservée. Le choix fonctionne sur soi ou un allié.

## Architecture des modificateurs

La chaîne reste :

`SkillUpgradeData` → `CharacterRunState` → `Unit.progression_modifiers` →
`SpellCaster`.

Chaque Resource de modifier filtre par `target_spell_id` avant son hook.
`CastContext` porte uniquement des données éphémères du cast :

- bonus de dégâts par cellule;
- bonus de soin par unité;
- statuts supplémentaires par unité;
- boucliers supplémentaires par unité;
- poussées supplémentaires exactes par unité.

`SpellCaster` résout ces demandes par les chemins génériques existants. Il ne
connaît aucun identifiant d’évolution, aucun nom affiché et aucune ressource
propre à l’Elfe. Ni les `Spell`, ni les statuts, ni les modifiers partagés ne
sont mutés. Une resynchronisation remplace et déduplique toujours la collection
de la `Unit`.

## File de choix multiple

La file est reconstruite de façon déterministe :

1. ordre des héros dans `GameManager.heroes`;
2. ordre des disciplines dans `UnitData.disciplines`;
3. rang croissant dans chaque progression.

Pour l’Elfe, l’ordre est donc Archer, Assassin, Mage, Soigneur.
`ProgressionChoiceScreen` garde une seule instance, remplace complètement ses
données après chaque confirmation, retire uniquement le choix accepté et ouvre
immédiatement le suivant. Après le quatrième, le flux historique reprend vers
la récompense éventuelle ou la salle suivante. Les gardes d’instance et de
confirmation empêchent respectivement un second écran et une double sélection.

## Persistance, nettoyage et compatibilité

XP, rangs, attentes et sélections persistent entre les salles dans
`CharacterRunState`. Les modifiers sélectionnés restent sur la même `Unit`
pendant la run. `cleanup_run_state()` et `dispose()` retirent la file, l’écran
et tous les modifiers avant une nouvelle run ou un retour au titre.

Les deux choix Mage (`Cœur incandescent` et `Braises persistantes`) utilisent
le même pipeline et restent inchangés. Le prototype Elfe conserve ses quatre
sorts. Les héros historiques sans disciplines, les huit sorts du Guerrier, la
Boule de feu historique, le draft, `RewardScreen`, les énergies, traits,
rewards et anciens `SpellModifier` suivent toujours leurs chemins existants.

## Limites volontaires et prochaine étape

Ce lot n’ajoute aucun rang 3+, sort, grimoire, remplacement interactif,
équipement, personnage définitif, énergie, sauvegarde disque ou direction
artistique finale.

La prochaine étape peut concevoir les rangs supérieurs et l’interface de
progression complète, en conservant la séparation entre données statiques,
état vivant de run et demandes éphémères de cast.
