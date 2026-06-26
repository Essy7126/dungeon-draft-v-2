class_name RelicData
extends Resource

enum Rarity { COMMON, RARE, MYTHIC }

@export var relic_name: String = "Relique"
@export_multiline var description: String = ""
@export var hook: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var tradeoff: String = ""
@export var trait_data: TraitData = null