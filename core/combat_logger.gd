# core/combat_logger.gd
# ============================================================
# COMBAT LOGGER — Le pont entre les faits de combat et le log.
# Autoload (singleton).
#
# Son UNIQUE rôle : écouter l'EventBus et traduire chaque fait de combat
# en une ligne de log, via le DebugLogger générique. Il ne calcule rien,
# ne décide rien : il observe et rapporte.
#
# Pourquoi un fichier séparé plutôt que d'abonner DebugLogger lui-même ?
#   - DebugLogger reste un OUTIL GÉNÉRIQUE (il logge SPELL, TERRAIN, AI...
#     sans rien savoir du combat).
#   - CombatLogger est le SEUL à connaître "comment se rédige une ligne de
#     combat". Séparation nette des responsabilités.
#   - Le jour où tu veux un combat-log POUR LE JOUEUR, tu crées un 2e abonné
#     du même bus, sans toucher à celui-ci ni à la logique.
#
# Grâce au bus, unit.gd n'appelle plus jamais DebugLogger pour le combat :
# il annonce un fait, ce logger l'écoute. Couplage logique↔log supprimé.
#
# ------------------------------------------------------------
# CONFIGURATION GODOT (Autoload), dans cet ordre :
#   1. DebugLogger   (l'outil de log)
#   2. EventBus      (le système nerveux)
#   3. CombatLogger  (cet abonné — a besoin des deux ci-dessus)
# ------------------------------------------------------------

extends Node

# Raccourcis de catégories (mêmes que celles qu'utilisait unit.gd).
const CAT_COMBAT := DebugLogger.LogCategory.COMBAT
const CAT_STATS := DebugLogger.LogCategory.STATS

func _ready() -> void:
	# On s'abonne à tous les faits de combat. Chaque signal → une ligne de log,
	# identique à ce que unit.gd produisait avant.
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.attack_dodged.connect(_on_attack_dodged)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.status_applied.connect(_on_status_applied)
	EventBus.status_expired.connect(_on_status_expired)
	# (critical_hit n'est PAS logué séparément : l'info "CRITIQUE" est déjà
	#  intégrée dans la ligne de damage_dealt, comme avant. Le signal existe
	#  pour les futurs traits, pas pour doubler le log.)

# ============================================================
# HANDLERS — reproduisent EXACTEMENT les lignes d'avant.
# Les PV sont relus sur l'unité elle-même (le bus transmet l'objet),
# donc aucune information contextuelle n'est perdue.
# ============================================================

func _on_damage_dealt(target, _attacker, amount: int, _category: int, _element: int, is_crit: bool) -> void:
	var pv := "%d/%d" % [max(target.current_hp, 0), target.max_hp.get_int()]
	if is_crit:
		DebugLogger.info(CAT_COMBAT, "%s subit %d dégâts (CRITIQUE)" % [
			target.unit_name, amount], { "PV": pv })
	else:
		DebugLogger.info(CAT_COMBAT, "%s subit %d dégâts" % [
			target.unit_name, amount], { "PV": pv })

func _on_attack_dodged(target, _attacker) -> void:
	DebugLogger.info(CAT_COMBAT, "%s esquive l'attaque" % target.unit_name)

func _on_unit_healed(unit, amount: int) -> void:
	DebugLogger.info(CAT_COMBAT, "%s récupère %d PV" % [unit.unit_name, amount], {
		"PV": "%d/%d" % [unit.current_hp, unit.max_hp.get_int()],
	})

func _on_unit_died(unit) -> void:
	DebugLogger.info(CAT_COMBAT, "%s est vaincu" % unit.unit_name)

func _on_status_applied(unit, status_data) -> void:
	DebugLogger.info(CAT_STATS, "%s subit %s (%d tours)" % [
		unit.unit_name, status_data.status_name, status_data.duration])

func _on_status_expired(unit, status_name: String) -> void:
	DebugLogger.debug(CAT_STATS, "%s : %s expire" % [unit.unit_name, status_name])
