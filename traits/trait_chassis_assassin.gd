# traits/trait_chassis_assassin.gd
# ============================================================
# CHÂSSIS ASSASSIN — La grammaire de base de l'Assassin.
#
# L'Assassin génère de l'énergie par l'EXPLOITATION des failles :
# attaquer une cible Marquée ou depuis un angle avantageux.
#
#   Rage : marquer → tuer → rembourser → enchaîner
#   Foi  : marquer → allié frappe → bouclier → stabiliser
#
# Paramètres (.tres optionnel) :
#   rage_on_hit           : float = 8.0   — Rage de base à chaque frappe
#   rage_bonus_marked     : float = 10.0  — bonus si cible Marquée
#   rage_bonus_angle      : float = 8.0   — bonus si angle avantageux
#   foi_on_hit            : float = 8.0   — Foi de base à chaque frappe
#   foi_bonus_marked      : float = 8.0   — bonus si cible Marquée
#   foi_bonus_angle       : float = 6.0   — bonus si angle avantageux
# ============================================================

class_name TraitChassisAssassin
extends Trait

var rage_on_hit: float       = 8.0
var rage_bonus_marked: float = 10.0
var rage_bonus_angle: float  = 8.0
var foi_on_hit: float        = 8.0
var foi_bonus_marked: float  = 8.0
var foi_bonus_angle: float   = 6.0

func _trait_name() -> String:
	return "chassis_assassin"

func configure(params: Dictionary) -> void:
	rage_on_hit       = params.get("rage_on_hit",       rage_on_hit)
	rage_bonus_marked = params.get("rage_bonus_marked", rage_bonus_marked)
	rage_bonus_angle  = params.get("rage_bonus_angle",  rage_bonus_angle)
	foi_on_hit        = params.get("foi_on_hit",        foi_on_hit)
	foi_bonus_marked  = params.get("foi_bonus_marked",  foi_bonus_marked)
	foi_bonus_angle   = params.get("foi_bonus_angle",   foi_bonus_angle)

func _activate() -> void:
	EventBus.spell_cast.connect(_on_spell_cast)

func _deactivate() -> void:
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)

# ============================================================
# GÉNÉRATION — sur tout sort générateur de l'Assassin
# Base : chaque sort générateur produit de l'énergie.
# Bonus : angle avantageux, cible Marquée.
# ============================================================

func _on_spell_cast(caster, spell: Spell, report: Dictionary) -> void:
	if caster != owner or not owner.is_alive or not owner.has_energy():
		return
	if not spell.is_generator():
		return

	var energy_id: String = owner.energy_type.energy_id
	var has_marked: bool = _any_marked(report.get("affected_units", []))
	var angle_ok: bool   = report.get("angle_advantage", false)

	# Génération de base sur tout sort générateur
	_generate_base()

	# Bonus conditionnels
	match energy_id:
		"rage":
			if has_marked:
				owner.generate_energy(rage_bonus_marked, source_id)
				DebugLogger.debug(DebugLogger.LogCategory.STATS,
					"%s génère %.0f Rage (cible Marquée)" \
					% [owner.unit_name, rage_bonus_marked])
			if angle_ok:
				owner.generate_energy(rage_bonus_angle, source_id)
				DebugLogger.debug(DebugLogger.LogCategory.STATS,
					"%s génère %.0f Rage (angle avantageux)" \
					% [owner.unit_name, rage_bonus_angle])
		"foi":
			if has_marked:
				owner.generate_energy(foi_bonus_marked, source_id)
				DebugLogger.debug(DebugLogger.LogCategory.STATS,
					"%s génère %.0f Foi (cible Marquée)" \
					% [owner.unit_name, foi_bonus_marked])
			if angle_ok:
				owner.generate_energy(foi_bonus_angle, source_id)
				DebugLogger.debug(DebugLogger.LogCategory.STATS,
					"%s génère %.0f Foi (angle avantageux)" \
					% [owner.unit_name, foi_bonus_angle])

# ============================================================
# HELPERS
# ============================================================

func _generate_base() -> void:
	var energy_id: String = owner.energy_type.energy_id
	match energy_id:
		"rage":
			owner.generate_energy(rage_on_hit, source_id)
			DebugLogger.debug(DebugLogger.LogCategory.STATS,
				"%s génère %.0f Rage (châssis Assassin)" % [owner.unit_name, rage_on_hit])
		"foi":
			owner.generate_energy(foi_on_hit, source_id)
			DebugLogger.debug(DebugLogger.LogCategory.STATS,
				"%s génère %.0f Foi (châssis Assassin)" % [owner.unit_name, foi_on_hit])

func _any_marked(targets: Array) -> bool:
	for target in targets:
		if _has_status(target, "Marqué"):
			return true
	return false

func _has_status(unit, status_name: String) -> bool:
	if not unit.has_method("get_active_statuses"):
		return false
	for entry in unit.get_active_statuses():
		var sd: StatusData = entry.get("data")
		if sd != null and sd.status_name == status_name:
			return true
	return false
