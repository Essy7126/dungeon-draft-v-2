# traits/trait_chassis_guerrier.gd
# ============================================================
# CHÂSSIS GUERRIER — La grammaire de base du champion Guerrier.
#
# Ce trait encode l'IDENTITÉ du Guerrier : un champion de contact,
# de pression et de poussée. Ce qu'il génère dépend de l'énergie équipée :
#
#   Rage : récompense l'agression (frapper, pousser, percuter).
#   Foi  : récompense la protection par violence (pousser pour protéger).
#
# Ce trait REMPLACE le TraitGenRageOnHit générique. Il est la source
# de toute génération d'énergie du Guerrier — pas un trait de loot.
#
# Paramètres (.tres optionnel) :
#   rage_on_hit            : float = 12.0  — Rage gagnée à chaque frappe
#   rage_bonus_collision   : float = 10.0  — bonus si collision (futur)
#   foi_on_hit             : float = 8.0   — Foi gagnée à chaque frappe
#   foi_bonus_ally_adjacent: float = 5.0   — bonus Foi si allié adjacent
#
# Extension future :
#   - Lecture de report["pushed"] pour +Rage/+Foi sur poussée
#   - Lecture de report["collision"] pour le bonus collision Rage
#   - Lecture de report["pushed_away_from_ally"] pour le bouclier Foi
# ============================================================

class_name TraitChassisGuerrier
extends Trait

# Valeurs par défaut — configurables via TraitData.params
var rage_on_hit: float            = 12.0
var rage_bonus_collision: float   = 10.0
var foi_on_hit: float             = 8.0
var foi_bonus_ally_adjacent: float = 5.0

func _trait_name() -> String:
	return "chassis_guerrier"

func configure(params: Dictionary) -> void:
	rage_on_hit             = params.get("rage_on_hit",             rage_on_hit)
	rage_bonus_collision    = params.get("rage_bonus_collision",    rage_bonus_collision)
	foi_on_hit              = params.get("foi_on_hit",              foi_on_hit)
	foi_bonus_ally_adjacent = params.get("foi_bonus_ally_adjacent", foi_bonus_ally_adjacent)

func _activate() -> void:
	EventBus.basic_attack_performed.connect(_on_basic_attack_performed)
	EventBus.spell_cast.connect(_on_spell_cast)

func _deactivate() -> void:
	if EventBus.basic_attack_performed.is_connected(_on_basic_attack_performed):
		EventBus.basic_attack_performed.disconnect(_on_basic_attack_performed)
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)

# ============================================================
# GÉNÉRATION SUR FRAPPE (attaque basique)
# Réagit à chaque coup porté par le Guerrier (sort OU attaque de base).
# damage_dealt est émis par Unit._apply_damage_result après les PV.
# ============================================================

func _on_basic_attack_performed(attacker, _target) -> void:
	if attacker != owner or not owner.is_alive or not owner.has_energy():
		return
	_generate_for_hit()

# ============================================================
# GÉNÉRATION CONDITIONNELLE SUR SORT GÉNÉRATEUR
# Réagit aux sorts coût-0 du Guerrier. Les sorts consommateurs ne déclenchent
# pas le châssis (ils dépensent, ils ne génèrent pas).
# Le rapport contient les données tactiques calculées par SpellCaster.
# ============================================================

func _on_spell_cast(caster, spell: Spell, report: Dictionary) -> void:
	if caster != owner or not owner.is_alive or not owner.has_energy():
		return
	if not spell.is_generator():
		return

	var energy_id: String = owner.energy_type.energy_id

	if spell.deals_damage() and _has_enemy_affected(report):
		_generate_for_hit()

	match energy_id:
		"rage":
			_handle_rage_spell(report)
		"foi":
			_handle_foi_spell(report)

# ============================================================
# BRANCHES RAGE / FOI
# ============================================================

func _generate_for_hit() -> void:
	var energy_id: String = owner.energy_type.energy_id
	match energy_id:
		"rage":
			owner.generate_energy(rage_on_hit, source_id)
			DebugLogger.debug(DebugLogger.LogCategory.STATS,
				"%s génère %.0f Rage (châssis, frappe)" % [owner.unit_name, rage_on_hit])
		"foi":
			owner.generate_energy(foi_on_hit, source_id)
			DebugLogger.debug(DebugLogger.LogCategory.STATS,
				"%s génère %.0f Foi (châssis, frappe)" % [owner.unit_name, foi_on_hit])

func _handle_rage_spell(report: Dictionary) -> void:
	# Bonus collision : actif quand push implémenté (report["collision"] = true).
	if report.get("collision", false):
		owner.generate_energy(rage_bonus_collision, source_id)
		DebugLogger.debug(DebugLogger.LogCategory.STATS,
			"%s génère %.0f Rage bonus (collision)" % [owner.unit_name, rage_bonus_collision])

func _handle_foi_spell(report: Dictionary) -> void:
	# Bonus allié adjacent : déjà disponible via report["ally_adjacent_to_caster"].
	if report.get("ally_adjacent_to_caster", false):
		owner.generate_energy(foi_bonus_ally_adjacent, source_id)
		DebugLogger.debug(DebugLogger.LogCategory.STATS,
			"%s génère %.0f Foi bonus (allié adjacent)" % [owner.unit_name, foi_bonus_ally_adjacent])
	# Bouclier allié sur poussée : actif quand push implémenté.
	# if report.get("pushed_away_from_ally", false):
	#     _protect_nearest_ally(8)

func _has_enemy_affected(report: Dictionary) -> bool:
	for target in report.get("affected_units", []):
		if target != null and target.team != owner.team:
			return true
	return false
