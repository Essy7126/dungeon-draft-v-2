extends Node

const NORMAL := preload("res://data/units/ennemie/skeleton_melee.tres")
const CENTURION := preload("res://data/units/ennemie/skeleton_snow_centurion.tres")

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	var report := _simulate()
	print("SKELETON_FORCED_SUMMON_RESULT=" + JSON.stringify(report))
	for failure in _failures:
		push_error("Forced summon integration: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _simulate() -> Dictionary:
	var grid := GridData.new(12, 8)
	var pathfinder := Pathfinder.new(grid)
	var terrain := TerrainEffects.new(grid)
	var caster := SpellCaster.new(grid, pathfinder, terrain)
	var queue := TurnQueue.new()
	var death_connections: Array = []
	var centurion := Unit.from_data(CENTURION)
	var normal_a := Unit.from_data(NORMAL)
	var normal_b := Unit.from_data(NORMAL)
	var hero := Unit.new("Temoin", 0, 500, 10, 6, 4, 9999)
	hero.unit_id = &"forced_simulation_hero"
	var units: Array = [centurion, normal_a, normal_b, hero]
	var placements := {
		centurion: Vector2i(2, 3),
		normal_a: Vector2i(3, 2),
		normal_b: Vector2i(3, 4),
		hero: Vector2i(10, 3),
	}
	for unit_value in placements:
		var unit := unit_value as Unit
		_require(grid.place_unit(unit, placements[unit_value]), "placement initial valide")
	queue.setup(units)
	for unit_value in units:
		_attach_death_cleanup(unit_value as Unit, grid, queue, death_connections)

	var event_counts := {
		&"call_bones": {"telegraphed": 0, "resolved": 0},
		&"raise_chief": {"telegraphed": 0, "resolved": 0},
	}
	var lifecycle_counts := {"pending_cancelled": 0}
	var on_summon_telegraphed := func(
			_event_caster: Unit,
			spell: Spell,
			_target_cell: Vector2i
		) -> void:
		var spell_id := spell.get_effective_spell_id()
		if event_counts.has(spell_id):
			var counts := event_counts[spell_id] as Dictionary
			counts["telegraphed"] = int(counts["telegraphed"]) + 1
	var on_summon_resolved := func(
			_event_caster: Unit,
			_summoned: Unit,
			_target_cell: Vector2i,
			source_ability_id: StringName
		) -> void:
		if event_counts.has(source_ability_id):
			var counts := event_counts[source_ability_id] as Dictionary
			counts["resolved"] = int(counts["resolved"]) + 1
	var on_pending_cancelled := func(
			_event_caster: Unit,
			_payload: Dictionary,
			_reason: StringName
		) -> void:
		lifecycle_counts["pending_cancelled"] = int(lifecycle_counts["pending_cancelled"]) + 1
	EventBus.summon_telegraphed.connect(on_summon_telegraphed)
	EventBus.summon_resolved.connect(on_summon_resolved)
	EventBus.pending_ability_cancelled.connect(on_pending_cancelled)

	# Le squelette manquant est obtenu par une vraie mort runtime, pas en
	# modifiant artificiellement le roster observe par le SpellCaster.
	normal_b.take_damage(9999, hero)
	_require(not normal_b.is_alive, "un squelette normal est mort")
	_require(grid.find_unit(normal_b) == Vector2i(-1, -1), "le squelette mort quitte la grille")
	_require(grid.count_living_in_team(1) == 2, "la faction commence sous la limite globale")

	centurion.current_hp = 75
	var call_bones := _find_spell(centurion, &"call_bones")
	var raise_chief := _find_spell(centurion, &"raise_chief")
	var call_cell := Vector2i(4, 3)
	var chief_cell := Vector2i(2, 5)
	_require(call_bones != null, "Appel des ossements existe")
	_require(raise_chief != null, "Lever le chef existe")
	_require(centurion.current_hp <= 75, "le centurion est a 75 PV ou moins")
	_require(grid.is_walkable(call_cell) and not grid.has_unit(call_cell), "la cellule d'Appel est libre")
	_require(not grid.has_living_unit_id(1, &"skeleton_chief"), "aucun chef vivant")
	_require(not grid.has_pending_summon_unit_id(1, &"skeleton_chief"), "aucun chef en attente")

	centurion.start_turn()
	_require(caster.can_cast(centurion, call_bones, call_cell), "Appel des ossements est disponible")
	var call_prepared := caster.cast(centurion, call_bones, call_cell)
	_require(bool(call_prepared.get("telegraphed", false)), "Appel des ossements est telegraphie")
	_require(grid.get_unit(call_cell) == null, "Appel ne cree rien pendant sa preparation")
	_require(int(event_counts[&"call_bones"]["telegraphed"]) == 1, "Appel emet un seul summon_telegraphed")

	centurion.start_turn()
	var call_result := caster.resolve_pending_activation(
		centurion,
		units,
		queue,
		func(summoned: Unit) -> void:
			_attach_death_cleanup(summoned, grid, queue, death_connections)
	)
	var summoned_normal := call_result.get("summoned_unit") as Unit
	_require(bool(call_result.get("resolved", false)), "Appel des ossements est resolu")
	_require(summoned_normal != null, "Appel cree un squelette")
	_require(summoned_normal.activation_index == 0, "le squelette invoque n'est pas active immediatement")
	_require(queue.get_full_order().count(summoned_normal) == 1, "le squelette est ajoute une seule fois a la TurnQueue")
	_require(int(event_counts[&"call_bones"]["resolved"]) == 1, "Appel emet un seul summon_resolved")
	var peak_enemies := grid.count_living_in_team(1)

	_require(grid.is_walkable(chief_cell) and not grid.has_unit(chief_cell), "la cellule du chef est libre")
	_require(grid.count_living_in_team(1) < 6, "la limite globale reste inferieure a 6")
	_require(caster.can_cast(centurion, raise_chief, chief_cell), "Lever le chef est disponible")
	var chief_prepared := caster.cast(centurion, raise_chief, chief_cell)
	_require(bool(chief_prepared.get("telegraphed", false)), "Lever le chef est telegraphie")
	_require(grid.get_unit(chief_cell) == null, "Lever le chef ne cree rien pendant sa preparation")
	_require(int(event_counts[&"raise_chief"]["telegraphed"]) == 1, "Lever le chef emet un seul summon_telegraphed")

	centurion.start_turn()
	var chief_result := caster.resolve_pending_activation(
		centurion,
		units,
		queue,
		func(summoned: Unit) -> void:
			_attach_death_cleanup(summoned, grid, queue, death_connections)
	)
	var chief := chief_result.get("summoned_unit") as Unit
	_require(bool(chief_result.get("resolved", false)), "Lever le chef est resolu")
	_require(chief != null, "Lever le chef cree un chef")
	_require(chief.current_hp == 154, "le chef est cree a exactement 154 PV")
	_require(chief.activation_index == 0, "le chef invoque n'est pas active immediatement")
	_require(queue.get_full_order().count(chief) == 1, "le chef est ajoute une seule fois a la TurnQueue")
	_require(int(event_counts[&"raise_chief"]["resolved"]) == 1, "Lever le chef emet un seul summon_resolved")
	peak_enemies = maxi(peak_enemies, grid.count_living_in_team(1))
	_require(peak_enemies >= 4, "le pic atteint au moins 4 ennemis simultanes")

	# Un cycle complet de TurnQueue doit activer chaque vivant exactement une
	# fois. Cela prouve a la fois l'absence d'activation immediate et de double tour.
	var cycle_turns := {}
	var on_turn_started := func(unit: Unit) -> void:
		cycle_turns[unit] = int(cycle_turns.get(unit, 0)) + 1
	queue.turn_started.connect(on_turn_started)
	var living_cycle := queue.get_living_order()
	queue.start()
	for _index in range(living_cycle.size() - 1):
		queue.advance()
	queue.turn_started.disconnect(on_turn_started)
	for living_value in living_cycle:
		var living_unit := living_value as Unit
		_require(int(cycle_turns.get(living_unit, 0)) == 1, "aucun double tour pour " + living_unit.unit_name)
	_require(summoned_normal.activation_index == 1, "le squelette joue une seule premiere activation")
	_require(chief.activation_index == 1, "le chef joue une seule premiere activation")
	var sentence := _find_spell(chief, &"scarlet_sentence")
	_require(sentence != null, "Sentence ecarlate existe")
	_require(not chief.can_use_spell(sentence), "Sentence ecarlate est indisponible a la premiere activation")

	# Une capacite differee non liee aux invocations est annulee par la mort du
	# chef. Les compteurs summon restent donc strictement a un evenement par
	# invocation reussie, tout en validant le nettoyage d'un etat en attente.
	_require(grid.relocate_unit(hero, chief.grid_pos + Vector2i.RIGHT), "le temoin rejoint le chef")
	chief.start_turn()
	_require(chief.can_use_spell(sentence), "Sentence devient disponible apres la premiere activation")
	var sentence_prepared := caster.cast(chief, sentence, hero.grid_pos)
	_require(bool(sentence_prepared.get("telegraphed", false)), "Sentence cree un etat differe a annuler")
	_require(not chief.pending_ability.is_empty(), "le chef possede un etat en attente avant sa mort")
	chief.take_damage(9999, hero)
	_require(chief.pending_ability.is_empty(), "la mort annule l'etat en attente")
	_require(int(lifecycle_counts["pending_cancelled"]) == 1, "l'annulation de mort est emise une seule fois")
	_require(grid.find_unit(chief) == Vector2i(-1, -1), "le chef mort ne reste pas sur la grille")
	_require(not queue.get_living_order().has(chief), "le chef mort ne reste pas vivant dans la TurnQueue")

	summoned_normal.take_damage(9999, hero)
	_require(grid.find_unit(summoned_normal) == Vector2i(-1, -1), "le squelette invoque mort ne reste pas sur la grille")
	_require(not queue.get_living_order().has(summoned_normal), "le squelette invoque mort ne reste pas vivant dans la TurnQueue")
	_require(centurion.pending_ability.is_empty(), "le centurion ne conserve aucun etat fantome")
	_require(int(event_counts[&"call_bones"]["telegraphed"]) == 1, "Appel garde exactement un telegraphe")
	_require(int(event_counts[&"call_bones"]["resolved"]) == 1, "Appel garde exactement une resolution")
	_require(int(event_counts[&"raise_chief"]["telegraphed"]) == 1, "Lever garde exactement un telegraphe")
	_require(int(event_counts[&"raise_chief"]["resolved"]) == 1, "Lever garde exactement une resolution")

	EventBus.summon_telegraphed.disconnect(on_summon_telegraphed)
	EventBus.summon_resolved.disconnect(on_summon_resolved)
	EventBus.pending_ability_cancelled.disconnect(on_pending_cancelled)
	var report := {
		"passed": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures,
		"normal_summons_resolved": int(event_counts[&"call_bones"]["resolved"]),
		"chiefs_resolved": int(event_counts[&"raise_chief"]["resolved"]),
		"peak_enemies": peak_enemies,
		"call_bones_events": event_counts[&"call_bones"],
		"raise_chief_events": event_counts[&"raise_chief"],
		"pending_cancelled_after_death": int(lifecycle_counts["pending_cancelled"]),
	}
	_release_death_cleanup(death_connections, grid)
	return report


func _attach_death_cleanup(
		unit: Unit,
		grid: GridData,
		queue: TurnQueue,
		connections: Array
	) -> void:
	var on_died := func(dead: Unit) -> void:
		grid.remove_unit(dead)
		queue.on_unit_died(dead)
	unit.died.connect(on_died)
	connections.append({"unit": unit, "callable": on_died})


func _release_death_cleanup(connections: Array, grid: GridData) -> void:
	for entry_value in connections:
		var entry := entry_value as Dictionary
		var unit := entry.get("unit") as Unit
		var callback: Callable = entry.get("callable", Callable())
		if unit != null and callback.is_valid() and unit.died.is_connected(callback):
			unit.died.disconnect(callback)
	for unit_value in grid.get_units():
		grid.remove_unit(unit_value)
	connections.clear()


func _find_spell(unit: Unit, spell_id: StringName) -> Spell:
	for spell_value in unit.spells:
		var spell := spell_value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _require(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
