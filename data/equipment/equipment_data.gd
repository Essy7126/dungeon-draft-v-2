class_name EquipmentData
extends Resource

enum Slot { WEAPON, ARMOR, TALISMAN }
enum Rarity { COMMON, RARE, EPIC }

@export var equipment_name: String = "Equipement"
@export_multiline var description: String = ""
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D = null
@export var affixes: Array[String] = []
@export var traits: Array[TraitData] = []
@export var granted_spell: Spell = null
@export_multiline var tradeoff: String = ""