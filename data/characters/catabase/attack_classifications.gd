extends CombatActionClassificationCatalogData

const MAGE := preload("res://data/characters/philosopher_mage/attack_classifications.tres")
const PARIS := preload("res://data/characters/paris/attack_classifications.tres")


func _init() -> void:
	catalog_id = &"catabase_enemy_action_classifications_v1"
	# Keep the exact authored entries of each enemy. Battle adds the hero's
	# classifications separately; neither standalone enemy catalog is rewritten.
	entries.assign(MAGE.entries)
	entries.append_array(PARIS.entries)
