# traits/trait_chassis_gardien.gd
# ============================================================
# CHÂSSIS GARDIEN — La grammaire de base du Gardien.
#
# Le Gardien génère de l'énergie quand il PROTÈGE : quand un allié
# adjacent est attaqué, ou quand l'allié qu'il a placé sous Protégé
# reçoit des dégâts.
#
#   Rage : protéger → Rage → Riposte (Frappe de bouclier renforcée)
#   Foi  : protéger → Foi → Rempart ou bouclier allié
#
# Paramètres (.tres optionnel) :
#   rage_on_ally_hit       : float = 12.0  — Rage quand allié adjacent touché
#   rage_bonus_protege     : float = 8.0   — bonus Rage si l'allié avait Protégé
#   foi_on_ally_hit        : float = 10.0  — Foi quand allié adjacent touché
#   foi_bonus_protege      : float = 6.0   — bonus Foi si l'allié avait Protégé
# ============================================================

class_name TraitChassisGardien
extends Trait

var rage_on_ally_hit: float    = 12.0
var rage_bonus_protege: float  = 8.0
var foi_on_ally_hit: float     = 10.0
var foi_bonus_protege: float   = 6.0

func _trait_name() -> String:
	return "chassis_gardien"

func configure(params: Dictionary) -> void:
	rage_on_ally_hit    = params.get("rage_on_ally_hit",    rage_on_ally_hit)
	rage_bonus_protege  = params.get("rage_bonus_protege",  rage_bonus_protege)
	foi_on_ally_hit     = params.get("foi_on_ally_hit",     foi_on_ally_hit)
	foi_bonus_protege   = params.get("foi_bonus_protege",   foi_bonus_protege)

func _activate() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _deactivate() -> void:
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)

# ============================================================
# GÉNÉRATION — quand un allié reçoit des dégâts
# Le Gardien réagit si :
#   - il est vivant et a une énergie
#   - la cible est un allié (même team, pas lui-même)
#   - l'attaquant est un ennemi
# ============================================================

func _on_damage_dealt(target, attacker, _amount, _category, _element, _is_crit) -> void:
	if owner == null or not owner.is_alive or not owner.has_energy():
		return
	# Seuls les alliés non-Gardien déclenchent la réaction
	if target == owner or target.team != owner.team:
		return
	# L'attaque doit venir d'un ennemi
	if attacker == null or attacker.team == owner.team:
		return

	var energy_id: String = owner.energy_type.energy_id
	var had_protege := _has_status(target, "Protégé")

	match energy_id:
		"rage":
			owner.generate_energy(rage_on_ally_hit, source_id)
			DebugLogger.debug(DebugLogger.LogCategory.STATS,
				"%s génère %.0f Rage (châssis Gardien, allié touché)" \
				% [owner.unit_name, rage_on_ally_hit])
			if had_protege:
				owner.generate_energy(rage_bonus_protege, source_id)
				DebugLogger.debug(DebugLogger.LogCategory.STATS,
					"%s génère %.0f Rage bonus (Protégé actif)" \
					% [owner.unit_name, rage_bonus_protege])

		"foi":
			owner.generate_energy(foi_on_ally_hit, source_id)
			DebugLogger.debug(DebugLogger.LogCategory.STATS,
				"%s génère %.0f Foi (châssis Gardien, allié touché)" \
				% [owner.unit_name, foi_on_ally_hit])
			if had_protege:
				owner.generate_energy(foi_bonus_protege, source_id)
				DebugLogger.debug(DebugLogger.LogCategory.STATS,
					"%s génère %.0f Foi bonus (Protégé actif)" \
					% [owner.unit_name, foi_bonus_protege])

# Helper — vérifie si une unité porte un statut par son nom
func _has_status(unit, status_name: String) -> bool:
	if not unit.has_method("get_active_statuses"):
		return false
	for entry in unit.get_active_statuses():
		var sd: StatusData = entry.get("data")
		if sd != null and sd.status_name == status_name:
			return true
	return false
