extends RefCounted
## The catalogue's upgradeText can be a delta, not a standalone explanation.
## Resolve these deltas for inspection without changing card rules or content.


static func full_text(row: Dictionary, upgraded := false) -> String:
	var base := str(row.get("baseText", ""))
	if not upgraded:
		return base
	var improved := str(row.get("upgradeText", base))
	if not (
		improved.begins_with("Effet de base") or improved.begins_with("Même effet")
		or improved.begins_with("Même formule")
	):
		return improved
	match str(row.get("id", "")):
		"a01":
			return base.replace("2 phases ennemies", "%d phases ennemies" % int(row.duration))
		"t01":
			return base.replace("2 phases", "%d phases" % int(row.waterReactionDuration))
		"t02":
			return base.replace("1 phase.", "%d phases." % int(row.waterReactionDuration))
		"t04":
			return base.replace("2 phases", "%d phases" % int(row.duration))
		"g06":
			return base.replace(
				"0,30 P de garde",
				"%s P de garde" % str(row.collisionGuard).replace(".", ","),
			)
	# Range-only deltas: the inspector also shows the effective, equipped range.
	if row.get("upgrade", { }).keys() == ["max"]:
		return base
	return base + "\nAmélioration : " + improved.get_slice(";", 1).strip_edges()
