# traits/trait_chassis_healer.gd

class_name TraitChassisHealer
extends Trait

var nature_on_generator: float = 10.0
var nature_bonus_heal: float = 5.0
var nature_bonus_terrain: float = 4.0

func _trait_name() -> String:
	return "chassis_healer"

func configure(params: Dictionary) -> void:
	nature_on_generator = params.get("nature_on_generator", nature_on_generator)
	nature_bonus_heal = params.get("nature_bonus_heal", nature_bonus_heal)
	nature_bonus_terrain = params.get("nature_bonus_terrain", nature_bonus_terrain)

func _activate() -> void:
	EventBus.spell_cast.connect(_on_spell_cast)

func _deactivate() -> void:
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)

func _on_spell_cast(caster, spell: Spell, report: Dictionary) -> void:
	if caster != owner or not owner.is_alive or not owner.has_energy():
		return
	if owner.energy_type.energy_id != "nature":
		return
	if not spell.is_generator():
		return

	var amount := nature_on_generator
	if spell.is_healing() and not report.get("affected_units", []).is_empty():
		amount += nature_bonus_heal
	if not report.get("terrain_changed", []).is_empty():
		amount += nature_bonus_terrain

	owner.generate_energy(amount, source_id)
	DebugLogger.debug(DebugLogger.LogCategory.STATS,
		"%s genere %.0f Nature (chassis Healer)" % [owner.unit_name, amount])
