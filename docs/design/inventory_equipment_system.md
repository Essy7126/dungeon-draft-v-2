# Système d’inventaire et d’équipement — implémentation V1

## Périmètre livré

Cette première version fournit un inventaire partagé de run, un équipement propre à chaque héros, l’application des statistiques, les consommables, une sauvegarde JSON dédiée et un écran utilisable depuis le HUD ou le menu de pause.

La représentation des armes et armures sur les modèles 3D est volontairement hors périmètre. Aucune scène de personnage, aucun squelette, aucun socket et aucune animation d’attaque n’est modifié par cette implémentation.

## Architecture

| Couche | Fichiers principaux | Responsabilité |
|---|---|---|
| Définitions | `data/items/item_definition.gd`, `data/items/item_stat_modifier_data.gd` | Données immuables d’un type d’objet |
| Catalogue | `data/items/item_catalog.gd`, `data/items/catalogs/first_run_item_catalog.tres` | Index et validation des identifiants stables |
| Runtime | `items/item_instance.gd`, `items/run_inventory.gd`, `items/equipment_loadout.gd` | Instances uniques, piles, 24 cases et trois emplacements par héros |
| Services | `items/equipment_service.gd`, `items/equipment_stat_service.gd`, `items/item_use_service.gd` | Transactions, modificateurs de statistiques et effets consommables |
| État de run | `core/game_manager.gd`, `characters/progression/character_run_state.gd` | Propriété, API publique, signaux et snapshots |
| Interface | `ui/inventory/InventoryScreen.tscn`, `ui/inventory/inventory_screen.gd` | Sac partagé, sélection du héros, équipement et utilisation |

Les définitions `.tres` ne contiennent pas d’état mutable. Chaque objet possédé est un `ItemInstance` identifié indépendamment. Un objet équipé quitte le sac et appartient au `EquipmentLoadout` du héros, ce qui évite une double propriété.

## Contenu de démonstration

Le catalogue initial contient cinq objets :

- épée d’entraînement du guerrier : arme réservée au guerrier, `+3` attaque ;
- veste renforcée : armure universelle, `+5` armure ;
- charme runique : accessoire universel, `+10` PV maximum ;
- potion de soin mineure : pile de cinq, rend `25` PV ;
- parchemin d’élan mineur : pile de trois, rend `1` PA.

Une nouvelle run commence avec ces cinq types d’objet. Une potion supplémentaire est attribuée après une victoire de salle si le sac peut l’accepter. Un sac plein refuse l’ajout sans modifier partiellement son contenu.

## Intégration UI

L’icône d’inventaire du HUD ouvre l’écran sur le héros actuellement actif. L’action « Équipement » du menu de pause ouvre exactement le même écran. L’interface présente :

- les 24 cases du sac partagé ;
- un sélecteur pour les héros du run ;
- les emplacements Arme, Armure et Accessoire ;
- la description, la rareté, les bonus et les statistiques courantes ;
- les actions Équiper, Utiliser et Déséquiper avec retour d’erreur.

L’écran est exclusif avec la pause, l’arbre de compétences, l’évolution et les transitions. En combat, son ouverture désactive temporairement les contrôles et sa fermeture restaure leur état précédent.

## Contrats de statistiques

Les bonus utilisent le système `Stat` existant. La source d’un modificateur suit le format `equipment:<instance_id>:<stat_id>`, ce qui permet de retirer précisément un équipement sans toucher aux bonus de progression ou de statut.

Les statistiques prises en charge sont `max_hp`, `initiative`, `max_ap`, `max_mp`, `attack_power`, `armure`, `resist_magique`, `esquive`, `crit_chance`, `crit_multi` et `force`. Les valeurs runtime de PV, PA et PM sont bornées après chaque changement de maximum.

## API de run

`GameManager` expose les opérations suivantes :

- `grant_item_to_inventory(definition_id, quantity)` ;
- `equip_inventory_item(instance_id, character_id, slot)` ;
- `unequip_inventory_item(character_id, slot)` ;
- `use_inventory_item(instance_id, character_id)` ;
- `get_inventory_equipment_snapshot()` ;
- `restore_inventory_equipment_snapshot(snapshot)` ;
- `save_inventory_equipment_state(file_path)` ;
- `load_inventory_equipment_state(file_path)`.

Les snapshots sont versionnés et contrôlent la capacité, les définitions, les quantités, la compatibilité des héros et l’unicité globale des instances entre le sac et les équipements.

La sauvegarde fournie couvre uniquement l’inventaire et les équipements d’une run déjà active. Elle ne constitue pas encore une reprise complète de run : salles, progression, rapport de combat et scène courante restent à intégrer dans un futur format de sauvegarde global.

## Ajouter un objet

1. Créer une ressource `ItemDefinition` dans `data/items/definitions/` avec un `item_id` stable et unique.
2. Configurer sa catégorie, sa limite de pile et, pour un équipement, son emplacement et ses modificateurs.
3. Ajouter la ressource à `first_run_item_catalog.tres` ou à un futur catalogue de run.
4. Étendre `ItemUseService` si l’objet introduit un nouveau type d’effet actif.
5. Ajouter des tests de catalogue, de transaction, d’effet et de snapshot.

## Extension visuelle différée

La future couche visuelle devra observer les changements de `EquipmentLoadout` sans devenir propriétaire du gameplay. Un `EquipmentVisualController` pourra résoudre une variante visuelle par `item_id`, attacher une scène d’arme aux sockets audités et synchroniser le changement avec les événements d’attaque. L’absence de visuel devra rester un cas valide afin que tout objet logique fonctionne même sans asset 3D.

## Validation

La couverture dédiée se trouve dans `test/unit/test_inventory_equipment_system.gd`. Elle vérifie le catalogue, les piles atomiques, les snapshots, les transactions d’équipement, le sac plein, les potions, les parchemins, la sauvegarde JSON et les deux points d’entrée UI.

Les tests du menu de pause ont également été adaptés pour rendre l’action Équipement active. Les échecs historiques non liés — textures de thème nulles et UID invalide du sort du guerrier — ne sont pas corrigés dans ce chantier.
