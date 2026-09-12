extends RefCounted
## Optional encounter objectives. Only the next encounter's consequence is saved.
var enabled := false
var outgoing_alert := 0
var outgoing_boon := false
var incoming_alert := 0
var incoming_boon := false
var contract := ""
var turns := 0
var displaced := 0
var sabotaged := false
var result_text := ""


func begin_encounter() -> void:
	incoming_alert = outgoing_alert
	incoming_boon = outgoing_boon
	outgoing_alert = 0
	outgoing_boon = false
	contract = ""
	turns = 0
	displaced = 0
	sabotaged = false


func finish_combat(budget: int) -> void:
	var success := (
		(contract == "tempo" and turns <= budget)
		or (contract == "control" and displaced >= 2) or (contract == "seal" and sabotaged)
	)
	outgoing_boon = success
	outgoing_alert = 1 if not contract.is_empty() and not success else 0
	result_text = "Défi %s · %s" % [
		"réussi" if success else ("refusé" if contract.is_empty() else "manqué"),
		(
			"prochain combat : bouclier pour Achille"
			if success
			else (
				"prochain combat : premier ennemi protégé" if outgoing_alert > 0 else "aucune conséquence"
			)
		),
	]


func snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"outgoing_alert": outgoing_alert,
		"outgoing_boon": outgoing_boon,
		"result_text": result_text,
	}


func restore(data: Dictionary) -> bool:
	if not data.get("enabled") is bool or not data.get("outgoing_boon") is bool:
		return false
	var alert = data.get("outgoing_alert")
	if not (alert is int or alert is float):
		return false
	if (
		not is_finite(float(alert)) or float(alert) != floor(float(alert))
		or int(alert) not in [0, 1, 2]
	):
		return false
	if not data.get("result_text") is String or data.result_text.length() > 500:
		return false
	enabled = data.enabled
	outgoing_boon = data.outgoing_boon
	outgoing_alert = int(alert)
	result_text = data.result_text
	return true


func restore_retired_deck(data: Dictionary) -> bool:
	return restore(
		{
			"enabled": data.get("enabled"),
			"outgoing_alert": data.get("outgoing_alert"),
			"outgoing_boon": data.get("outgoing_boon"),
			"result_text": "Reprise avec les sorts habituels. Conséquences du dernier défi conservées.",
		}
	)
