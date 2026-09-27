extends RefCounted
## Reuses the project's checksum + verified temporary-file + atomic rename writer.
## Transaction callbacks operate exclusively on detached data, before presentation.
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const MAX_BYTES := 2_000_000
var path := Profile.SAVE_PATH
var writer: Callable = ExpeditionSaveService.write_snapshot
var state: Dictionary = { }
var blocked := false
var last_error := ""


func initialize(
	run_id: String,
	cards: CatabaseCards,
	seed_value: int,
	visual_variant: Dictionary = { },
	chronicle: Dictionary = { },
) -> bool:
	if run_id.is_empty() or not cards is Cards:
		return false
	var initial := {
		"schema_version": Profile.SCHEMA_VERSION,
		"ruleset_id": Profile.ID,
		"content_version": Profile.CONTENT_VERSION,
		"run_id": run_id,
		"seed": seed_value,
		"action_seq": 0,
		"phase": "preparation",
		"cards": cards.snapshot(),
		"route": { },
		"combat": { },
		"receipts": { },
		"visual_variant": visual_variant.duplicate(true),
		"chronicle": (
			chronicle.duplicate(true)
			if not chronicle.is_empty()
			else { "families": [], "runs": [] }
		),
	}
	if not validation_errors(initial).is_empty() or not writer.call(initial, path):
		last_error = "Impossible d'écrire le départ."
		return false
	state = initial
	blocked = false
	return true


func transact(action_id: String, expected_seq: int, action: Callable) -> Dictionary:
	if state.is_empty() or blocked:
		return { "success": false, "reason": "checkpoint_unavailable" }
	if state.receipts.has(action_id):
		return {
			"success": true,
			"replayed": true,
			"receipt": state.receipts[action_id].duplicate(true),
		}
	if (
		expected_seq != int(state.action_seq)
		or action_id != "%s/%d" % [state.run_id, expected_seq + 1] or not action.is_valid()
	):
		return { "success": false, "reason": "action_sequence" }
	var candidate := state.duplicate(true)
	var result: Variant = action.call(candidate)
	if not result is Dictionary or not result.get("success", false):
		return result if result is Dictionary else { "success": false, "reason": "action_result" }
	candidate.action_seq = expected_seq + 1
	candidate.receipts[action_id] = result.duplicate(true)
	_record_discoveries(candidate)
	if not validation_errors(candidate).is_empty():
		return { "success": false, "reason": "invalid_candidate" }
	if not writer.call(candidate, path):
		blocked = true
		last_error = "L'action n'a pas été engagée : sauvegarde impossible. Réessayez la sauvegarde avant de continuer."
		return { "success": false, "reason": "write_failed" }
	state = candidate
	last_error = ""
	return { "success": true, "replayed": false, "receipt": result.duplicate(true) }


func retry() -> bool:
	if state.is_empty() or not writer.call(state, path):
		return false
	blocked = false
	last_error = ""
	return true


func restore() -> bool:
	var candidate := ExpeditionSaveService.read_snapshot(path)
	if not validation_errors(candidate).is_empty():
		last_error = "Sauvegarde V2 absente ou incompatible."
		return false
	state = candidate
	blocked = false
	last_error = ""
	return true


static func validation_errors(candidate: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if (
		candidate.get("ruleset_id") != Profile.ID
		or candidate.get("content_version") != Profile.CONTENT_VERSION
		or candidate.get("schema_version") != Profile.SCHEMA_VERSION
	):
		return ["Profil ou version de sauvegarde incompatible."]
	if not candidate.get("run_id") is String or str(candidate.run_id).is_empty():
		errors.append("Identité de run absente.")
	for key in ["action_seq", "seed"]:
		var n: Variant = candidate.get(key)
		if (
			not (n is int or n is float) or not is_finite(float(n)) or float(n) < 0
			or float(n) != floorf(float(n)) or float(n) > 2147483647
		):
			errors.append("Compteur invalide : " + key)
	if candidate.get("phase") not in ["preparation", "combat", "reward", "halt", "complete"]:
		errors.append("Phase invalide.")
	for key in ["cards", "route", "combat", "receipts", "visual_variant"]:
		if not candidate.get(key) is Dictionary:
			errors.append("État absent : " + key)
	if not errors.is_empty():
		return errors
	if not RunHeroVisualVariants.validation_errors(candidate.visual_variant).is_empty():
		errors.append("Apparence inconnue.")
	if candidate.phase != "combat" and not candidate.combat.is_empty():
		errors.append("Combat hors de sa phase.")
	if candidate.phase != "preparation":
		for key in ["depth", "hero_hp", "hero_max_hp", "encounter"]:
			var n: Variant = candidate.route.get(key)
			if (
				not (n is int or n is float) or not is_finite(float(n))
				or n != floorf(float(n)) or n < 0
			):
				errors.append("Route invalide : " + key)
		if (
			errors.is_empty()
			and (
				candidate.route.depth > 20 or candidate.route.encounter > 12
				or candidate.route.hero_hp > candidate.route.hero_max_hp
			)
		):
			errors.append("Progression de route incohérente.")
	if not errors.is_empty():
		return errors
	if candidate.route.has("equipment_health_basis"):
		var basis: Variant = candidate.route.equipment_health_basis
		if not basis is Dictionary:
			return ["Proportion de santé invalide."]
		for key in ["hp", "maximum"]:
			var n: Variant = basis.get(key)
			if (
				not (n is int or n is float) or not is_finite(float(n))
				or n != floorf(float(n)) or n < 0
			):
				return ["Proportion de santé invalide."]
		if basis.maximum < 1 or basis.hp > basis.maximum:
			return ["Proportion de santé incohérente."]
	var history: Variant = candidate.get("chronicle", { "families": [], "runs": [] })
	if (
		not history is Dictionary or not history.get("families") is Array
		or not history.get("runs") is Array
	):
		return ["Chronique invalide."]
	if history.runs.size() > 20 or history.families.size() > 48:
		return ["Chronique trop volumineuse."]
	var discovered: Array = []
	for family in history.families:
		if not family is String or Catalog.card(family).is_empty() or family in discovered:
			return ["Découverte invalide."]
		discovered.append(family)
	var run_ids: Array = []
	for row in history.runs:
		if (
			not row is Dictionary or not row.get("run_id") is String
			or row.run_id.is_empty() or row.run_id in run_ids
		):
			return ["Bilan invalide."]
		if (
			row.get("class_id") not in Catalog.CLASSES
			or row.get("outcome") not in ["victory", "defeat", "timeout", "abandoned"]
		):
			return ["Bilan inconnu."]
		for key in ["level", "depth", "consumed"]:
			var n: Variant = row.get(key)
			if (
				not (n is int or n is float) or not is_finite(float(n))
				or n != floorf(float(n)) or n < 0
			):
				return ["Compteur de bilan invalide."]
		if row.level < 1 or row.level > 12 or row.depth > 20:
			return ["Progression de bilan invalide."]
		run_ids.append(row.run_id)
	var cards := Cards.new()
	if not cards.restore(candidate.cards):
		errors.append("État de cartes incohérent.")
		return errors
	if candidate.phase == "combat" and candidate.combat.is_empty():
		errors.append("Combat absent.")
	elif not candidate.combat.is_empty():
		var battle = load("res://core/expedition/consumable_cards_battle.gd").restore(
			cards,
			candidate.combat,
		)
		if battle == null:
			errors.append("Combat incohérent.")
		else:
			battle.dispose()
	# Receipts are consecutive; a forged future receipt cannot skip a payment.
	if candidate.receipts.size() != int(candidate.action_seq):
		errors.append("Journal de transactions incomplet.")
		return errors
	for index in int(candidate.action_seq):
		var id := "%s/%d" % [candidate.run_id, index + 1]
		if not candidate.receipts.get(id) is Dictionary or not candidate.receipts[id].get(
				"success",
				false,
			):
			errors.append("Reçu invalide : " + id)
	if JSON.stringify(candidate).to_utf8_buffer().size() > MAX_BYTES - 1024:
		errors.append("Sauvegarde trop volumineuse.")
	return errors


static func _record_discoveries(candidate: Dictionary) -> void:
	if not candidate.has("chronicle"):
		candidate.chronicle = { "families": [], "runs": [] }
	var history: Dictionary = candidate.chronicle
	for copy in candidate.cards.copies:
		if copy.family not in history.families:
			history.families.append(copy.family)
	for table in [candidate.cards.consumed, candidate.cards.retired]:
		for row in table.values():
			if row.family not in history.families:
				history.families.append(row.family)
	if candidate.phase == "complete" and not history.runs.any(
			func(row):
				return row.get("run_id") == candidate.run_id,
		):
		history.runs.append(
			{
				"run_id": candidate.run_id,
				"class_id": candidate.cards.primary_class,
				"level": candidate.cards.level,
				"depth": candidate.route.get("depth", 0),
				"outcome": candidate.route.get("outcome", ""),
				"consumed": candidate.cards.consumed.size(),
			}
		)
		while history.runs.size() > 20:
			history.runs.pop_front()
