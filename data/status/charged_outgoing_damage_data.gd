class_name ChargedOutgoingDamageData
extends StatusData

# -1 : toute catégorie de dégâts ; sinon Spell.DamageType.
@export_range(-1, 1) var trigger_damage_type: int = -1
@export_range(1, 99) var max_charges: int = 1
@export var bonus_damage: int = 0
