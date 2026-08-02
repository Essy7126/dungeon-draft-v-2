extends Node

const LogDefinitions = preload("res://debug/log_definitions.gd")
const CAT_COMBAT: LogDefinitions.LogCategory = LogDefinitions.LogCategory.COMBAT
const CAT_STATS: LogDefinitions.LogCategory = LogDefinitions.LogCategory.STATS

func _ready() -> void:
	EventBus.health_damage_taken.connect(_on_health_damage_taken)
	EventBus.attack_dodged.connect(_on_attack_dodged)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.status_applied.connect(_on_status_applied)
	EventBus.status_refreshed.connect(_on_status_refreshed)
	EventBus.status_expired.connect(_on_status_expired)

func _on_health_damage_taken(target, attacker, amount: int, category: int, element: int, is_crit: bool) -> void:
	var pv := "%d/%d" % [max(target.current_hp, 0), target.max_hp.get_int()]
	var source_name: String = attacker.unit_name if attacker != null else "Terrain"
	var crit_label := " (CRITIQUE)" if is_crit else ""
	DebugLogger.info(CAT_COMBAT, "%s inflige %d degats a %s%s" % [
		source_name, amount, target.unit_name, crit_label], {
		"PV": pv,
		"Detail": "Perte reelle de PV apres mitigation et absorption du bouclier.",
		"Categorie": category,
		"Element": element,
	})

func _on_attack_dodged(target, attacker) -> void:
	var source_name: String = attacker.unit_name if attacker != null else "une attaque"
	DebugLogger.info(CAT_COMBAT, "%s esquive %s" % [target.unit_name, source_name])

func _on_unit_healed(unit, amount: int) -> void:
	DebugLogger.info(CAT_COMBAT, "%s recupere %d PV" % [unit.unit_name, amount], {
		"PV": "%d/%d" % [unit.current_hp, unit.max_hp.get_int()],
		"Detail": "Soin reel apres plafond de PV max.",
	})

func _on_unit_died(unit) -> void:
	DebugLogger.info(CAT_COMBAT, "%s est vaincu" % unit.unit_name)

func _on_status_applied(unit, status_data) -> void:
	DebugLogger.info(CAT_STATS, "%s subit %s (%d tours)" % [
		unit.unit_name, status_data.status_name, status_data.duration], {
		"Effet": status_data.description,
	})

func _on_status_refreshed(unit, status_data) -> void:
	DebugLogger.debug(CAT_STATS, "%s : %s rafraichi" % [
		unit.unit_name,
		status_data.status_name,
	])

func _on_status_expired(unit, status_id: StringName) -> void:
	DebugLogger.debug(CAT_STATS, "%s : %s expire" % [unit.unit_name, status_id])
