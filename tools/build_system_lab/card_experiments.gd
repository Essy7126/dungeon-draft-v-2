extends RefCounted
## Isolated design specimens, NOT a public class system or a second combat engine.
## Each call returns fresh Spell resources; the common SpellCaster executes them.

const IDS := ["opening", "finish", "guard", "repel", "shot", "step", "frost", "blast"]
const CLASSES := {
	"opening": "assassin",
	"finish": "assassin",
	"guard": "gardien",
	"repel": "gardien",
	"shot": "arpenteur",
	"step": "arpenteur",
	"frost": "thaumaturge",
	"blast": "thaumaturge",
}


static func make_card(id: String, mastery: int, prowess: float) -> Spell:
	if id not in IDS or mastery < 0 or mastery > 4 or not is_finite(prowess) or prowess < 0:
		return null
	var spell := Spell.new()
	spell.spell_id = StringName("lab_" + id)
	spell.spell_name = id
	spell.damage_type = Spell.DamageType.PHYSICAL
	spell.ap_cost = 2
	spell.minimum_range = 1
	spell.spell_range = 1
	# Iteration 2: ordinary attacks may use two owned copies in one hand.
	# Limit the controls/defense by ability ID, not every card indiscriminately.
	spell.once_per_activation = id in ["guard", "repel", "step", "frost"]
	var multiplier := 1.0 + 0.1 * mastery
	match id:
		"opening":
			spell.spell_name = "Ouvrir la garde"
			spell.ap_cost = 1
			spell.spell_range = 3
			spell.damage_scaling = _scaling(0.35 * multiplier)
			var status := StatusData.new()
			status.status_id = &"lab_opening"
			status.status_name = "Ouverture"
			status.duration = 1
			spell.applied_status = status
		"finish":
			spell.spell_name = "Frapper l'ouverture"
			spell.damage_scaling = _scaling(0.8 * multiplier)
			spell.bonus_damage_status_id = &"lab_opening"
			# Frozen in this laboratory specimen at construction; rebuild after stats change.
			spell.bonus_damage_if_marked = roundi(0.55 * prowess * multiplier)
		"guard":
			spell.spell_name = "Garde brève"
			_self_target(spell)
			spell.shield_scaling = _scaling(0.65 * multiplier, 0.04 * multiplier)
			spell.shield_duration_activations = 1
			spell.shield_tags = [&"guard"]
		"repel":
			spell.spell_name = "Repousser"
			spell.damage_scaling = _scaling(0.75 * multiplier)
			spell.push_distance = 1
		"shot":
			spell.spell_name = "Trait tendu"
			spell.minimum_range = 2
			spell.spell_range = 4
			spell.damage_scaling = _scaling(1.0 * multiplier)
		"step":
			spell.spell_name = "Pas latéral"
			spell.ap_cost = 1
			spell.spell_range = 2
			spell.can_target_enemy = false
			spell.can_target_free_cell = true
			spell.caster_movement = Spell.CasterMovement.TARGET_CELL
			spell.movement_requires_clear_path = true
		"frost":
			spell.spell_name = "Trait de givre"
			spell.spell_range = 3
			spell.damage_type = Spell.DamageType.MAGICAL
			spell.element = Spell.Element.ICE
			spell.damage_scaling = _scaling(0.7 * multiplier)
			var status := StatusData.new()
			status.status_id = &"lab_frost"
			status.status_name = "Givre"
			status.mp_reduction = 1
			status.duration = 1
			spell.applied_status = status
		"blast":
			spell.spell_name = "Éclat de braise"
			spell.ap_cost = 3
			spell.spell_range = 3
			spell.damage_type = Spell.DamageType.MAGICAL
			spell.element = Spell.Element.FIRE
			spell.can_target_free_cell = true
			spell.aoe_shape = Spell.AoeShape.CROSS
			spell.aoe_size = 1
			spell.exclude_allies_from_area_effects = true
			spell.damage_scaling = _scaling(0.8 * multiplier)
	return spell


static func _scaling(prowess: float, hp := 0.0) -> SpellScalingData:
	var scaling := SpellScalingData.new()
	scaling.prowess_coefficient = prowess
	scaling.max_hp_coefficient = hp
	return scaling


static func _self_target(spell: Spell) -> void:
	spell.minimum_range = 0
	spell.spell_range = 0
	spell.can_target_enemy = false
	spell.can_target_self = true
