class_name SkeletonFactionAudit
extends Node2D

const GridViewScript = preload("res://battle/grid_view.gd")
const UnitViewScene = preload("res://battle/unit_view.tscn")
const NORMAL := preload("res://data/units/ennemie/skeleton_melee.tres")
const CHIEF := preload("res://data/units/ennemie/skeleton_chief.tres")
const CENTURION := preload("res://data/units/ennemie/skeleton_snow_centurion.tres")

var grid: GridData
var pathfinder: Pathfinder
var terrain: TerrainEffects
var caster: SpellCaster
var ai: EnemyAI
var queue: TurnQueue
var units: Array = []
var views: Dictionary = {}
var grid_view: Node2D
var telegraphs: TacticalTelegraphLayer
var info_label: RichTextLabel
var scenario_label: Label
var action_box: VBoxContainer
var active_scenario := "A"


func _ready() -> void:
	_build_ui()
	_load_scenario("A")
	if "--capture-skeleton-audit" in OS.get_cmdline_user_args():
		_capture_sequence.call_deferred()


func _process(_delta: float) -> void:
	_refresh_info()


func _build_ui() -> void:
	grid_view = GridViewScript.new()
	grid_view.position = Vector2(28, 72)
	grid_view.show_terrain_colors = true
	grid_view.show_grid_lines = true
	add_child(grid_view)
	telegraphs = TacticalTelegraphLayer.new()
	grid_view.add_child(telegraphs)
	telegraphs.setup(grid_view)

	var panel := PanelContainer.new()
	panel.position = Vector2(700, 22)
	panel.size = Vector2(550, 675)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "AUDIT — FACTION SQUELETTE TACTIQUE"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for scenario in ["A", "B", "C", "D"]:
		var button := Button.new()
		button.text = "Scenario " + scenario
		button.pressed.connect(func() -> void: _load_scenario(scenario))
		tabs.add_child(button)
	scenario_label = Label.new()
	scenario_label.add_theme_font_size_override("font_size", 17)
	column.add_child(scenario_label)
	action_box = VBoxContainer.new()
	column.add_child(action_box)
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = false
	info_label.custom_minimum_size = Vector2(500, 360)
	column.add_child(info_label)


func _reset_battlefield() -> void:
	if telegraphs != null:
		telegraphs.clear_all()
	for view_value in views.values():
		if is_instance_valid(view_value):
			view_value.queue_free()
	views.clear()
	units.clear()
	grid = GridData.new(10, 8)
	pathfinder = Pathfinder.new(grid)
	terrain = TerrainEffects.new(grid)
	caster = SpellCaster.new(grid, pathfinder, terrain)
	ai = EnemyAI.new(grid, pathfinder, caster)
	queue = TurnQueue.new()
	grid_view.setup(grid)
	for child in action_box.get_children():
		child.queue_free()


func _add_action(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	action_box.add_child(button)


func _place(unit: Unit, cell: Vector2i) -> Unit:
	grid.place_unit(unit, cell)
	units.append(unit)
	var view := UnitViewScene.instantiate()
	grid_view.add_child(view)
	view.setup(unit)
	view.position = grid_view.grid_to_world(cell)
	unit.moved.connect(func(_from: Vector2i, to: Vector2i) -> void:
		if is_instance_valid(view):
			view.position = grid_view.grid_to_world(to)
	)
	views[unit] = view
	return unit


func _enemy(data: UnitData, cell: Vector2i) -> Unit:
	return _place(Unit.from_data(data), cell)


func _hero(name: String, cell: Vector2i, hp := 260) -> Unit:
	var hero := Unit.new(name, 0, hp, 10, 6, 3, 24)
	hero.unit_id = StringName(name.to_lower().replace(" ", "_"))
	return _place(hero, cell)


func _find_role(role_id: StringName) -> Unit:
	for value in units:
		var unit := value as Unit
		if unit != null and unit.is_alive and unit.tactical_role_id == role_id:
			return unit
	return null


func _find_spell(unit: Unit, spell_id: StringName) -> Spell:
	if unit == null:
		return null
	for value in unit.spells:
		var spell := value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _load_scenario(scenario: String) -> void:
	active_scenario = scenario
	_reset_battlefield()
	match scenario:
		"A":
			scenario_label.text = "A — Formation macabre : 0, 1 ou 2 voisins"
			_enemy(NORMAL, Vector2i(4, 3))
			_enemy(NORMAL, Vector2i(1, 1))
			_enemy(NORMAL, Vector2i(8, 6))
			_add_action("Isoler", _formation_zero)
			_add_action("Placer 1 voisin", _formation_one)
			_add_action("Placer 2 voisins", _formation_two)
		"B":
			scenario_label.text = "B — Chef : Sentence et Ossature colossale"
			_enemy(CHIEF, Vector2i(4, 3))
			_hero("Cible", Vector2i(5, 3))
			_add_action("Preparer Sentence", _prepare_sentence)
			_add_action("Sortir la cible de l'adjacence", _evade_sentence)
			_add_action("Activation suivante / resoudre", _resolve_chief)
			_add_action("Tester une poussee de 1", _push_chief_once)
		"C":
			scenario_label.text = "C — Centurion limite : marque, lance, egide, 1 summon"
			var centurion := _enemy(CENTURION, Vector2i(2, 3))
			centurion.spells = centurion.spells.filter(func(value):
				return (value as Spell).get_effective_spell_id() != &"raise_chief"
			)
			var summon := _find_spell(centurion, &"call_bones").duplicate(true) as Spell
			summon.max_uses_per_combat = 1
			for index in centurion.spells.size():
				if (centurion.spells[index] as Spell).get_effective_spell_id() == &"call_bones":
					centurion.spells[index] = summon
			_enemy(NORMAL, Vector2i(4, 2))
			_enemy(NORMAL, Vector2i(4, 4))
			_hero("Hero A", Vector2i(8, 3))
			_hero("Hero B", Vector2i(8, 6))
			_add_action("Marquer Hero A", _cast_mark)
			_add_action("Lance de givre sur Hero A", _cast_lance)
			_add_action("Egide sur un squelette", _cast_aegis)
			_add_action("Telegraphier l'invocation", _prepare_normal_summon)
			_add_action("Activation suivante / invoquer", _resolve_centurion)
		"D":
			scenario_label.text = "D — Groupe complet : limite 6 et Lever le chef"
			_enemy(CENTURION, Vector2i(2, 3))
			_enemy(NORMAL, Vector2i(1, 1))
			_enemy(NORMAL, Vector2i(1, 5))
			_hero("Hero A", Vector2i(8, 3), 320)
			_hero("Hero B", Vector2i(9, 1), 300)
			_hero("Hero C", Vector2i(9, 6), 280)
			_add_action("Blesser le centurion a 75 PV", _wound_centurion)
			_add_action("Telegraphier Lever le chef", _prepare_raise_chief)
			_add_action("Activation suivante / lever", _resolve_centurion)
	queue.setup(units)
	grid_view.queue_redraw()


func _formation_zero() -> void:
	var normals := units.filter(func(value): return (value as Unit).tactical_role_id == &"skeleton_normal")
	grid.relocate_unit(normals[1], Vector2i(1, 1))
	grid.relocate_unit(normals[2], Vector2i(8, 6))


func _formation_one() -> void:
	_formation_zero()
	var normals := units.filter(func(value): return (value as Unit).tactical_role_id == &"skeleton_normal")
	grid.relocate_unit(normals[1], Vector2i(4, 2))


func _formation_two() -> void:
	_formation_one()
	var normals := units.filter(func(value): return (value as Unit).tactical_role_id == &"skeleton_normal")
	grid.relocate_unit(normals[2], Vector2i(5, 3))


func _prepare_sentence() -> void:
	var chief := _find_role(&"skeleton_chief")
	var target := units.filter(func(value): return (value as Unit).team == 0)[0] as Unit
	chief.start_turn()
	caster.cast(chief, _find_spell(chief, &"scarlet_sentence"), target.grid_pos)


func _evade_sentence() -> void:
	var target := units.filter(func(value): return (value as Unit).team == 0)[0] as Unit
	grid.relocate_unit(target, Vector2i(7, 3))


func _resolve_chief() -> void:
	var chief := _find_role(&"skeleton_chief")
	chief.start_turn()
	caster.resolve_pending_activation(chief, units, queue, _on_summoned)


func _push_chief_once() -> void:
	var chief := _find_role(&"skeleton_chief")
	var hero := units.filter(func(value): return (value as Unit).team == 0)[0] as Unit
	chief.on_actor_activation_started(hero)
	caster._push_unit(hero, chief, 1)


func _cast_mark() -> void:
	var centurion := _find_role(&"skeleton_centurion")
	var hero := units.filter(func(value): return (value as Unit).team == 0)[0] as Unit
	caster.cast(centurion, _find_spell(centurion, &"centurion_mark"), hero.grid_pos)


func _cast_lance() -> void:
	var centurion := _find_role(&"skeleton_centurion")
	var hero := units.filter(func(value): return (value as Unit).team == 0)[0] as Unit
	caster.cast(centurion, _find_spell(centurion, &"frost_lance"), hero.grid_pos)


func _cast_aegis() -> void:
	var centurion := _find_role(&"skeleton_centurion")
	var normal := _find_role(&"skeleton_normal")
	caster.cast(centurion, _find_spell(centurion, &"frost_aegis"), normal.grid_pos)


func _prepare_normal_summon() -> void:
	var centurion := _find_role(&"skeleton_centurion")
	centurion.start_turn()
	caster.cast(centurion, _find_spell(centurion, &"call_bones"), Vector2i(4, 3))


func _resolve_centurion() -> void:
	var centurion := _find_role(&"skeleton_centurion")
	centurion.start_turn()
	caster.resolve_pending_activation(centurion, units, queue, _on_summoned)


func _wound_centurion() -> void:
	var centurion := _find_role(&"skeleton_centurion")
	centurion.current_hp = 75
	centurion.hp_changed.emit(centurion)


func _prepare_raise_chief() -> void:
	var centurion := _find_role(&"skeleton_centurion")
	centurion.start_turn()
	caster.cast(centurion, _find_spell(centurion, &"raise_chief"), Vector2i(4, 3))


func _on_summoned(unit: Unit) -> void:
	var view := UnitViewScene.instantiate()
	grid_view.add_child(view)
	view.setup(unit)
	view.position = grid_view.grid_to_world(unit.grid_pos)
	views[unit] = view


func _refresh_info() -> void:
	if info_label == null:
		return
	var lines := ["[b]Etat runtime[/b]"]
	for value in units:
		var unit := value as Unit
		if unit == null:
			continue
		var statuses: Array = []
		for entry in unit.get_active_statuses():
			statuses.append(String((entry.data as StatusData).get_effective_status_id()))
		lines.append(
			"%s  PV %d/%d  PA %d  PM %d  ARM %d  RM %d  [%s]%s" % [
				unit.unit_name,
				unit.current_hp,
				unit.max_hp.get_int(),
				unit.current_ap,
				unit.current_mp,
				unit.armure.get_int(),
				unit.resist_magique.get_int(),
				", ".join(statuses),
				"  TELEGRAPHE" if not unit.pending_ability.is_empty() else "",
			]
		)
	lines.append("\nEnnemis vivants : %d / 6" % grid.count_living_in_team(1))
	info_label.text = "\n".join(lines)


func _save_capture(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://artifacts/skeleton_faction_audit")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(file_name))


func _capture_sequence() -> void:
	await get_tree().create_timer(0.8).timeout
	if not _capture_normal_move_then_attack():
		push_error("Capture impossible : le squelette normal n'a pas produit mouvement + attaque.")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.35).timeout
	await _save_capture("09_normal_move_then_attack.png")
	if not _capture_chief_move_then_sentence():
		push_error("Capture impossible : le chef n'a pas produit mouvement + Sentence.")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.35).timeout
	await _save_capture("10_chief_move_then_sentence.png")
	_load_scenario("A")
	await get_tree().create_timer(0.5).timeout
	await _save_capture("01_skeleton_isolated.png")
	_formation_two()
	await get_tree().create_timer(0.4).timeout
	await _save_capture("02_formation_two_neighbors.png")
	_load_scenario("C")
	await get_tree().create_timer(0.5).timeout
	_cast_mark()
	await _save_capture("03_centurion_mark.png")
	_cast_aegis()
	await _save_capture("05_frost_aegis.png")
	_prepare_normal_summon()
	await _save_capture("06_summon_telegraph.png")
	_load_scenario("B")
	await get_tree().create_timer(0.5).timeout
	_prepare_sentence()
	await _save_capture("04_scarlet_sentence.png")
	_load_scenario("D")
	await get_tree().create_timer(0.5).timeout
	await _save_capture("08_full_group.png")
	_wound_centurion()
	_prepare_raise_chief()
	_resolve_centurion()
	await get_tree().create_timer(0.8).timeout
	await _save_capture("07_raised_chief.png")
	print("SKELETON_VISUAL_AUDIT=PASS")
	get_tree().quit(0)


func _capture_normal_move_then_attack() -> bool:
	_reset_battlefield()
	scenario_label.text = "Activation normale — mouvement puis Lame osseuse"
	var normal := _enemy(NORMAL, Vector2i(1, 3))
	var hero := _hero("Cible", Vector2i(5, 3), 260)
	queue.setup(units)
	normal.start_turn()
	var hp_before := hero.current_hp
	var origin := normal.grid_pos
	var plan := ai.build_action_plan(normal, units)
	_execute_plan_for_capture(normal, plan)
	grid_view.queue_redraw()
	return normal.grid_pos != origin and hero.current_hp < hp_before


func _capture_chief_move_then_sentence() -> bool:
	_reset_battlefield()
	scenario_label.text = "Activation chef — mouvement puis préparation de Sentence écarlate"
	var chief := _enemy(CHIEF, Vector2i(1, 3))
	var hero := _hero("Cible", Vector2i(4, 3), 260)
	hero.current_hp = 100
	queue.setup(units)
	chief.start_turn()
	var origin := chief.grid_pos
	var plan := ai.build_action_plan(chief, units)
	_execute_plan_for_capture(chief, plan)
	grid_view.queue_redraw()
	return chief.grid_pos != origin \
		and StringName(chief.pending_ability.get("source_ability_id", &"")) \
			== &"scarlet_sentence"


func _execute_plan_for_capture(actor: Unit, plan: EnemyActionPlan) -> void:
	if actor == null or plan == null:
		return
	for action_value in plan.actions:
		var action := action_value as Dictionary
		match StringName(action.get("type", &"")):
			&"move":
				var path := action.get("path", []) as Array
				if path.size() >= 2:
					var steps := mini(actor.current_mp, path.size() - 1)
					if actor.spend_mp(steps):
						grid.relocate_unit(actor, path[steps] as Vector2i)
			&"cast":
				var spell := action.get("spell") as Spell
				if spell != null:
					caster.cast(
						actor,
						spell,
						action.get("cell", Vector2i(-1, -1)) as Vector2i,
					)
			&"attack":
				var target := action.get("target") as Unit
				if target != null and target.is_alive \
						and grid.are_adjacent(actor.grid_pos, target.grid_pos) \
						and actor.spend_ap(actor.get_basic_attack_ap_cost()):
					target.take_damage(actor.get_attack(), actor, Spell.DamageType.PHYSICAL)
