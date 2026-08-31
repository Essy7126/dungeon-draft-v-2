extends RefCounted

## Construit le constat de fin de run a partir de faits deja presents dans le
## GameManager. Aucun historique n'est conserve ici : le service ne fait que
## normaliser les compteurs et formuler l'epitaphe affichee immediatement.


static func build_snapshot(
		victory: bool,
		run_name: String,
		room_flow_mode: StringName,
		current_room_index: int,
		room_names: PackedStringArray,
		seed: int,
		seed_available: bool,
		hero_states: Array[Dictionary]
	) -> Dictionary:
	var normalized_name := run_name.strip_edges()
	var room_total := room_names.size()
	var rooms_cleared := _rooms_cleared(
		victory, current_room_index, room_total
	)
	var reached_room_number := _reached_room_number(
		victory, current_room_index, room_total
	)
	var reached_room_name := _reached_room_name(
		room_names, reached_room_number
	)
	var normalized_heroes := _normalize_hero_states(hero_states)
	var featured_hero_name := ""
	if normalized_heroes.size() == 1:
		featured_hero_name = str(normalized_heroes[0].get("name", ""))
	var is_catabase := normalized_name.to_lower() == "catabase"
	var snapshot := {
		"victory": victory,
		"run_name": normalized_name,
		"room_flow_mode": room_flow_mode,
		"rooms_cleared": rooms_cleared,
		"room_total": room_total,
		"reached_room_number": reached_room_number,
		"reached_room_name": reached_room_name,
		"seed_available": seed_available,
		"seed": seed,
		"hero_states": normalized_heroes,
		"featured_hero_name": featured_hero_name,
		"is_catabase": is_catabase,
	}
	snapshot["epitaph"] = _build_epitaph(snapshot)
	return snapshot


static func _rooms_cleared(
		victory: bool,
		current_room_index: int,
		room_total: int
	) -> int:
	if room_total <= 0:
		return 0
	if victory:
		return room_total
	return clampi(current_room_index, 0, room_total)


static func _reached_room_number(
		victory: bool,
		current_room_index: int,
		room_total: int
	) -> int:
	if room_total <= 0:
		return 0
	if victory:
		return room_total
	return clampi(current_room_index + 1, 0, room_total)


static func _reached_room_name(
		room_names: PackedStringArray,
		reached_room_number: int
	) -> String:
	if reached_room_number <= 0 or reached_room_number > room_names.size():
		return ""
	return room_names[reached_room_number - 1].strip_edges()


static func _normalize_hero_states(
		hero_states: Array[Dictionary]
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in hero_states:
		var name := str(source.get("name", "")).strip_edges()
		var maximum_hp := maxi(0, int(source.get("max_hp", 0)))
		var current_hp := clampi(
			int(source.get("current_hp", 0)), 0, maximum_hp
		)
		result.append({
			"name": name,
			"current_hp": current_hp,
			"max_hp": maximum_hp,
			"alive": bool(source.get("alive", current_hp > 0)),
		})
	return result


static func _build_epitaph(snapshot: Dictionary) -> String:
	var run_name := str(snapshot.get("run_name", "")).strip_edges()
	var room_total := int(snapshot.get("room_total", 0))
	var rooms_cleared := int(snapshot.get("rooms_cleared", 0))
	var reached_room_name := str(
		snapshot.get("reached_room_name", "")
	).strip_edges()
	var is_catabase := bool(snapshot.get("is_catabase", false))
	var victory := bool(snapshot.get("victory", false))
	var sentence := "L’Archiviste consigne : "
	if victory:
		if is_catabase:
			sentence += "la Catabase est achevée — %d/%d salles franchies." % [
				rooms_cleared,
				room_total,
			]
		else:
			sentence += "la tentative est achevée — %d/%d salles franchies." % [
				rooms_cleared,
				room_total,
			]
	else:
		var journey_name := "la Catabase" if is_catabase else "la tentative"
		if reached_room_name != "":
			sentence += "%s s’arrête dans « %s », après %d/%d salles franchies." % [
				journey_name,
				reached_room_name,
				rooms_cleared,
				room_total,
			]
		else:
			sentence += "%s s’arrête après %d/%d salles franchies." % [
				journey_name,
				rooms_cleared,
				room_total,
			]
	var heroes: Array = snapshot.get("hero_states", [])
	if heroes.size() == 1:
		var hero: Dictionary = heroes[0]
		var hero_name := str(hero.get("name", "")).strip_edges()
		if hero_name == "":
			hero_name = "Héros"
		sentence += " %s : %d/%d PV." % [
			hero_name,
			int(hero.get("current_hp", 0)),
			int(hero.get("max_hp", 0)),
		]
	elif heroes.size() > 1:
		var living_count := 0
		for hero_value in heroes:
			if bool((hero_value as Dictionary).get("alive", false)):
				living_count += 1
		sentence += " Héros encore debout : %d/%d." % [
			living_count,
			heroes.size(),
		]
	elif run_name == "" and room_total == 0:
		sentence = "L’Archiviste ne dispose d’aucun fait sur cette tentative."
	return sentence
