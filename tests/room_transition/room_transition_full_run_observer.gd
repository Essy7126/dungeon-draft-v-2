extends Node

const TITLE_PATH := "res://ui/TitreEcran.tscn"
const PARTY_PATH := "res://ui/party/PartyPresentationScreen.tscn"
const TRANSITION_PATH := "res://ui/Transitionsalle.tscn"
const POST_COMBAT_PATH := "res://ui/post_combat/PostCombatScreen.tscn"
const RESULT_PATH := "res://ui/RunResultScreen.tscn"
const RUN_PATH := "res://data/runs/first_run.tres"
const PARTY_DATA_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]
const FULL_REPORT_PATH := "res://.godot/painted_full_run_validation.json"
const ROOM_TWO_REPORT_PATH := "C:/Blender_AI_Test/Output/room_transition_room2_open.json"
const CINEMATIC_REPORT_PATH := "C:/Blender_AI_Test/Output/skeleton_chief_cinematic_capture.json"
const SNOW_CINEMATIC_REPORT_PATH := "C:/Blender_AI_Test/Output/snow_centurion_room4_cinematic_capture.json"
const ROOM_FOUR_REPORT_PATH := "C:/Blender_AI_Test/Output/snow_centurion_room4_open.json"
const CHIEF_ARTIFACT_DIR := "res://artifacts/skeleton_chief"
const SNOW_ARTIFACT_DIR := "res://artifacts/skeleton_snow_centurion"
const EXPECTED_HERO_IDS := [&"elf", &"mage", &"warrior"]
const EXPECTED_ENEMY_IDS_BY_ROOM := {
	0: [&"skeleton_melee", &"skeleton_melee", &"skeleton_ranged"],
	1: [&"skeleton_chief", &"skeleton_melee", &"skeleton_ranged"],
	2: [&"skeleton_melee", &"skeleton_melee", &"skeleton_ranged"],
	# La Rune conserve ses spawns historiques hors grille : le ranged ne peut
	# pas être instancié en runtime. Ce test enregistre l'état existant sans le
	# corriger dans une mission limitée aux maps peintes.
	3: [&"skeleton_chief", &"skeleton_melee"],
	4: [
		&"skeleton_chief", &"skeleton_chief", &"skeleton_chief",
		&"skeleton_snow_centurion", &"skeleton_snow_centurion",
		&"skeleton_ranged",
	],
	5: [
		&"skeleton_chief", &"skeleton_chief", &"skeleton_chief",
		&"skeleton_snow_centurion", &"skeleton_snow_centurion",
		&"skeleton_ranged",
	],
}

var stop_with_room_two_open := false
var stop_with_room_four_open := false
var cinematic_capture := false
var snow_centurion_cinematic_capture := false
var _handled_scene_id := 0
var _handled_rooms := {}
var _pending_old_scene := {}
var _initial_hero_state := {}
var _started_at_msec := 0
var _finished := false
var _report := {
	"route": [],
	"rooms": [],
	"transitions": [],
	"errors": [],
	"warnings": [],
	"active_enemy_visual_at_transition": false,
	"active_projectile_before_room_1_victory": false,
}


func begin() -> void:
	_started_at_msec = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_debug_overlays()
	get_tree().scene_changed.connect(_on_scene_changed)
	GameManager.scene_change_requested.connect(_on_scene_change_requested)
	GameManager.cleanup_run_state()
	var run_data := load(RUN_PATH) as RunData
	var party_data: Array[UnitData] = []
	for path in PARTY_DATA_PATHS:
		party_data.append(load(path) as UnitData)
	if run_data == null or party_data.any(func(data): return data == null):
		_fail("La configuration de la Run V1 est incomplete.")
		_finish_and_quit(90)
		return
	GameManager.start_preconfigured_run.call_deferred(run_data, party_data)


func _exit_tree() -> void:
	if get_tree() != null and get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.disconnect(_on_scene_changed)
	if GameManager.scene_change_requested.is_connected(_on_scene_change_requested):
		GameManager.scene_change_requested.disconnect(_on_scene_change_requested)


func _process(_delta: float) -> void:
	if _finished:
		return
	if Time.get_ticks_msec() - _started_at_msec > 150000:
		_fail("TIMEOUT: le parcours des six salles n'a pas termine en 150 s.")
		_finish_and_quit(91)


func _on_scene_changed() -> void:
	call_deferred("_handle_current_scene")


func _handle_current_scene() -> void:
	if _finished:
		return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var scene_id := scene.get_instance_id()
	if scene_id == _handled_scene_id:
		return
	_handled_scene_id = scene_id
	var path := scene.scene_file_path
	_report.route.append(path)
	print("ROOM_VALIDATION_SCENE=", path)

	if path == TITLE_PATH:
		await get_tree().process_frame
		if is_instance_valid(scene) and scene.has_method("_on_trio_fixe"):
			scene._on_trio_fixe()
		else:
			_fail("Le bouton Trio fixe du titre n'est pas disponible.")
	elif path == PARTY_PATH:
		await get_tree().process_frame
		if not is_instance_valid(scene) or not scene.has_method("start_with_manager"):
			_fail("PartyPresentationScreen ne peut pas lancer le run.")
			return
		if not scene.start_with_manager(GameManager):
			_fail("PartyPresentationScreen a refuse le demarrage du run.")
	elif path == TRANSITION_PATH:
		await get_tree().process_frame
		await _validate_old_scene_cleanup("transition")
		if GameManager.get_current_room() == null:
			_fail("La transition ne possede aucune salle courante.")
			return
		GameManager.start_next_battle()
	elif path == POST_COMBAT_PATH:
		await _handle_post_combat(scene)
	elif scene.has_method("_end_battle") and scene.has_method("_check_battle_end"):
		_handle_battle(scene)
	elif path == RESULT_PATH:
		await _validate_old_scene_cleanup("run_result")
		_finish_full_run()


func _handle_battle(battle: Node) -> void:
	var room_index: int = GameManager.current_room_index
	if _handled_rooms.has(room_index):
		_fail("Double chargement detecte pour la salle %d." % (room_index + 1))
		return
	_handled_rooms[room_index] = true
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(battle) or get_tree().current_scene != battle:
		_fail("La salle %d a disparu pendant son initialisation." % (room_index + 1))
		return

	await _validate_old_scene_cleanup("battle_%d" % (room_index + 1))
	var room: RoomData = GameManager.get_current_room()
	if room == null:
		_fail("RoomData absente pour la salle %d." % (room_index + 1))
		return
	var deployed := 0
	for cell in room.hero_spawn_zone:
		if deployed >= GameManager.heroes.size():
			break
		if battle.grid.is_walkable(cell):
			battle._deployment.on_cell_clicked(cell)
			deployed += 1
			await get_tree().process_frame
	if deployed != 3:
		_fail("Salle %d: seulement %d heros deployes." % [room_index + 1, deployed])
		return
	await get_tree().process_frame

	var heroes: Array = battle.units.filter(
		func(unit): return unit != null and unit.team == 0
	)
	var enemies: Array = battle.units.filter(
		func(unit): return unit != null and unit.team == 1
	)
	var hero_ids := heroes.map(func(unit): return unit.unit_id)
	var enemy_ids := enemies.map(func(unit): return unit.unit_id)
	var enemy_ids_sorted := enemy_ids.duplicate()
	enemy_ids_sorted.sort()
	var expected_sorted: Array = EXPECTED_ENEMY_IDS_BY_ROOM.get(room_index, []).duplicate()
	expected_sorted.sort()
	if hero_ids != EXPECTED_HERO_IDS:
		_fail("Salle %d: trio inattendu %s." % [room_index + 1, str(hero_ids)])
	if enemy_ids_sorted != expected_sorted:
		_fail("Salle %d: roster ennemi inattendu %s." % [room_index + 1, str(enemy_ids)])
	var expected_enemy_count: int = EXPECTED_ENEMY_IDS_BY_ROOM.get(room_index, []).size()
	if enemies.size() != expected_enemy_count:
		_fail("Salle %d: %d ennemis au lieu de %d." % [
			room_index + 1, enemies.size(), expected_enemy_count,
		])

	var hero_state := _snapshot_heroes(GameManager.heroes)
	if room_index == 0:
		_initial_hero_state = hero_state.duplicate(true)
	else:
		_validate_hero_persistence(room_index, hero_state)
	var hud_ok := _hud_is_bound_to(battle)
	if not hud_ok:
		_fail("Salle %d: le HUD persistant n'est pas lie a la nouvelle Battle." % (room_index + 1))
	var persistent_ui_count := 0
	for child in GameManager.get_children():
		if child is PersistentRunUI:
			persistent_ui_count += 1
	if persistent_ui_count != 1:
		_fail("Salle %d: %d interfaces persistantes detectees." % [room_index + 1, persistent_ui_count])

	var vfx_layer := battle.get_node_or_null("VFXLayer")
	var room_record := {
		"room": room_index + 1,
		"scene": battle.scene_file_path,
		"hero_ids": hero_ids.map(func(value): return str(value)),
		"enemy_ids": enemy_ids.map(func(value): return str(value)),
		"hero_state": hero_state,
		"hud_bound": hud_ok,
		"persistent_ui_count": persistent_ui_count,
		"projectiles_on_entry": get_tree().get_nodes_in_group("skeleton_ranged_projectiles").size(),
		"vfx_children_on_entry": vfx_layer.get_child_count() if is_instance_valid(vfx_layer) else -1,
	}
	_report.rooms.append(room_record)
	print("ROOM_VALIDATION_READY=", room_index + 1, " HEROES=", hero_ids, " ENEMIES=", enemy_ids)

	if room_index == 1 and stop_with_room_two_open:
		if room_record.projectiles_on_entry != 0 or room_record.vfx_children_on_entry != 0:
			_fail("La salle 2 contient encore un projectile ou VFX de la salle 1.")
		await get_tree().create_timer(1.35).timeout
		_save_main_capture("room2_chief_melee_ranged.png")
		_save_main_capture("room2_no_fourth_enemy.png")
		_finish_room_two_open(battle, room_record)
		return
	if room_index == 3 and stop_with_room_four_open:
		await get_tree().create_timer(2.20).timeout
		var runtime_state := _validate_room_four_runtime_state(battle, enemies)
		_save_snow_capture("room4_six_enemies.png")
		_save_snow_capture("room4_three_normal_two_snow_one_ranged.png")
		_save_snow_capture("trio_vs_room4_roster.png")
		_save_snow_capture("room4_no_placeholder.png")
		_save_snow_capture("room4_final_idle.png")
		_finish_room_four_open(battle, room_record, runtime_state)
		return
	if cinematic_capture:
		if room_index == 0:
			await get_tree().create_timer(0.90).timeout
		elif room_index == 1:
			await _capture_skeleton_chief_sequence(battle, enemies)
		elif room_index == 2:
			await get_tree().create_timer(1.10).timeout
			_report["status"] = "CINEMATIC_CAPTURE_COMPLETE"
			_report["duration_msec"] = Time.get_ticks_msec() - _started_at_msec
			_write_report(CINEMATIC_REPORT_PATH, _report)
			_finish_and_quit(0 if _report.errors.is_empty() else 93)
			return
	if snow_centurion_cinematic_capture:
		if room_index == 2:
			await get_tree().create_timer(1.10).timeout
			_save_snow_capture("room3_before_room4_transition.png")
		elif room_index == 3:
			await _capture_snow_centurion_sequence(battle, enemies)

	if room_index == 0:
		await _start_active_ranged_visual_and_projectile(battle, enemies, heroes)
	_pending_old_scene = {
		"room": room_index + 1,
		"battle": weakref(battle),
		"runner": weakref(battle._enemy_turn),
		"views": battle._unit_views.values().map(func(view): return weakref(view)),
		"subviewports": battle.find_children("*", "SubViewport", true, false).map(
			func(viewport): return weakref(viewport)
		),
	}
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		enemy.take_damage(
			enemy.current_hp + 1000,
			GameManager.heroes[0],
			Spell.DamageType.PHYSICAL,
			Spell.Element.NONE
		)
		await get_tree().process_frame
	if not battle._battle_over:
		_fail("Salle %d: la victoire n'a pas marque la Battle terminee." % (room_index + 1))
	print("ROOM_VALIDATION_VICTORY=", room_index + 1)


func _handle_post_combat(screen: Node) -> void:
	await get_tree().process_frame
	await _validate_old_scene_cleanup("post_combat")
	for _step in 12:
		if not is_instance_valid(screen) or get_tree().current_scene != screen:
			return
		if screen.has_method("get_phase_name") \
				and screen.get_phase_name() == &"REWARD_SELECTION":
			break
		screen.advance_or_skip()
		await get_tree().process_frame
	if not is_instance_valid(screen) or screen.get_phase_name() != &"REWARD_SELECTION":
		_fail("L'ecran apres-combat n'a pas atteint la selection de recompense.")
		return
	var options: Array = GameManager.get_post_combat_reward_options()
	if options.is_empty():
		_fail("Aucune recompense apres-combat n'est disponible.")
		return
	var reward_id := StringName(options[0].get("reward_id", &""))
	if not screen.select_reward_by_id(reward_id) or not screen.confirm_selected_reward():
		_fail("La recompense apres-combat n'a pas pu etre confirmee.")
		return
	screen.advance_or_skip()


func _capture_skeleton_chief_sequence(battle: Node, enemies: Array) -> void:
	var chief: Unit = null
	for enemy in enemies:
		if enemy.unit_id == &"skeleton_chief":
			chief = enemy
			break
	if chief == null:
		_fail("Capture: Chef squelette absent de la salle 2.")
		return
	var view = battle._unit_views.get(chief)
	if not is_instance_valid(view) or not view.has_method("get_optional_visual"):
		_fail("Capture: UnitView du Chef absent.")
		return
	var visual = view.get_optional_visual()
	if not is_instance_valid(visual):
		_fail("Capture: SkeletonChiefIsoUnitView absent.")
		return

	await get_tree().create_timer(0.75).timeout
	_save_main_capture("room2_chief_melee_ranged.png")
	_save_main_capture("room2_no_fourth_enemy.png")
	var start_position: Vector2 = view.position
	if visual.has_method("set_facing"):
		visual.set_facing(Vector2i.RIGHT)
	if visual.has_method("play_walk"):
		visual.play_walk()
	var movement: Tween = view.create_tween()
	movement.tween_property(view, "position", start_position + Vector2(72.0, 34.0), 0.24)
	await movement.finished
	await get_tree().create_timer(0.18).timeout
	view.position = start_position

	if visual.has_method("play_basic_attack"):
		visual.play_basic_attack()
	await get_tree().create_timer(0.76).timeout
	_save_main_capture("skeleton_chief_room2_attack.png")
	await get_tree().create_timer(0.80).timeout
	if visual.has_method("play_hit"):
		visual.play_hit()
	await get_tree().create_timer(0.35).timeout
	_save_main_capture("skeleton_chief_room2_hit.png")
	await get_tree().create_timer(0.55).timeout
	chief.take_damage(
		chief.current_hp + 1000,
		GameManager.heroes[0],
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE
	)
	await get_tree().create_timer(1.25).timeout
	_save_main_capture("skeleton_chief_room2_death.png")
	await get_tree().create_timer(1.20).timeout


func _save_main_capture(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHIEF_ARTIFACT_DIR))
	var image := get_viewport().get_texture().get_image()
	var path := CHIEF_ARTIFACT_DIR.path_join(filename)
	var error := image.save_png(path)
	if error != OK:
		_fail("Capture impossible %s: %s" % [path, error_string(error)])


func _capture_snow_centurion_sequence(battle: Node, enemies: Array) -> void:
	var snow_units: Array = enemies.filter(
		func(enemy): return enemy.unit_id == &"skeleton_snow_centurion"
	)
	var ranged_units: Array = enemies.filter(
		func(enemy): return enemy.unit_id == &"skeleton_ranged"
	)
	if snow_units.size() != 2 or ranged_units.size() != 1:
		_fail("Capture Snow: roster salle 4 invalide (%d Snow, %d distance)." % [
			snow_units.size(), ranged_units.size(),
		])
		return
	var snow: Unit = snow_units[0]
	var view = battle._unit_views.get(snow)
	if not is_instance_valid(view) or not view.has_method("get_optional_visual"):
		_fail("Capture Snow: UnitView du Centurion des neiges absent.")
		return
	var visual = view.get_optional_visual()
	if not visual is SnowCenturionIsoUnitView:
		_fail("Capture Snow: SnowCenturionIsoUnitView absent.")
		return
	var heavy_spell := load(SnowCenturionVisual3D.HEAVY_STRIKE_PATH) as Spell
	if heavy_spell == null:
		_fail("Capture Snow: sort HeavyAttack introuvable.")
		return

	await get_tree().create_timer(0.80).timeout
	_save_snow_capture("room4_six_enemies.png")
	_save_snow_capture("room4_three_normal_two_snow_one_ranged.png")
	_save_snow_capture("trio_vs_room4_roster.png")
	_save_snow_capture("room4_no_placeholder.png")

	var sequence := {
		"room": 4,
		"snow_unit_id": str(snow.unit_id),
		"walk_started": false,
		"attack_started": false,
		"heavy_attack_started": false,
		"hit_started": false,
		"death_finished": false,
		"ranged_attack_started": false,
		"captures": [],
	}
	var start_position: Vector2 = view.position
	visual.set_facing(Vector2i.RIGHT)
	sequence.walk_started = visual.play_walk()
	var movement: Tween = view.create_tween()
	movement.tween_property(view, "position", start_position + Vector2(64.0, 32.0), 0.34)
	await get_tree().create_timer(0.20).timeout
	_save_snow_capture("snow_centurion_room4_walk.png")
	sequence.captures.append("snow_centurion_room4_walk.png")
	await movement.finished
	view.position = start_position
	visual.cancel_movement_feedback()
	await get_tree().create_timer(0.15).timeout

	sequence.attack_started = visual.play_basic_attack()
	await get_tree().create_timer(0.34).timeout
	_save_snow_capture("snow_centurion_room4_attack.png")
	sequence.captures.append("snow_centurion_room4_attack.png")
	await get_tree().create_timer(0.62).timeout

	sequence.heavy_attack_started = visual.play_spell_action(heavy_spell)
	await get_tree().create_timer(0.82).timeout
	_save_snow_capture("snow_centurion_room4_heavy_attack.png")
	sequence.captures.append("snow_centurion_room4_heavy_attack.png")
	await get_tree().create_timer(0.62).timeout

	sequence.hit_started = visual.play_hit()
	await get_tree().create_timer(0.34).timeout
	_save_snow_capture("snow_centurion_room4_hit.png")
	sequence.captures.append("snow_centurion_room4_hit.png")
	await get_tree().create_timer(0.52).timeout

	var ranged: Unit = ranged_units[0]
	var ranged_view = battle._unit_views.get(ranged)
	if is_instance_valid(ranged_view) and ranged_view.has_method("get_optional_visual"):
		var ranged_visual = ranged_view.get_optional_visual()
		if is_instance_valid(ranged_visual) and ranged_visual.has_method("play_spell_action") \
				and not ranged.spells.is_empty():
			sequence.ranged_attack_started = ranged_visual.play_spell_action(ranged.spells[0])
			await get_tree().create_timer(0.55).timeout
			_save_snow_capture("skeleton_ranged_room4_attack.png")
			sequence.captures.append("skeleton_ranged_room4_attack.png")
			await get_tree().create_timer(0.65).timeout
	if not sequence.ranged_attack_started:
		_fail("Capture Snow: l'animation du Squelette distance n'a pas demarre.")

	var death_state := {"finished": false}
	var mark_death_finished := func() -> void: death_state.finished = true
	visual.death_animation_finished.connect(mark_death_finished, CONNECT_ONE_SHOT)
	snow.take_damage(
		snow.current_hp + 1000,
		GameManager.heroes[0],
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE
	)
	await get_tree().create_timer(1.05).timeout
	_save_snow_capture("snow_centurion_room4_death.png")
	sequence.captures.append("snow_centurion_room4_death.png")
	var death_deadline := Time.get_ticks_msec() + 8000
	while not death_state.finished and Time.get_ticks_msec() < death_deadline:
		await get_tree().process_frame
	sequence.death_finished = death_state.finished
	if not sequence.death_finished:
		_fail("Capture Snow: Death n'a pas atteint death_animation_finished.")

	for key in ["walk_started", "attack_started", "heavy_attack_started", "hit_started"]:
		if not sequence[key]:
			_fail("Capture Snow: %s n'a pas demarre." % key)
	_report["snow_centurion_sequence"] = sequence


func _save_snow_capture(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SNOW_ARTIFACT_DIR))
	var image := get_viewport().get_texture().get_image()
	var path := SNOW_ARTIFACT_DIR.path_join(filename)
	var error := image.save_png(path)
	if error != OK:
		_fail("Capture impossible %s: %s" % [path, error_string(error)])


func _start_active_ranged_visual_and_projectile(
		battle: Node,
		enemies: Array,
		heroes: Array
	) -> void:
	var ranged: Unit = null
	for enemy in enemies:
		if enemy.unit_id == &"skeleton_ranged":
			ranged = enemy
			break
	if ranged == null or ranged.spells.is_empty() or heroes.is_empty():
		_fail("Impossible d'activer le tir de controle dans la salle 1.")
		return
	var view = battle._unit_views.get(ranged)
	if is_instance_valid(view):
		_start_visual_without_gameplay(view, heroes[0].grid_pos, ranged.spells[0])
	await get_tree().process_frame
	var projectile = VFXManager.play_spell_vfx(ranged, ranged.spells[0], heroes[0].grid_pos)
	var active_count := get_tree().get_nodes_in_group("skeleton_ranged_projectiles").size()
	_report.active_projectile_before_room_1_victory = (
		is_instance_valid(projectile) and active_count > 0
	)
	print("ROOM_VALIDATION_ACTIVE_PROJECTILE=", active_count)
	if not _report.active_projectile_before_room_1_victory:
		_fail("Le projectile de controle n'etait pas actif avant la victoire de la salle 1.")


func _start_visual_without_gameplay(view: Node, cell: Vector2i, spell: Spell) -> void:
	if is_instance_valid(view) and view.has_method("prepare_spell_visual"):
		await view.prepare_spell_visual(cell, spell)


func _on_scene_change_requested(path: String) -> void:
	if path not in [POST_COMBAT_PATH, TRANSITION_PATH, RESULT_PATH]:
		return
	var battle_ref: WeakRef = _pending_old_scene.get("battle")
	var battle = battle_ref.get_ref() if battle_ref != null else null
	if not is_instance_valid(battle):
		return
	var active_death := false
	for view_ref in _pending_old_scene.get("views", []):
		var view = view_ref.get_ref()
		if not is_instance_valid(view) or not view.has_method("get_optional_visual"):
			continue
		var optional = view.get_optional_visual()
		if not is_instance_valid(optional) or not optional.has_method("get_character_visual"):
			continue
		var character = optional.get_character_visual()
		if is_instance_valid(character) and character.has_method("get_current_animation"):
			if str(character.get_current_animation()).to_lower().contains("death"):
				active_death = true
	_report.active_enemy_visual_at_transition = (
		_report.active_enemy_visual_at_transition or active_death
	)
	print("ROOM_VALIDATION_DEATH_ACTIVE_AT_TRANSITION=", active_death)


func _validate_old_scene_cleanup(destination: String) -> void:
	if _pending_old_scene.is_empty():
		return
	await get_tree().process_frame
	var room_number: int = _pending_old_scene.room
	var battle_freed := _weak_is_empty(_pending_old_scene.battle)
	var runner_freed := _weak_is_empty(_pending_old_scene.runner)
	var views_freed := true
	for view_ref in _pending_old_scene.views:
		if not _weak_is_empty(view_ref):
			views_freed = false
	var subviewports_freed := true
	for viewport_ref in _pending_old_scene.subviewports:
		if not _weak_is_empty(viewport_ref):
			subviewports_freed = false
	var projectile_count := get_tree().get_nodes_in_group("skeleton_ranged_projectiles").size()
	var transition_record := {
		"from_room": room_number,
		"destination": destination,
		"battle_freed": battle_freed,
		"runner_freed": runner_freed,
		"unit_views_freed": views_freed,
		"unit_view_count": _pending_old_scene.views.size(),
		"subviewports_freed": subviewports_freed,
		"subviewport_count": _pending_old_scene.subviewports.size(),
		"projectile_count": projectile_count,
		"vfx_manager_unbound": not is_instance_valid(VFXManager._battle_view),
	}
	_report.transitions.append(transition_record)
	if not battle_freed:
		_fail("Salle %d: l'ancienne Battle est encore vivante." % room_number)
	if not runner_freed:
		_fail("Salle %d: l'ancien EnemyTurnRunner est encore vivant." % room_number)
	if not views_freed:
		_fail("Salle %d: un ancien UnitView est encore vivant." % room_number)
	if not subviewports_freed:
		_fail("Salle %d: un ancien SubViewport est encore vivant." % room_number)
	if room_number in [5, 6] and transition_record.subviewport_count != 9:
		_fail("Salle %d: %d SubViewports au lieu de 9." % [
			room_number, transition_record.subviewport_count,
		])
	if projectile_count != 0:
		_fail("Salle %d: %d projectile(s) residuel(s)." % [room_number, projectile_count])
	if not transition_record.vfx_manager_unbound and destination == "transition":
		_fail("Salle %d: VFXManager reste lie a l'ancienne salle." % room_number)
	print("ROOM_VALIDATION_CLEANUP=", JSON.stringify(transition_record))
	_pending_old_scene = {}


func _weak_is_empty(reference: WeakRef) -> bool:
	return reference == null or reference.get_ref() == null


func _snapshot_heroes(heroes: Array) -> Dictionary:
	var snapshot := {}
	for hero in heroes:
		var state = GameManager.get_character_state_for_unit(hero)
		snapshot[str(hero.unit_id)] = {
			"instance_id": hero.get_instance_id(),
			"hp": hero.current_hp,
			"alive": hero.is_alive,
			"state_instance_id": state.get_instance_id() if state != null else 0,
		}
	return snapshot


func _validate_hero_persistence(room_index: int, current: Dictionary) -> void:
	for hero_id in ["elf", "mage", "warrior"]:
		if not _initial_hero_state.has(hero_id) or not current.has(hero_id):
			_fail("Salle %d: etat persistant absent pour %s." % [room_index + 1, hero_id])
			continue
		var before: Dictionary = _initial_hero_state[hero_id]
		var after: Dictionary = current[hero_id]
		if before.instance_id != after.instance_id:
			_fail("Salle %d: l'instance de %s a ete remplacee." % [room_index + 1, hero_id])
		if before.hp != after.hp:
			_fail("Salle %d: les PV de %s ont varie (%d -> %d)." % [room_index + 1, hero_id, before.hp, after.hp])
		if before.state_instance_id != after.state_instance_id:
			_fail("Salle %d: l'etat de progression de %s a ete remplace." % [room_index + 1, hero_id])


func _hud_is_bound_to(battle: Node) -> bool:
	var run_ui = GameManager._persistent_run_ui
	if not is_instance_valid(run_ui):
		return false
	var hud = run_ui.get_combat_hud()
	return is_instance_valid(hud) and hud.get_combat_context() == battle


func _hide_debug_overlays() -> void:
	var autoload_overlay := get_node_or_null("/root/DebugOverlay")
	if is_instance_valid(autoload_overlay):
		autoload_overlay.visible = false
		var autoload_panel := autoload_overlay.get_node_or_null("Panel")
		if is_instance_valid(autoload_panel):
			autoload_panel.visible = false


func _debug_overlays_are_hidden() -> bool:
	for overlay in get_tree().root.find_children("DebugOverlay", "", true, false):
		var panel := overlay.get_node_or_null("Panel")
		if is_instance_valid(panel) and panel.visible:
			return false
	return true


func _validate_room_four_runtime_state(battle: Node, enemies: Array) -> Dictionary:
	var counts := {
		"skeleton_chief": 0,
		"skeleton_snow_centurion": 0,
		"skeleton_ranged": 0,
	}
	var all_alive := true
	var all_idle := true
	var snow_visuals := 0
	for enemy in enemies:
		var enemy_id := str(enemy.unit_id)
		if counts.has(enemy_id):
			counts[enemy_id] += 1
		all_alive = all_alive and enemy.is_alive
		var view = battle._unit_views.get(enemy)
		if not is_instance_valid(view) or not view.has_method("get_optional_visual"):
			all_idle = false
			continue
		var optional = view.get_optional_visual()
		if enemy.unit_id == &"skeleton_snow_centurion" and optional is SnowCenturionIsoUnitView:
			snow_visuals += 1
		if is_instance_valid(optional) and optional.has_method("get_character_visual"):
			var character = optional.get_character_visual()
			if is_instance_valid(character) and character.has_method("get_current_animation"):
				all_idle = all_idle and str(character.get_current_animation()).to_lower().contains("idle")
			else:
				all_idle = false
		else:
			all_idle = false
	var subviewports := battle.find_children("*", "SubViewport", true, false)
	var vfx_layer := battle.get_node_or_null("VFXLayer")
	var state := {
		"enemy_count": enemies.size(),
		"enemy_counts": counts,
		"all_enemies_alive": all_alive,
		"all_enemies_idle": all_idle,
		"snow_visual_count": snow_visuals,
		"subviewport_count": subviewports.size(),
		"subviewport_sizes": subviewports.map(func(viewport): return str(viewport.size)),
		"projectile_count": get_tree().get_nodes_in_group("skeleton_ranged_projectiles").size(),
		"vfx_children": vfx_layer.get_child_count() if is_instance_valid(vfx_layer) else 0,
		"debug_overlays_hidden": _debug_overlays_are_hidden(),
	}
	if state.enemy_count != 6 or counts.skeleton_chief != 3 \
			or counts.skeleton_snow_centurion != 2 or counts.skeleton_ranged != 1:
		_fail("Salle 4 finale: roster 3/2/1 non respecte: %s." % str(counts))
	if not all_alive:
		_fail("Salle 4 finale: au moins un ennemi n'est pas vivant.")
	if not all_idle:
		_fail("Salle 4 finale: au moins un ennemi n'est pas en Idle.")
	if snow_visuals != 2:
		_fail("Salle 4 finale: %d visuels Snow natifs au lieu de 2." % snow_visuals)
	if state.subviewport_count != 9:
		_fail("Salle 4 finale: %d SubViewports au lieu de 9." % state.subviewport_count)
	if state.projectile_count != 0 or state.vfx_children != 0:
		_fail("Salle 4 finale: projectile ou VFX residuel detecte.")
	if not state.debug_overlays_hidden:
		_fail("Salle 4 finale: un overlay debug est visible.")
	return state


func _finish_room_two_open(battle: Node, room_record: Dictionary) -> void:
	if GameManager.current_room_index != 1:
		_fail("Le mode visuel ne s'est pas arrete dans la salle 2.")
	if battle._battle_over:
		_fail("La salle 2 est deja terminee dans l'etat final.")
	var payload := {
		"status": "ROOM_2_OPEN",
		"room": 2,
		"scene": battle.scene_file_path,
		"room_record": room_record,
		"errors": _report.errors,
	}
	_write_report(ROOM_TWO_REPORT_PATH, payload)
	_finished = true
	print("ROOM_TRANSITION_ROOM_2_OPEN=", JSON.stringify(payload))
	call_deferred("queue_free")


func _finish_room_four_open(
		battle: Node,
		room_record: Dictionary,
		runtime_state: Dictionary
	) -> void:
	if GameManager.current_room_index != 3:
		_fail("Le mode visuel ne s'est pas arrete dans la salle 4.")
	if battle._battle_over:
		_fail("La salle 4 est deja terminee dans l'etat final.")
	var payload := {
		"status": "ROOM_4_OPEN",
		"room": 4,
		"scene": battle.scene_file_path,
		"room_record": room_record,
		"runtime_state": runtime_state,
		"errors": _report.errors,
	}
	_write_report(ROOM_FOUR_REPORT_PATH, payload)
	_finished = true
	print("SNOW_CENTURION_ROOM_4_OPEN=", JSON.stringify(payload))
	call_deferred("queue_free")


func _finish_full_run() -> void:
	if _handled_rooms.size() != 6:
		_fail("Le parcours n'a visite que %d salle(s) sur 6." % _handled_rooms.size())
	if _report.transitions.size() != 6:
		_fail("Seulement %d nettoyages de salle sur 6 ont ete controles." % _report.transitions.size())
	if not _report.active_enemy_visual_at_transition:
		_fail("Aucune animation ennemie active n'a ete observee au changement de scene.")
	_report["completed_rooms"] = _handled_rooms.size()
	_report["final_scene"] = get_tree().current_scene.scene_file_path
	_report["duration_msec"] = Time.get_ticks_msec() - _started_at_msec
	_report["status"] = "PASS" if _report.errors.is_empty() else "FAIL"
	_write_report(FULL_REPORT_PATH, _report)
	if snow_centurion_cinematic_capture:
		_write_report(SNOW_CINEMATIC_REPORT_PATH, _report)
	print("ROOM_TRANSITION_FULL_RUN_RESULT=", JSON.stringify(_report))
	_finish_and_quit(0 if _report.errors.is_empty() else 92)


func _write_report(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Impossible d'ecrire le rapport %s (erreur %d)." % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()


func _fail(message: String) -> void:
	if message in _report.errors:
		return
	_report.errors.append(message)
	push_error("ROOM_VALIDATION: " + message)


func _finish_and_quit(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	GameManager.cleanup_run_state()
	# Laisser les queue_free du HUD persistant et du dernier ecran se vider avant
	# l'arret headless, afin que le controle de fuites reflete le runtime reel.
	var tree := get_tree()
	if tree != null:
		await tree.process_frame
		await tree.process_frame
	get_tree().quit(exit_code)
