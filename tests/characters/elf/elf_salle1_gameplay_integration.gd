extends Node

const HERO_DATA_PATH := "res://data/units/alliés/elfe.tres"
const SUPPORT_DATA_PATH := "res://data/units/alliés/Gardien.tres"
const ROOM_DATA_PATH := "res://data/rooms/bible/le_gue.tres"
const SCREENSHOT_DIR := "res://tests/characters/elf/screenshots"
const REVIEW_OUTPUT := "C:/Blender_AI_Test/Output/godot_elf_first_playable_integration.json"
const SHARPNESS_AUDIT_OUTPUT := "C:/Blender_AI_Test/Output/godot_elf_sharpness_audit.json"
const SHARPNESS_FINAL_OUTPUT := "C:/Blender_AI_Test/Output/godot_elf_sharpness_final.json"
const FIREBALL_AUDIT_OUTPUT := "C:/Blender_AI_Test/Output/godot_fireball_lifecycle_audit.json"
const FIREBALL_INTERRUPTED_OUTPUT := \
	"C:/Blender_AI_Test/Output/godot_fireball_lifecycle_interrupted_before.json"
const FIREBALL_VALIDATION_OUTPUT := \
	"C:/Blender_AI_Test/Output/godot_fireball_lifecycle_validation.json"
const HERO_START_CELL := Vector2i(9, 7)
const REVIEW_CENTER_CELL := Vector2i(5, 4)

@onready var battle = $Battle
@onready var debug_label: Label = $IntegrationUI/Panel/Margin/VBox/DebugLabel

var hero: Unit = null
var support_hero: Unit = null
var hero_view: Node2D = null
var elf_view: ElfIsoUnitView = null
var temporary_visual: CanvasItem = null
var reference_goblin: Unit = null
var reference_goblin_view: Node2D = null
var _debug_run_enabled := false
var _socket_debug_visible := false
var _debug_controls_enabled := false
var _auto_review_running := false
var _performance_sampling := false
var _performance_warmup_frames := 0
var _fps_samples: Array[float] = []
var _screenshots: Array[String] = []
var _errors: Array[String] = []
var _warnings: Array[String] = []
var _root_checks: Array[Dictionary] = []
var _observed_cast_count := 0
var _cast_release_msec := -1
var _spell_cast_msec := -1
var _cast_vfx_origin_delta := -1.0
var _captured_cast_vfx: Node2D = null
var _freeze_cast_vfx_for_capture := true
var _hero_spell_damage_events := 0
var _initial_hit_count := 0
var _death_started_count := 0
var _death_finished_observed := false
var _death_visual_present_until_finished := true
var _death_max_unit_delta := 0.0
var _death_max_elf_delta := 0.0


func _enter_tree() -> void:
	_prepare_runtime_test_run()


func _ready() -> void:
	EventBus.spell_cast.connect(_on_spell_cast_observed)
	EventBus.damage_dealt.connect(_on_damage_observed)
	var args := OS.get_cmdline_user_args()
	_debug_controls_enabled = "--elf-salle1-debug" in args
	$IntegrationUI.visible = _debug_controls_enabled
	await get_tree().process_frame
	if not await _install_on_real_hero():
		push_error("ElfSalle1GameplayIntegration: impossible d'installer le visuel elfe.")
		return
	_place_reference_goblin(Vector2i(8, 6))
	elf_view.set_facing(reference_goblin.grid_pos - hero.grid_pos)
	elf_view.play_idle()
	_update_debug_label()
	if args.is_empty():
		battle._on_cell_clicked(hero.grid_pos)
		hero_view.set_active(true)
	if "--fireball-lifecycle-validation" in args:
		await _run_fireball_lifecycle_validation("--fireball-lifecycle-auto-exit" in args)
		return
	if "--fireball-lifecycle-audit" in args:
		await _run_fireball_lifecycle_audit("--fireball-lifecycle-auto-exit" in args)
		return
	if "--elf-sharpness-audit" in args:
		await _run_sharpness_audit("--elf-sharpness-auto-exit" in args)
		return
	if "--elf-sharpness-board" in args:
		var board_path := await _build_sharpness_comparison_board()
		print("ELF_SHARPNESS_BOARD=", board_path)
		if "--elf-sharpness-auto-exit" in args:
			await _wait_render_frames(2)
			get_tree().quit(0 if board_path != "" else 11)
		return
	if "--elf-sharpness-final" in args:
		await _run_sharpness_final("--elf-sharpness-auto-exit" in args)
		return
	if "--elf-salle1-auto-review" in args:
		_auto_review_running = true
		_run_automated_review("--elf-salle1-auto-exit" in args)


func _process(_delta: float) -> void:
	if _auto_review_running and _performance_sampling:
		_performance_warmup_frames += 1
		if _performance_warmup_frames > 240:
			_fps_samples.append(Engine.get_frames_per_second())
	_update_debug_label()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _debug_controls_enabled or _auto_review_running \
			or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			if is_instance_valid(temporary_visual):
				temporary_visual.visible = not temporary_visual.visible
		KEY_F2:
			if is_instance_valid(elf_view):
				elf_view.visible = not elf_view.visible
		KEY_F3:
			if is_instance_valid(temporary_visual) and is_instance_valid(elf_view):
				temporary_visual.visible = true
				elf_view.visible = true
		KEY_F4:
			_socket_debug_visible = not _socket_debug_visible
			elf_view.set_socket_debug_visible(_socket_debug_visible)
		KEY_F5:
			elf_view.play_hit()
		KEY_F6:
			elf_view.play_death()
		KEY_F7:
			if hero.is_alive:
				elf_view.play_idle()
		KEY_F8:
			_debug_run_enabled = not _debug_run_enabled
			elf_view.set_debug_run_for_next_movement(_debug_run_enabled)


func _prepare_runtime_test_run() -> void:
	var hero_data := load(HERO_DATA_PATH) as UnitData
	var support_data := load(SUPPORT_DATA_PATH) as UnitData
	var room_data := load(ROOM_DATA_PATH) as RoomData
	if hero_data == null or support_data == null or room_data == null:
		push_error("Ressources de test Salle 1 introuvables.")
		return
	hero = Unit.from_data(hero_data)
	support_hero = Unit.from_data(support_data)
	GameManager.heroes = [hero, support_hero]
	GameManager.rooms = [room_data]
	GameManager.current_room_index = 0
	GameManager.run_active = true


func _install_on_real_hero() -> bool:
	if hero == null or battle == null or battle._deployment == null:
		return false
	if battle._deployment.is_active():
		battle._deployment.on_cell_clicked(HERO_START_CELL)
	await get_tree().process_frame
	hero_view = battle._unit_views.get(hero) as Node2D
	if hero_view == null:
		return false
	if not hero_view.has_method("get_optional_visual"):
		return false
	elf_view = hero_view.get_optional_visual() as ElfIsoUnitView
	if elf_view == null:
		return false
	temporary_visual = hero_view.get_node_or_null("IsoTemporaryPlaceholder") as CanvasItem
	elf_view.cast_release_reached.connect(_on_cast_release_observed)
	elf_view.animation_started.connect(_on_elf_animation_started)
	elf_view.death_animation_finished.connect(_on_death_animation_finished_observed)
	## Finish the real deployment with a second, unchanged temporary hero. The
	## scene still contains exactly one ElfVisual3D.
	if battle._deployment.is_active():
		battle._deployment.on_cell_clicked(Vector2i(8, 7))
	await get_tree().process_frame
	return true


func _on_cast_release_observed() -> void:
	_cast_release_msec = Time.get_ticks_msec()


func _on_spell_cast_observed(caster, _spell, _report: Dictionary) -> void:
	if caster != hero:
		return
	_observed_cast_count += 1
	_spell_cast_msec = Time.get_ticks_msec()
	var vfx_layer := battle.get_node_or_null("VFXLayer") as Node2D
	if vfx_layer != null and not vfx_layer.get_children().is_empty():
		var actual_vfx := vfx_layer.get_children().back() as Node2D
		if actual_vfx != null:
			_captured_cast_vfx = actual_vfx
			if _freeze_cast_vfx_for_capture:
				_captured_cast_vfx.set_process(false)
			_cast_vfx_origin_delta = actual_vfx.global_position.distance_to(
				hero_view.get_cast_effect_origin_global()
			)


func _run_fireball_lifecycle_audit(exit_when_done: bool) -> void:
	_freeze_cast_vfx_for_capture = false
	var force_interruption := "--fireball-force-interrupt" in OS.get_cmdline_user_args()
	var vfx_layer := battle.get_node_or_null("VFXLayer") as Node2D
	var result := {
		"initial": {},
		"samples": [],
		"cast_vfx_origin_delta_pixels": -1.0,
		"damage_events": 0,
		"forced_interruption": force_interruption,
		"errors": [],
	}
	if vfx_layer == null:
		result.errors.append("VFXLayer introuvable.")
		_write_json(FIREBALL_AUDIT_OUTPUT, result)
		print("FIREBALL_LIFECYCLE_AUDIT_RESULT=", JSON.stringify(result))
		if exit_when_done:
			get_tree().quit(12)
		return
	result.initial = _fireball_layer_snapshot("before_cast", vfx_layer, null, 0.0)
	var spell := hero.spells[2] as Spell
	var target_cell := Vector2i(3, 3)
	_relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view)
	_place_reference_goblin(Vector2i(3, 4))
	reference_goblin.current_hp = 1000
	hero.current_ap = hero.max_ap.get_int()
	var previous_cast_count := _observed_cast_count
	var previous_damage_count := _hero_spell_damage_events
	battle._on_request_cast_spell(spell, target_cell, false)
	var cast_timeout := Time.get_ticks_msec() + 7000
	while _observed_cast_count == previous_cast_count and Time.get_ticks_msec() < cast_timeout:
		await get_tree().process_frame
	if _observed_cast_count != previous_cast_count + 1:
		result.errors.append("Le cast réel n'a pas créé exactement une instance observable.")
	var fireball_ref: WeakRef = weakref(_captured_cast_vfx) \
		if is_instance_valid(_captured_cast_vfx) else null
	if force_interruption and is_instance_valid(_captured_cast_vfx):
		_captured_cast_vfx.set_process(false)
	var started_at := Time.get_ticks_msec()
	var sample_times: Array[float] = [0.0, 0.25, 0.5, 1.0, 2.0, 5.0]
	for sample_time: float in sample_times:
		while float(Time.get_ticks_msec() - started_at) / 1000.0 < sample_time:
			await get_tree().process_frame
		var instance: Node2D = fireball_ref.get_ref() as Node2D if fireball_ref != null else null
		result.samples.append(_fireball_layer_snapshot(
			"after_%.2f_s" % sample_time,
			vfx_layer,
			instance,
			sample_time
		))
		if is_equal_approx(sample_time, 5.0):
			await _capture("fireball_residue_before.png")
	result.cast_vfx_origin_delta_pixels = _cast_vfx_origin_delta
	result.damage_events = _hero_spell_damage_events - previous_damage_count
	var output_path := FIREBALL_INTERRUPTED_OUTPUT if force_interruption else FIREBALL_AUDIT_OUTPUT
	_write_json(output_path, result)
	print("FIREBALL_LIFECYCLE_AUDIT_RESULT=", JSON.stringify(result))
	elf_view.play_idle()
	if exit_when_done:
		await _wait_render_frames(2)
		get_tree().quit(0 if result.errors.is_empty() else 12)


func _fireball_layer_snapshot(
	label: String,
	vfx_layer: Node2D,
	instance,
	elapsed_seconds: float
) -> Dictionary:
	var layer_children: Array[Dictionary] = []
	for child in vfx_layer.get_children():
		layer_children.append({"name": child.name, "type": child.get_class()})
	var snapshot := {
		"label": label,
		"elapsed_seconds": elapsed_seconds,
		"vfx_layer_child_count": vfx_layer.get_child_count(),
		"vfx_layer_children": layer_children,
		"processed_tween_count": get_tree().get_processed_tweens().size(),
		"instance_present": is_instance_valid(instance) and instance.is_inside_tree(),
		"instance": {},
	}
	if not is_instance_valid(instance):
		return snapshot
	var child_states: Array[Dictionary] = []
	for child in instance.get_children():
		var state := {
			"name": child.name,
			"type": child.get_class(),
			"process_mode": child.process_mode,
		}
		if child is CanvasItem:
			state.visible = child.visible
			state.modulate = [child.modulate.r, child.modulate.g, child.modulate.b, child.modulate.a]
		if child is Node2D:
			state.scale = [child.scale.x, child.scale.y]
		elif child is Control:
			state.scale = [child.scale.x, child.scale.y]
		if child is GPUParticles2D:
			state.emitting = child.emitting
			state.one_shot = child.one_shot
			state.lifetime = child.lifetime
			state.finished_connection_count = child.get_signal_connection_list(&"finished").size()
		child_states.append(state)
	snapshot.instance = {
		"name": instance.name,
		"type": instance.get_class(),
		"global_position": [instance.global_position.x, instance.global_position.y],
		"visible": instance.visible,
		"process_mode": instance.process_mode,
		"is_processing": instance.is_processing(),
		"modulate": [instance.modulate.r, instance.modulate.g, instance.modulate.b, instance.modulate.a],
		"scale": [instance.scale.x, instance.scale.y],
		"inside_tree": instance.is_inside_tree(),
		"child_states": child_states,
	}
	return snapshot


func _run_fireball_lifecycle_validation(exit_when_done: bool) -> void:
	_freeze_cast_vfx_for_capture = false
	var vfx_layer := battle.get_node_or_null("VFXLayer") as Node2D
	var result := {
		"verdict": "FIREBALL_VFX_CLEANUP_FIXED",
		"initial_vfx_layer_children": [],
		"initial_vfx_layer_child_count": -1,
		"casts": [],
		"successive_instance_ids_are_distinct": false,
		"watchdog_interruption": {},
		"caster_death_interruption": {},
		"selection_unchanged": false,
		"y_sort_unchanged": false,
		"pivot_unchanged": false,
		"final_vfx_layer_child_count": -1,
		"errors": [],
	}
	if vfx_layer == null:
		result.errors.append("VFXLayer introuvable.")
		result.verdict = "FIREBALL_VFX_CLEANUP_NOT_FIXED"
		_write_json(FIREBALL_VALIDATION_OUTPUT, result)
		print("FIREBALL_LIFECYCLE_VALIDATION_RESULT=", JSON.stringify(result))
		if exit_when_done:
			get_tree().quit(13)
		return
	var initial_children: Array[Dictionary] = []
	for child in vfx_layer.get_children():
		initial_children.append({"name": child.name, "type": child.get_class()})
	result.initial_vfx_layer_children = initial_children
	result.initial_vfx_layer_child_count = vfx_layer.get_child_count()
	var y_sort_before: bool = battle._unit_view_parent.y_sort_enabled
	var pivot_before: Vector3 = elf_view.model_scale_multiplier
	battle._on_cell_clicked(hero.grid_pos)
	hero_view.set_active(true)
	var selection_before: bool = bool(hero_view.get("_is_active"))
	var spell := hero.spells[2] as Spell
	var target_cell := Vector2i(3, 3)
	_relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view)
	_place_reference_goblin(Vector2i(3, 4))
	var cast_results: Array[Dictionary] = []
	cast_results.append(await _perform_fireball_cast_probe(spell, target_cell, false))
	cast_results.append(await _perform_fireball_cast_probe(spell, target_cell, false))
	result.casts = cast_results
	var first_id := int(cast_results[0].get("instance_id", 0))
	var second_id := int(cast_results[1].get("instance_id", 0))
	result.successive_instance_ids_are_distinct = first_id > 0 and second_id > 0 and first_id != second_id
	if not result.successive_instance_ids_are_distinct:
		result.errors.append("Les deux casts successifs n'ont pas utilisé deux instances distinctes.")
	for cast_result: Dictionary in cast_results:
		if not bool(cast_result.get("origin_is_exact", false)):
			result.errors.append("Un cast ne part pas exactement de la main droite.")
		if not bool(cast_result.get("reached_target", false)):
			result.errors.append("Un projectile n'a pas rejoint sa cible.")
		if int(cast_result.get("damage_events", 0)) != 1:
			result.errors.append("Un cast n'a pas produit exactement un événement de dégâts.")
		if int(cast_result.get("vfx_layer_child_count_after", -1)) \
				!= int(result.initial_vfx_layer_child_count):
			result.errors.append("VFXLayer n'est pas revenu à son nombre initial après un cast.")
	await _capture("fireball_cleanup_after.png")
	var damage_before_watchdog := _hero_spell_damage_events
	var watchdog_instance := spell.vfx_scene.instantiate() as Node2D
	vfx_layer.add_child(watchdog_instance)
	watchdog_instance.call(
		"initialiser",
		hero_view.get_cast_effect_origin_global(),
		VFXManager._grid_cell_global(target_cell)
	)
	var watchdog_id := watchdog_instance.get_instance_id()
	var watchdog_ref: WeakRef = weakref(watchdog_instance)
	watchdog_instance.set_process(false)
	var watchdog_started := Time.get_ticks_msec()
	while is_instance_valid(watchdog_ref.get_ref()) \
			and Time.get_ticks_msec() - watchdog_started < 5000:
		await get_tree().process_frame
	var watchdog_seconds := float(Time.get_ticks_msec() - watchdog_started) / 1000.0
	result.watchdog_interruption = {
		"instance_id": watchdog_id,
		"freed": not is_instance_valid(watchdog_ref.get_ref()),
		"lifetime_seconds": watchdog_seconds,
		"damage_events": _hero_spell_damage_events - damage_before_watchdog,
		"vfx_layer_child_count_after": vfx_layer.get_child_count(),
	}
	if not bool(result.watchdog_interruption.freed):
		result.errors.append("Le watchdog local n'a pas libéré un projectile interrompu.")
	if int(result.watchdog_interruption.damage_events) != 0:
		result.errors.append("Le watchdog visuel a déclenché un événement de dégâts.")
	var death_cast: Dictionary = await _perform_fireball_cast_probe(spell, target_cell, true)
	result.caster_death_interruption = death_cast
	if not bool(death_cast.get("freed", false)):
		result.errors.append("Le VFX n'a pas été libéré après la mort du lanceur.")
	if int(death_cast.get("damage_events", 0)) != 1:
		result.errors.append("Le cast suivi de la mort n'a pas produit exactement un événement de dégâts.")
	result.selection_unchanged = selection_before and bool(hero_view.get("_is_active")) \
		if is_instance_valid(hero_view) else selection_before
	result.y_sort_unchanged = battle._unit_view_parent.y_sort_enabled == y_sort_before
	result.pivot_unchanged = elf_view.model_scale_multiplier.is_equal_approx(pivot_before) \
		if is_instance_valid(elf_view) else true
	result.final_vfx_layer_child_count = vfx_layer.get_child_count()
	if int(result.final_vfx_layer_child_count) != int(result.initial_vfx_layer_child_count):
		result.errors.append("VFXLayer ne revient pas à son nombre d'enfants initial.")
	if not result.y_sort_unchanged:
		result.errors.append("Le Y-sort a changé pendant la validation du VFX.")
	if not result.pivot_unchanged:
		result.errors.append("Le pivot de l'elfe a changé pendant la validation du VFX.")
	if not result.errors.is_empty():
		result.verdict = "FIREBALL_VFX_CLEANUP_NOT_FIXED"
	_write_json(FIREBALL_VALIDATION_OUTPUT, result)
	print("FIREBALL_LIFECYCLE_VALIDATION_RESULT=", JSON.stringify(result))
	if exit_when_done:
		await _wait_render_frames(2)
		get_tree().quit(0 if result.errors.is_empty() else 13)


func _perform_fireball_cast_probe(
	spell: Spell,
	target_cell: Vector2i,
	kill_caster_after_spawn: bool
) -> Dictionary:
	if hero.is_alive:
		_relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view)
		elf_view.play_idle()
		elf_view.set_facing(target_cell - hero.grid_pos)
	_place_reference_goblin(Vector2i(3, 4))
	reference_goblin.current_hp = 1000
	hero.current_ap = hero.max_ap.get_int()
	var previous_cast_count := _observed_cast_count
	var previous_damage_count := _hero_spell_damage_events
	_captured_cast_vfx = null
	_cast_vfx_origin_delta = -1.0
	battle._on_request_cast_spell(spell, target_cell, false)
	var cast_timeout := Time.get_ticks_msec() + 7000
	while _observed_cast_count == previous_cast_count and Time.get_ticks_msec() < cast_timeout:
		await get_tree().process_frame
	if _observed_cast_count != previous_cast_count + 1 or not is_instance_valid(_captured_cast_vfx):
		return {
			"instance_id": 0,
			"origin_delta_pixels": _cast_vfx_origin_delta,
			"origin_is_exact": false,
			"reached_target": false,
			"freed": false,
			"damage_events": _hero_spell_damage_events - previous_damage_count,
			"vfx_layer_child_count_after": -1,
			"error": "Instance non observée après le cast.",
		}
	var instance_id := _captured_cast_vfx.get_instance_id()
	var fireball_ref: WeakRef = weakref(_captured_cast_vfx)
	var target_global: Vector2 = VFXManager._grid_cell_global(target_cell)
	var min_target_distance := _captured_cast_vfx.global_position.distance_to(target_global)
	var arrival_seconds := -1.0
	var spawned_at := Time.get_ticks_msec()
	if kill_caster_after_spawn:
		hero.take_damage(
			hero.current_hp + 1000,
			reference_goblin,
			Spell.DamageType.PHYSICAL,
			Spell.Element.NONE
		)
	while is_instance_valid(fireball_ref.get_ref()) and Time.get_ticks_msec() - spawned_at < 5000:
		var instance := fireball_ref.get_ref() as Node2D
		if is_instance_valid(instance):
			min_target_distance = minf(
				min_target_distance,
				instance.global_position.distance_to(target_global)
			)
			if arrival_seconds < 0.0 and not instance.is_processing():
				arrival_seconds = float(Time.get_ticks_msec() - spawned_at) / 1000.0
		await get_tree().process_frame
	var lifetime_seconds := float(Time.get_ticks_msec() - spawned_at) / 1000.0
	if hero.is_alive:
		var idle_timeout := Time.get_ticks_msec() + 6000
		while elf_view.get_elf_visual().get_current_animation() != ElfVisual3D.ANIM_IDLE \
				and Time.get_ticks_msec() < idle_timeout:
			await get_tree().process_frame
	var vfx_layer := battle.get_node_or_null("VFXLayer") as Node2D
	return {
		"instance_id": instance_id,
		"origin_delta_pixels": _cast_vfx_origin_delta,
		"origin_is_exact": is_zero_approx(_cast_vfx_origin_delta),
		"minimum_target_distance_pixels": min_target_distance,
		"reached_target": min_target_distance < 8.0,
		"arrival_seconds": arrival_seconds,
		"lifetime_seconds": lifetime_seconds,
		"freed": not is_instance_valid(fireball_ref.get_ref()),
		"damage_events": _hero_spell_damage_events - previous_damage_count,
		"caster_killed_after_spawn": kill_caster_after_spawn,
		"caster_alive_after": hero.is_alive,
		"vfx_layer_child_count_after": vfx_layer.get_child_count() if vfx_layer != null else -1,
	}


func _on_damage_observed(_target, attacker, _amount: int, _category: int, _element: int, _is_crit: bool) -> void:
	if attacker == hero:
		_hero_spell_damage_events += 1


func _on_elf_animation_started(animation_name: StringName) -> void:
	if animation_name == ElfVisual3D.ANIM_HIT:
		_initial_hit_count += 1
	elif animation_name == ElfVisual3D.ANIM_DEATH:
		_death_started_count += 1


func _on_death_animation_finished_observed() -> void:
	_death_finished_observed = true


func _place_reference_goblin(cell: Vector2i) -> void:
	if reference_goblin == null:
		for unit in battle.units:
			if unit != null and unit.team != 0 and unit.unit_name == "Eclaireur gobelin":
				reference_goblin = unit
				break
	if reference_goblin == null:
		for unit in battle.units:
			if unit != null and unit.team != 0:
				reference_goblin = unit
				break
	if reference_goblin == null:
		return
	reference_goblin_view = battle._unit_views.get(reference_goblin) as Node2D
	_relocate_for_review(reference_goblin, cell, reference_goblin_view)


func _relocate_for_review(unit: Unit, cell: Vector2i, view: Node2D) -> bool:
	if unit == null or view == null or not battle.grid.is_valid(cell):
		return false
	var occupying = battle.grid.get_unit(cell)
	if occupying != null and occupying != unit:
		return false
	if not battle.grid.relocate_unit(unit, cell):
		return false
	view.position = battle.grid_cell_to_parent_local(cell, view.get_parent())
	if unit == hero and elf_view != null:
		elf_view.cancel_movement_feedback()
	return true


func _debug_move_existing_path(direction: Vector2i, use_run: bool, screenshot_name: String = "") -> bool:
	if not _relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view):
		_errors.append("Impossible de replacer le héros au centre de revue.")
		return false
	elf_view.set_debug_run_for_next_movement(use_run)
	var from_cell := hero.grid_pos
	var to_cell := from_cell + direction
	if not battle.grid.relocate_unit(hero, to_cell):
		_errors.append("Déplacement debug réel impossible vers %s." % to_cell)
		return false
	await battle._animate_move(hero, [from_cell, to_cell])
	if screenshot_name != "":
		await _capture(screenshot_name)
	await get_tree().create_timer(0.09).timeout
	var expected: Vector2 = battle.grid_cell_to_parent_local(to_cell, hero_view.get_parent())
	if hero_view.position.distance_to(expected) > 0.01:
		_errors.append("Fin de déplacement %s décalée de %.4f px." % [direction, hero_view.position.distance_to(expected)])
	elf_view.set_debug_run_for_next_movement(_debug_run_enabled)
	return true


func _run_automated_review(exit_when_done: bool) -> void:
	var absolute_screenshot_dir := ProjectSettings.globalize_path(SCREENSHOT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_screenshot_dir)
	_warnings.append("Death conserve le déplacement interne de Hips de l'Action source, mesuré à environ 1,312 m.")
	_warnings.append("Le déplacement interne de Hips fait déborder visuellement la pose de mort sur la case adjacente, sans déplacer les racines 2D.")
	_validate_structure()
	await get_tree().create_timer(0.5).timeout
	_performance_warmup_frames = 0
	_performance_sampling = true
	elf_view.play_idle()
	await _review_orientation_pivot()
	await _review_selection()
	await _review_moving_capture()

	await _debug_move_existing_path(Vector2i.RIGHT, false, "salle1_elf_walk_pos_x.png")
	await _debug_move_existing_path(Vector2i.LEFT, false, "salle1_elf_walk_neg_x.png")
	await _debug_move_existing_path(Vector2i.DOWN, false, "salle1_elf_walk_pos_y.png")
	await _debug_move_existing_path(Vector2i.UP, false, "salle1_elf_walk_neg_y.png")
	await _debug_move_existing_path(Vector2i.RIGHT, true)

	await _review_real_cast()
	await _review_real_hit()
	await _review_y_sort()
	var saved_viewport_size := elf_view.viewport_size
	var saved_camera_size := elf_view.camera_orthographic_size
	var saved_character_scale := elf_view.character_scale
	var saved_model_scale := elf_view.model_scale_multiplier
	var saved_foot_pixel := elf_view.get_projected_foot_pixel()
	var saved_render_position := elf_view.render_sprite.position
	var saved_render_z := elf_view.render_sprite.z_index
	var saved_hero_z := hero_view.z_index
	var saved_facing_yaws := {
		"pos_x": elf_view.facing_yaw_pos_x,
		"neg_x": elf_view.facing_yaw_neg_x,
		"pos_y": elf_view.facing_yaw_pos_y,
		"neg_y": elf_view.facing_yaw_neg_y,
	}
	var saved_walk_multiplier := elf_view.walk_animation_speed_multiplier
	var saved_run_multiplier := elf_view.run_animation_speed_multiplier
	await _review_real_death()
	_performance_sampling = false

	var average_fps := 0.0
	var minimum_fps := INF
	for sample in _fps_samples:
		average_fps += sample
		minimum_fps = minf(minimum_fps, sample)
	if not _fps_samples.is_empty():
		average_fps /= _fps_samples.size()
	else:
		minimum_fps = 0.0
	var verdict := "ELF_FIRST_PLAYABLE_INTEGRATION_INCOMPLETE" if not _errors.is_empty() else (
		"ELF_FIRST_PLAYABLE_INTEGRATION_COMPLETE_WITH_WARNINGS" if not _warnings.is_empty() else "ELF_FIRST_PLAYABLE_INTEGRATION_COMPLETE"
	)
	var result := {
		"verdict": verdict,
		"errors": _errors,
		"warnings": _warnings,
		"screenshots": _screenshots,
		"root_checks": _root_checks,
		"metrics": {
			"viewport_size": [saved_viewport_size.x, saved_viewport_size.y],
			"camera_orthographic_size": saved_camera_size,
			"character_scale": saved_character_scale,
			"model_scale_multiplier": [saved_model_scale.x, saved_model_scale.y, saved_model_scale.z],
			"foot_pixel": _vector2_array(saved_foot_pixel),
			"render_sprite_position": _vector2_array(saved_render_position),
			"facing_yaws": saved_facing_yaws,
			"walk_animation_speed_multiplier": saved_walk_multiplier,
			"run_animation_speed_multiplier": saved_run_multiplier,
			"average_fps": average_fps,
			"minimum_fps": minimum_fps,
			"fps_samples": _fps_samples.size(),
			"observed_cast_count": _observed_cast_count,
			"cast_release_msec": _cast_release_msec,
			"spell_cast_msec": _spell_cast_msec,
			"cast_vfx_origin_delta_pixels": _cast_vfx_origin_delta,
			"hero_spell_damage_events": _hero_spell_damage_events,
			"hit_animation_count": _initial_hit_count,
			"death_animation_count": _death_started_count,
			"y_sort_enabled": battle._unit_view_parent.y_sort_enabled,
			"hero_view_z_index": saved_hero_z,
			"render_sprite_z_index": saved_render_z,
			"hero_alive_after_real_death_test": hero.is_alive,
			"hero_grid_pos_after_real_death_test": [hero.grid_pos.x, hero.grid_pos.y],
		}
	}
	var output := FileAccess.open(REVIEW_OUTPUT, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(result, "  "))
		output.close()
	print("ELF_FIRST_PLAYABLE_INTEGRATION_RESULT=", JSON.stringify(result))
	_auto_review_running = false
	if exit_when_done:
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit(0 if _errors.is_empty() else 8)


func _review_selection() -> void:
	battle._on_cell_clicked(hero.grid_pos)
	if battle.inspect_panel == null or battle.inspect_panel.get("_displayed_unit") != hero:
		_errors.append("Le clic sur la cellule de l'elfe n'a pas conserve ses informations accessibles.")
	if not elf_view.character_viewport.gui_disable_input:
		_errors.append("Le SubViewport 3D peut encore capturer les entrees souris.")
	hero_view.set_active(true)
	await _capture("final_elf_selected.png")
	await _check_character_not_clipped("Idle")


func _review_orientation_pivot() -> void:
	var initial_root := elf_view.global_position
	var initial_render_position := elf_view.render_sprite.position
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		elf_view.set_facing(direction)
		await get_tree().process_frame
		if elf_view.global_position.distance_to(initial_root) > 0.001 \
				or elf_view.render_sprite.position.distance_to(initial_render_position) > 0.001:
			_errors.append("Le pivot 2D varie lors de l'orientation %s." % direction)
	elf_view.set_facing(Vector2i.DOWN)


func _review_moving_capture() -> void:
	if not _relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view):
		_errors.append("Impossible de placer l'elfe pour la capture de mouvement.")
		return
	elf_view.set_debug_run_for_next_movement(false)
	var from_cell := hero.grid_pos
	var to_cell := from_cell + Vector2i.RIGHT
	if not battle.grid.relocate_unit(hero, to_cell):
		_errors.append("Impossible de demarrer le deplacement reel de la capture finale.")
		return
	battle._animate_move(hero, [from_cell, to_cell])
	await get_tree().create_timer(0.075).timeout
	if elf_view.get_elf_visual().get_current_animation() != ElfVisual3D.ANIM_WALK:
		_errors.append("Walk n'est pas active pendant le deplacement reel.")
	await _capture("final_elf_moving.png")
	await _check_character_not_clipped("Walk")
	await get_tree().create_timer(0.16).timeout
	var expected: Vector2 = battle.grid_cell_to_parent_local(to_cell, hero_view.get_parent())
	if hero_view.position.distance_to(expected) > 0.01:
		_errors.append("La capture de mouvement ne termine pas au centre de la cellule.")


func _validate_structure() -> void:
	if battle._unit_view_parent == null or battle._unit_view_parent.name != "YSortedWorld":
		_errors.append("Le parent direct des UnitView n'est pas YSortedWorld.")
	elif not battle._unit_view_parent.y_sort_enabled:
		_errors.append("YSortedWorld n'a pas y_sort_enabled.")
	if hero_view.get_parent() != battle._unit_view_parent:
		_errors.append("Le héros logique n'est pas enfant direct de YSortedWorld.")
	if elf_view.get_parent() != hero_view or elf_view.position != Vector2.ZERO:
		_errors.append("ElfIsoUnitView n'est pas un visuel local à Vector2.ZERO du héros.")
	if elf_view.render_sprite.z_index != 0 or hero_view.z_index != 0:
		_errors.append("Un z_index fixe est présent sur le héros ou son rendu.")
	if not is_instance_valid(temporary_visual):
		_errors.append("Le visuel temporaire du héros n'a pas été conservé.")
	elif temporary_visual.visible:
		_errors.append("Le placeholder historique reste visible avec l'elfe.")
	if hero.visual_scene == null or not hero_view.has_optional_visual():
		_errors.append("Le visuel elfe ne provient pas de la configuration PackedScene de l'unité.")
	if absf(elf_view.character_scale - 1.10) > 0.0001 \
			or elf_view.model_scale_multiplier.distance_to(Vector3.ONE * 1.10) > 0.0001:
		_errors.append("L'échelle de production uniforme de l'elfe n'est pas 1,10.")
	for unit in battle.units:
		if unit == null or unit.team == 0:
			continue
		var enemy_view = battle._unit_views.get(unit)
		if is_instance_valid(enemy_view) and enemy_view.has_method("has_optional_visual") \
				and enemy_view.has_optional_visual():
			_errors.append("Une unité ennemie a reçu un visuel optionnel inattendu.")
	if elf_view.get_logical_foot_position() != Vector2.ZERO:
		_errors.append("Le pivot logique des pieds n'est pas Vector2.ZERO.")


func _review_real_cast() -> void:
	if hero.spells.size() < 3:
		_errors.append("L'Elfe de test ne possède pas le sort feu attendu.")
		return
	var spell := hero.spells[2] as Spell
	var target_cell := Vector2i(3, 3)
	_relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view)
	_place_reference_goblin(Vector2i(3, 4))
	reference_goblin.current_hp = 1000
	hero.current_ap = hero.max_ap.get_int()
	var before := _root_snapshot("Cast_before")
	var previous_cast_count := _observed_cast_count
	var previous_damage_count := _hero_spell_damage_events
	var previous_enemy_hp := reference_goblin.current_hp
	battle._on_request_cast_spell(spell, target_cell, false)
	var timeout_at := Time.get_ticks_msec() + 5000
	while _observed_cast_count == previous_cast_count and Time.get_ticks_msec() < timeout_at:
		await get_tree().process_frame
	await _capture("final_elf_cast_origin.png")
	await _check_character_not_clipped("Cast")
	if is_instance_valid(_captured_cast_vfx):
		_captured_cast_vfx.set_process(true)
	while elf_view.get_elf_visual().get_current_animation() != ElfVisual3D.ANIM_IDLE \
			and Time.get_ticks_msec() < timeout_at:
		await get_tree().process_frame
	if _observed_cast_count != previous_cast_count + 1:
		_errors.append("Le vrai sort n'a pas été observé exactement une fois.")
	if _cast_release_msec < 0 or _spell_cast_msec < _cast_release_msec:
		_errors.append("Le sort/VFX a été déclenché avant cast_release_reached.")
	if _cast_vfx_origin_delta < 0.0 or _cast_vfx_origin_delta > 0.5:
		_errors.append("Le VFX réel n'est pas parti de la main droite (écart %.3f px)." % _cast_vfx_origin_delta)
	if _hero_spell_damage_events != previous_damage_count + 1:
		_errors.append("Le sort réel n'a pas produit exactement un événement de dégâts.")
	if reference_goblin.current_hp >= previous_enemy_hp:
		_errors.append("Le système existant n'a appliqué aucun dégât à la cible du sort.")
	if elf_view.get_facing_direction() != Vector2i.LEFT:
		_errors.append("L'elfe ne s'est pas orientée vers la cellule ciblée avant Cast.")
	_record_root_check("Cast", before)


func _review_real_hit() -> void:
	_relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view)
	var before := _root_snapshot("Hit_before")
	var hit_count_before := _initial_hit_count
	hero.take_damage(1, reference_goblin, Spell.DamageType.PHYSICAL, Spell.Element.NONE)
	await get_tree().create_timer(0.65).timeout
	await _capture("salle1_elf_hit.png")
	await _check_character_not_clipped("Hit")
	var timeout_at := Time.get_ticks_msec() + 4000
	while elf_view.get_elf_visual().get_current_animation() != ElfVisual3D.ANIM_IDLE and Time.get_ticks_msec() < timeout_at:
		await get_tree().process_frame
	if _initial_hit_count != hit_count_before + 1:
		_errors.append("Un dégât réel n'a pas lancé exactement une animation Hit.")
	_record_root_check("Hit", before)


func _review_y_sort() -> void:
	_relocate_for_review(hero, Vector2i(4, 4), hero_view)
	_place_reference_goblin(Vector2i(5, 4))
	elf_view.set_facing(reference_goblin.grid_pos - hero.grid_pos)
	elf_view.play_idle()
	await get_tree().process_frame
	if hero_view.position.y >= reference_goblin_view.position.y:
		_errors.append("Le cas 'elfe derrière' n'a pas une position Y inférieure au gobelin.")
	await _capture("final_elf_y_sort.png")

	_relocate_for_review(hero, Vector2i(6, 4), hero_view)
	elf_view.set_facing(reference_goblin.grid_pos - hero.grid_pos)
	elf_view.play_idle()
	await get_tree().process_frame
	if hero_view.position.y <= reference_goblin_view.position.y:
		_errors.append("Le cas 'elfe devant' n'a pas une position Y supérieure au gobelin.")
	await _capture("salle1_elf_in_front_of_goblin.png")


func _review_real_death() -> void:
	_relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view)
	elf_view.play_idle()
	await get_tree().process_frame
	var before := _root_snapshot("Death_before")
	var death_count_before := _death_started_count
	var previous_cell := hero.grid_pos
	_death_finished_observed = false
	_death_visual_present_until_finished = true
	_death_max_unit_delta = 0.0
	_death_max_elf_delta = 0.0
	hero.take_damage(hero.current_hp + 1000, reference_goblin, Spell.DamageType.PHYSICAL, Spell.Element.NONE)
	var timeout_at := Time.get_ticks_msec() + 6000
	var death_started_at := Time.get_ticks_msec()
	var capture_done := false
	while not _death_finished_observed and Time.get_ticks_msec() < timeout_at:
		if not is_instance_valid(hero_view) \
				or not is_instance_valid(elf_view) \
				or not elf_view.is_inside_tree() \
				or not elf_view.is_visible_in_tree():
			_death_visual_present_until_finished = false
			break
		var before_unit_global := Vector2(float(before["global_position"][0]), float(before["global_position"][1]))
		var before_elf_global := Vector2(float(before["elf_global_position"][0]), float(before["elf_global_position"][1]))
		_death_max_unit_delta = maxf(_death_max_unit_delta, hero_view.global_position.distance_to(before_unit_global))
		_death_max_elf_delta = maxf(_death_max_elf_delta, elf_view.global_position.distance_to(before_elf_global))
		if not capture_done and Time.get_ticks_msec() - death_started_at >= 2400:
			await _capture("final_elf_death.png")
			await _check_character_not_clipped("Death")
			capture_done = true
		await get_tree().process_frame
	if not capture_done and is_instance_valid(elf_view) and elf_view.is_inside_tree():
		await _capture("final_elf_death.png")
		await _check_character_not_clipped("Death")
	if _death_started_count != death_count_before + 1:
		_errors.append("La mort réelle n'a pas lancé exactement une animation Death.")
	if not _death_finished_observed:
		_errors.append("Death n'a pas atteint death_animation_finished dans le délai de validation.")
	if not _death_visual_present_until_finished:
		_errors.append("Le visuel de l'elfe a disparu avant death_animation_finished.")
	if is_instance_valid(elf_view) and elf_view.get_elf_visual().get_current_animation() == ElfVisual3D.ANIM_IDLE:
		_errors.append("Death est revenue à Idle après une mort réelle.")
	_record_death_contract(before, previous_cell)


func _root_snapshot(label: String) -> Dictionary:
	return {
		"label": label,
		"global_position": _vector2_array(hero_view.global_position),
		"elf_global_position": _vector2_array(elf_view.global_position),
		"grid_pos": [hero.grid_pos.x, hero.grid_pos.y],
		"expected_parent_position": _vector2_array(battle.grid_cell_to_parent_local(hero.grid_pos, hero_view.get_parent())),
	}


func _record_death_contract(before: Dictionary, previous_cell: Vector2i) -> void:
	var before_unit_global := Vector2(float(before["global_position"][0]), float(before["global_position"][1]))
	var before_elf_global := Vector2(float(before["elf_global_position"][0]), float(before["elf_global_position"][1]))
	var unit_view_present := is_instance_valid(hero_view) and hero_view.is_inside_tree()
	var elf_view_present := is_instance_valid(elf_view) and elf_view.is_inside_tree()
	var after_unit_global := hero_view.global_position if unit_view_present else before_unit_global
	var after_elf_global := elf_view.global_position if elf_view_present else before_elf_global
	var unit_view_delta := maxf(_death_max_unit_delta, after_unit_global.distance_to(before_unit_global) if unit_view_present else 0.0)
	var elf_view_delta := maxf(_death_max_elf_delta, after_elf_global.distance_to(before_elf_global) if elf_view_present else 0.0)
	var previous_cell_empty: bool = battle.grid.get_unit(previous_cell) == null
	var grid_position_invalid: bool = hero.grid_pos == Vector2i(-1, -1) or not battle.grid.is_valid(hero.grid_pos)
	var check := {
		"label": "Death",
		"before_cell": [previous_cell.x, previous_cell.y],
		"after_cell": [hero.grid_pos.x, hero.grid_pos.y],
		"previous_cell_empty": previous_cell_empty,
		"grid_position_invalid": grid_position_invalid,
		"before_unit_view_global": before["global_position"],
		"after_unit_view_global": _vector2_array(after_unit_global),
		"unit_view_delta_pixels": unit_view_delta,
		"before_elf_view_global": before["elf_global_position"],
		"after_elf_view_global": _vector2_array(after_elf_global),
		"elf_view_delta_pixels": elf_view_delta,
		"unit_view_present_after_finished": unit_view_present,
		"elf_view_present_after_finished": elf_view_present,
		"visuals_present_until_finished": _death_visual_present_until_finished,
		"death_animation_finished": _death_finished_observed,
	}
	_root_checks.append(check)
	if not previous_cell_empty:
		_errors.append("L'ancienne cellule %s reste occupée après grid.clear_unit()." % previous_cell)
	if not grid_position_invalid:
		_errors.append("La cellule logique après la mort devrait être invalide, valeur observée : %s." % hero.grid_pos)
	if not _death_visual_present_until_finished or unit_view_delta > 0.01:
		_errors.append("Death a déplacé ou supprimé UnitView avant la fin (delta %.4f px)." % unit_view_delta)
	if not _death_visual_present_until_finished or elf_view_delta > 0.01:
		_errors.append("Death a déplacé ou supprimé ElfIsoUnitView avant la fin (delta %.4f px)." % elf_view_delta)


func _record_root_check(label: String, before: Dictionary) -> void:
	var after_global := hero_view.global_position
	var before_global := Vector2(float(before["global_position"][0]), float(before["global_position"][1]))
	var before_cell := Vector2i(int(before["grid_pos"][0]), int(before["grid_pos"][1]))
	var position_delta := after_global.distance_to(before_global)
	var cell_stable := hero.grid_pos == before_cell
	var expected_delta := -1.0
	if battle.grid.is_valid(hero.grid_pos):
		var expected: Vector2 = battle.grid_cell_to_parent_local(hero.grid_pos, hero_view.get_parent())
		expected_delta = hero_view.position.distance_to(expected)
	var check := {
		"label": label,
		"before_global": before["global_position"],
		"after_global": _vector2_array(after_global),
		"position_delta_pixels": position_delta,
		"before_cell": before["grid_pos"],
		"after_cell": [hero.grid_pos.x, hero.grid_pos.y],
		"cell_stable": cell_stable,
		"expected_position_delta_pixels": expected_delta,
	}
	_root_checks.append(check)
	if position_delta > 0.01:
		_errors.append("%s a déplacé la racine logique de %.4f px." % [label, position_delta])
	if not cell_stable:
		_errors.append("%s a changé la cellule logique de %s vers %s." % [label, before_cell, hero.grid_pos])
	if expected_delta > 0.01:
		_errors.append("%s laisse la racine à %.4f px de la projection IsoGridView." % [label, expected_delta])


func _run_sharpness_audit(exit_when_done: bool) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
	await get_tree().create_timer(0.6).timeout
	elf_view.play_idle()
	await _wait_render_frames(4)
	var original := _quality_runtime_snapshot()
	var before := await _capture_quality_variant(
		"before",
		"%s/sharpness_before_viewport.png" % SCREENSHOT_DIR,
		"%s/sharpness_before_composite.png" % SCREENSHOT_DIR,
		"%s/sharpness_before_composite_crop.png" % SCREENSHOT_DIR,
		"%s/sharpness_before_viewport_crop.png" % SCREENSHOT_DIR
	)
	before["performance"] = await _measure_quality_fps()
	var baseline_source_height := float(before["source_bbox"][3])
	var baseline_ratio := float(before["effective_character_height_ratio"])
	var target_ratio := 0.80
	var target_camera_size := elf_view.camera_orthographic_size * baseline_ratio / target_ratio
	var variants: Array[Dictionary] = []
	var configurations := [
		{"tag": "512_linear", "size": 512, "filter": CanvasItem.TEXTURE_FILTER_LINEAR},
		{"tag": "512_nearest", "size": 512, "filter": CanvasItem.TEXTURE_FILTER_NEAREST},
		{"tag": "768_linear", "size": 768, "filter": CanvasItem.TEXTURE_FILTER_LINEAR},
	]
	for configuration in configurations:
		var resolution: int = configuration["size"]
		var display_scale := baseline_source_height / (target_ratio * float(resolution))
		await _apply_runtime_quality(
			Vector2i(resolution, resolution),
			target_camera_size,
			configuration["filter"],
			display_scale
		)
		elf_view.play_idle()
		await _wait_render_frames(3)
		var tag: String = configuration["tag"]
		var captured := await _capture_quality_variant(
			tag,
			"%s/sharpness_%s_viewport.png" % [SCREENSHOT_DIR, tag],
			"%s/sharpness_%s_composite.png" % [SCREENSHOT_DIR, tag],
			"%s/sharpness_%s_composite_crop.png" % [SCREENSHOT_DIR, tag],
			"%s/sharpness_%s_viewport_crop.png" % [SCREENSHOT_DIR, tag]
		)
		captured["performance"] = await _measure_quality_fps()
		variants.append(captured)
	var safe_target_ratio := 0.76
	var safe_camera_size := float(original["camera_size"]) * baseline_ratio / safe_target_ratio
	var production_display_scale := baseline_source_height / (safe_target_ratio * 512.0)
	await _apply_runtime_quality(
		Vector2i(640, 512),
		safe_camera_size,
		CanvasItem.TEXTURE_FILTER_LINEAR,
		production_display_scale
	)
	elf_view.play_idle()
	await _wait_render_frames(3)
	var safe_captured := await _capture_quality_variant(
		"640x512_linear_safe",
		"%s/sharpness_640x512_linear_viewport.png" % SCREENSHOT_DIR,
		"%s/sharpness_640x512_linear_composite.png" % SCREENSHOT_DIR,
		"%s/sharpness_640x512_linear_composite_crop.png" % SCREENSHOT_DIR,
		"%s/sharpness_640x512_linear_viewport_crop.png" % SCREENSHOT_DIR
	)
	safe_captured["performance"] = await _measure_quality_fps()
	variants.append(safe_captured)
	await _apply_runtime_quality(
		Vector2i(768, 512),
		safe_camera_size,
		CanvasItem.TEXTURE_FILTER_LINEAR,
		production_display_scale
	)
	elf_view.camera.look_at(Vector3(0.0, 0.87, 0.0), Vector3.UP)
	elf_view.call("_realign_foot_deferred")
	await _wait_render_frames(4)
	elf_view.render_sprite.position = (
		-elf_view.get_projected_foot_pixel() * production_display_scale
		+ elf_view.render_offset_adjustment
	)
	var wide_captured := await _capture_quality_variant(
		"768x512_linear_wide",
		"%s/sharpness_768x512_linear_viewport.png" % SCREENSHOT_DIR,
		"%s/sharpness_768x512_linear_composite.png" % SCREENSHOT_DIR,
		"%s/sharpness_768x512_linear_composite_crop.png" % SCREENSHOT_DIR,
		"%s/sharpness_768x512_linear_viewport_crop.png" % SCREENSHOT_DIR
	)
	wide_captured["performance"] = await _measure_quality_fps()
	variants.append(wide_captured)
	var motion_bounds := await _sample_sharpness_animation_bounds()
	await _restore_runtime_quality(original)
	var result := {
		"before": before,
		"target_height_ratio": target_ratio,
		"computed_camera_orthographic_size": target_camera_size,
		"safe_target_height_ratio": safe_target_ratio,
		"computed_safe_camera_orthographic_size": safe_camera_size,
		"computed_render_display_scale_640x512": production_display_scale,
		"wide_viewport_size": [768, 512],
		"wide_camera_look_at_height": 0.87,
		"variants": variants,
		"motion_bounds_768x512_linear": motion_bounds,
		"errors": _errors,
	}
	_write_json(SHARPNESS_AUDIT_OUTPUT, result)
	print("ELF_SHARPNESS_AUDIT_RESULT=", JSON.stringify(result))
	if exit_when_done:
		await _wait_render_frames(2)
		get_tree().quit(0 if _errors.is_empty() else 9)


func _run_sharpness_final(exit_when_done: bool) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
	await get_tree().create_timer(0.7).timeout
	_validate_structure()
	elf_view.play_idle()
	await _wait_render_frames(4)
	var idle_data := await _capture_quality_variant(
		"final_idle",
		"%s/sharpness_final_idle_viewport.png" % SCREENSHOT_DIR,
		"%s/elf_sharpness_final_idle.png" % SCREENSHOT_DIR,
		"%s/sharpness_final_idle_crop.png" % SCREENSHOT_DIR,
		"%s/sharpness_final_idle_viewport_crop.png" % SCREENSHOT_DIR
	)
	var motion_bounds := await _sample_sharpness_animation_bounds()
	for animation_name in motion_bounds:
		if motion_bounds[animation_name].get("clipped", false):
			_errors.append("%s touche encore le bord du SubViewport final." % animation_name)
	await _review_selection()
	await _capture_sharpness_final_walk()
	await _debug_move_existing_path(Vector2i.LEFT, false)
	await _debug_move_existing_path(Vector2i.DOWN, false)
	await _debug_move_existing_path(Vector2i.UP, false)
	await _capture_sharpness_final_cast()
	await _review_real_hit()
	await _review_y_sort()
	var performance := await _measure_quality_fps()
	var comparison_path := await _build_sharpness_comparison_board()
	var result := {
		"verdict": "ELF_SHARPNESS_IMPROVED_WITH_LIMITS" if not _errors.is_empty() else "ELF_SHARPNESS_FIXED",
		"errors": _errors,
		"warnings": _warnings,
		"pipeline": idle_data,
		"motion_bounds": motion_bounds,
		"performance": performance,
		"cast_vfx_origin_delta_pixels": _cast_vfx_origin_delta,
		"selection_displayed_unit": battle.inspect_panel.get("_displayed_unit") == hero,
		"y_sort_enabled": battle._unit_view_parent.y_sort_enabled,
		"comparison_board": comparison_path,
	}
	_write_json(SHARPNESS_FINAL_OUTPUT, result)
	print("ELF_SHARPNESS_FINAL_RESULT=", JSON.stringify(result))
	if exit_when_done:
		await _wait_render_frames(2)
		get_tree().quit(0 if _errors.is_empty() else 10)


func _capture_sharpness_final_walk() -> void:
	if not _relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view):
		_errors.append("Impossible de placer l'elfe pour la validation Walk nette.")
		return
	elf_view.set_debug_run_for_next_movement(false)
	var from_cell := hero.grid_pos
	var to_cell := from_cell + Vector2i.RIGHT
	if not battle.grid.relocate_unit(hero, to_cell):
		_errors.append("Impossible de démarrer Walk pour la capture de netteté.")
		return
	battle._animate_move(hero, [from_cell, to_cell])
	await get_tree().create_timer(0.075).timeout
	if elf_view.get_elf_visual().get_current_animation() != ElfVisual3D.ANIM_WALK:
		_errors.append("Walk n'est pas active pendant la capture de netteté.")
	await _capture("elf_sharpness_final_walk.png")
	await _save_current_composite_crop("%s/sharpness_final_walk_crop.png" % SCREENSHOT_DIR)
	await _check_character_not_clipped("Walk final")
	await get_tree().create_timer(0.18).timeout
	var expected: Vector2 = battle.grid_cell_to_parent_local(to_cell, hero_view.get_parent())
	if hero_view.position.distance_to(expected) > 0.01:
		_errors.append("Walk final ne termine pas au centre de la cellule.")


func _capture_sharpness_final_cast() -> void:
	if hero.spells.size() < 3:
		_errors.append("L'Elfe ne possède pas le sort feu de validation.")
		return
	var spell := hero.spells[2] as Spell
	var target_cell := Vector2i(3, 3)
	_relocate_for_review(hero, REVIEW_CENTER_CELL, hero_view)
	_place_reference_goblin(Vector2i(3, 4))
	reference_goblin.current_hp = 1000
	hero.current_ap = hero.max_ap.get_int()
	var before := _root_snapshot("Sharpness_Cast_before")
	var previous_cast_count := _observed_cast_count
	var previous_damage_count := _hero_spell_damage_events
	battle._on_request_cast_spell(spell, target_cell, false)
	await get_tree().create_timer(0.55).timeout
	await _capture("elf_sharpness_final_cast.png")
	await _check_character_not_clipped("Cast final")
	var timeout_at := Time.get_ticks_msec() + 5000
	while _observed_cast_count == previous_cast_count and Time.get_ticks_msec() < timeout_at:
		await get_tree().process_frame
	if is_instance_valid(_captured_cast_vfx):
		_captured_cast_vfx.set_process(true)
	if _observed_cast_count != previous_cast_count + 1:
		_errors.append("Le Cast final n'a pas été observé exactement une fois.")
	if _hero_spell_damage_events != previous_damage_count + 1:
		_errors.append("Le Cast final n'a pas produit exactement un événement de dégâts.")
	if _cast_vfx_origin_delta < 0.0 or _cast_vfx_origin_delta > 0.5:
		_errors.append("Le VFX final ne part plus de la main droite (%.3f px)." % _cast_vfx_origin_delta)
	while elf_view.get_elf_visual().get_current_animation() != ElfVisual3D.ANIM_IDLE \
			and Time.get_ticks_msec() < timeout_at:
		await get_tree().process_frame
	_record_root_check("Sharpness Cast", before)


func _save_current_composite_crop(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var crop := image.get_region(_fixed_character_crop_rect(image.get_size()))
	crop.save_png(ProjectSettings.globalize_path(path))


func _build_sharpness_comparison_board() -> String:
	var entries := [
		{"label": "BEFORE", "path": "%s/sharpness_before_composite_crop.png" % SCREENSHOT_DIR},
		{"label": "512 CADRE + LINEAR", "path": "%s/sharpness_512_linear_composite_crop.png" % SCREENSHOT_DIR},
		{"label": "512 CADRE + NEAREST", "path": "%s/sharpness_512_nearest_composite_crop.png" % SCREENSHOT_DIR},
		{"label": "768 CADRE + LINEAR", "path": "%s/sharpness_768_linear_composite_crop.png" % SCREENSHOT_DIR},
		{"label": "RETENU 768x512 + LINEAR - WALK", "path": "%s/sharpness_final_walk_crop.png" % SCREENSHOT_DIR},
	]
	var cell_size := Vector2i(260, 230)
	var header_height := 42
	var board_viewport := SubViewport.new()
	board_viewport.size = Vector2i(cell_size.x * entries.size(), cell_size.y + header_height)
	board_viewport.transparent_bg = false
	board_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(board_viewport)
	var background := ColorRect.new()
	background.size = Vector2(board_viewport.size)
	background.color = Color(0.025, 0.03, 0.04, 1.0)
	board_viewport.add_child(background)
	for index in range(entries.size()):
		var source := Image.load_from_file(ProjectSettings.globalize_path(entries[index]["path"]))
		if source == null or source.is_empty():
			_errors.append("Planche : image absente %s." % entries[index]["path"])
			continue
		var x := index * cell_size.x
		var label := Label.new()
		label.position = Vector2(x + 8, 8)
		label.size = Vector2(cell_size.x - 16, 28)
		label.text = entries[index]["label"]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color.WHITE)
		board_viewport.add_child(label)
		var texture_rect := TextureRect.new()
		texture_rect.position = Vector2(x, header_height)
		texture_rect.size = Vector2(cell_size)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.texture = ImageTexture.create_from_image(source)
		board_viewport.add_child(texture_rect)
	await _wait_render_frames(4)
	var result_path := "%s/elf_sharpness_comparison.png" % SCREENSHOT_DIR
	var board_image := board_viewport.get_texture().get_image()
	var save_result := board_image.save_png(ProjectSettings.globalize_path(result_path))
	board_viewport.queue_free()
	if save_result != OK:
		_errors.append("Impossible d'enregistrer la planche de netteté (code %d)." % save_result)
		return ""
	return result_path


func _quality_runtime_snapshot() -> Dictionary:
	return {
		"viewport_size": elf_view.viewport_size,
		"camera_size": elf_view.camera_orthographic_size,
		"render_filter": elf_view.render_sprite.texture_filter,
		"render_scale": elf_view.render_sprite.scale,
		"render_position": elf_view.render_sprite.position,
		"scaling_3d_scale": elf_view.character_viewport.scaling_3d_scale,
		"scaling_3d_mode": elf_view.character_viewport.scaling_3d_mode,
		"use_taa": elf_view.character_viewport.use_taa,
		"screen_space_aa": elf_view.character_viewport.screen_space_aa,
		"msaa_3d": elf_view.character_viewport.msaa_3d,
	}


func _sample_sharpness_animation_bounds() -> Dictionary:
	var visual := elf_view.get_elf_visual() as ElfVisual3D
	var player := visual.get_animation_player()
	var result := {}
	var animations := [
		{"label": "Idle", "name": ElfVisual3D.ANIM_IDLE},
		{"label": "Walk", "name": ElfVisual3D.ANIM_WALK},
		{"label": "Cast", "name": ElfVisual3D.ANIM_CAST_FULL},
		{"label": "Hit", "name": ElfVisual3D.ANIM_HIT},
		{"label": "Death", "name": ElfVisual3D.ANIM_DEATH},
	]
	for entry in animations:
		var animation_name: StringName = entry["name"]
		var animation := player.get_animation(animation_name)
		if animation == null:
			result[entry["label"]] = {"error": "animation absente"}
			continue
		player.play(animation_name, 0.0, 1.0)
		await _wait_render_frames(2)
		var union := Rect2i()
		var first := true
		for normalized_time in [0.0, 0.2, 0.4, 0.6, 0.8, 0.98]:
			player.seek(animation.length * normalized_time, true)
			await _wait_render_frames(2)
			var image := elf_view.character_viewport.get_texture().get_image()
			var bounds := _alpha_bounds(image)
			if first:
				union = bounds
				first = false
			else:
				union = union.merge(bounds)
			if absf(normalized_time - 0.6) < 0.001:
				image.save_png(ProjectSettings.globalize_path(
					"%s/sharpness_motion_%s_viewport.png" % [SCREENSHOT_DIR, String(entry["label"]).to_lower()]
				))
		var margins := [
			union.position.x,
			union.position.y,
			elf_view.character_viewport.size.x - union.end.x,
			elf_view.character_viewport.size.y - union.end.y,
		]
		result[entry["label"]] = {
			"union_bbox": [union.position.x, union.position.y, union.size.x, union.size.y],
			"margins_left_top_right_bottom": margins,
			"clipped": margins.min() <= 2,
		}
	player.stop()
	visual.play_idle(0.0)
	await _wait_render_frames(2)
	return result


func _restore_runtime_quality(snapshot: Dictionary) -> void:
	elf_view.character_viewport.scaling_3d_scale = snapshot["scaling_3d_scale"]
	elf_view.character_viewport.scaling_3d_mode = snapshot["scaling_3d_mode"]
	elf_view.character_viewport.use_taa = snapshot["use_taa"]
	elf_view.character_viewport.screen_space_aa = snapshot["screen_space_aa"]
	elf_view.character_viewport.msaa_3d = snapshot["msaa_3d"]
	elf_view.viewport_size = snapshot["viewport_size"]
	elf_view.camera_orthographic_size = snapshot["camera_size"]
	elf_view.render_sprite.texture_filter = snapshot["render_filter"]
	elf_view.render_sprite.scale = snapshot["render_scale"]
	await _wait_render_frames(3)
	elf_view.render_sprite.position = snapshot["render_position"]


func _apply_runtime_quality(
	size: Vector2i,
	orthographic_size: float,
	filter: CanvasItem.TextureFilter,
	display_scale: float
) -> void:
	elf_view.character_viewport.scaling_3d_scale = 1.0
	elf_view.character_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	elf_view.character_viewport.use_taa = false
	elf_view.character_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	elf_view.character_viewport.msaa_3d = Viewport.MSAA_4X
	elf_view.viewport_size = size
	elf_view.camera_orthographic_size = orthographic_size
	elf_view.render_sprite.texture_filter = filter
	elf_view.render_sprite.scale = Vector2.ONE * display_scale
	await _wait_render_frames(4)
	elf_view.render_sprite.position = (
		-elf_view.get_projected_foot_pixel() * display_scale
		+ elf_view.render_offset_adjustment
	)
	await _wait_render_frames(2)


func _capture_quality_variant(
	tag: String,
	viewport_path: String,
	composite_path: String,
	composite_crop_path: String,
	viewport_crop_path: String
) -> Dictionary:
	await RenderingServer.frame_post_draw
	var viewport_image := elf_view.character_viewport.get_texture().get_image()
	var composite_image := get_viewport().get_texture().get_image()
	if viewport_image == null or viewport_image.is_empty() \
			or composite_image == null or composite_image.is_empty():
		_errors.append("%s : capture de netteté indisponible." % tag)
		return {}
	viewport_image.save_png(ProjectSettings.globalize_path(viewport_path))
	composite_image.save_png(ProjectSettings.globalize_path(composite_path))
	var source_bbox := _alpha_bounds(viewport_image)
	var screen_bbox := _source_rect_to_screen(source_bbox)
	var fixed_crop_rect := _fixed_character_crop_rect(composite_image.get_size())
	var composite_crop := composite_image.get_region(fixed_crop_rect)
	composite_crop.save_png(ProjectSettings.globalize_path(composite_crop_path))
	var source_crop_rect := _expanded_clamped_rect(source_bbox, 12, viewport_image.get_size())
	var viewport_crop := viewport_image.get_region(source_crop_rect)
	viewport_crop.save_png(ProjectSettings.globalize_path(viewport_crop_path))
	return _pipeline_capture_data(tag, source_bbox, screen_bbox, viewport_path, composite_path)


func _pipeline_capture_data(
	tag: String,
	source_bbox: Rect2i,
	screen_bbox: Rect2,
	viewport_path: String,
	composite_path: String
) -> Dictionary:
	var parent_scales: Array = []
	var cursor: Node = elf_view.render_sprite
	while cursor != null:
		if cursor is Node2D:
			var node_2d := cursor as Node2D
			parent_scales.append({"node": str(node_2d.get_path()), "scale": _vector2_array(node_2d.scale)})
		if cursor == battle:
			break
		cursor = cursor.get_parent()
	var transform := elf_view.render_sprite.get_global_transform_with_canvas()
	var final_scale := Vector2(transform.x.length(), transform.y.length())
	return {
		"tag": tag,
		"viewport_size": [elf_view.character_viewport.size.x, elf_view.character_viewport.size.y],
		"scaling_3d_scale": elf_view.character_viewport.scaling_3d_scale,
		"scaling_3d_mode": int(elf_view.character_viewport.scaling_3d_mode),
		"use_taa": elf_view.character_viewport.use_taa,
		"screen_space_aa": int(elf_view.character_viewport.screen_space_aa),
		"msaa_3d": int(elf_view.character_viewport.msaa_3d),
		"render_texture_filter": int(elf_view.render_sprite.texture_filter),
		"render_scale": _vector2_array(elf_view.render_sprite.scale),
		"parent_2d_scales": parent_scales,
		"effective_canvas_scale": _vector2_array(final_scale),
		"character_pivot_scale": [elf_view.character_pivot.scale.x, elf_view.character_pivot.scale.y, elf_view.character_pivot.scale.z],
		"camera_orthographic_size": elf_view.camera_orthographic_size,
		"source_bbox": [source_bbox.position.x, source_bbox.position.y, source_bbox.size.x, source_bbox.size.y],
		"screen_bbox": [screen_bbox.position.x, screen_bbox.position.y, screen_bbox.size.x, screen_bbox.size.y],
		"effective_character_height_ratio": float(source_bbox.size.y) / float(maxi(1, elf_view.character_viewport.size.y)),
		"fractional_viewport_to_screen_scale": (
			absf(final_scale.x - roundf(final_scale.x)) > 0.0001
			or absf(final_scale.y - roundf(final_scale.y)) > 0.0001
		),
		"pixels_per_frame": elf_view.character_viewport.size.x * elf_view.character_viewport.size.y,
		"viewport_capture": viewport_path,
		"composite_capture": composite_path,
	}


func _alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _source_rect_to_screen(source_rect: Rect2i) -> Rect2:
	var transform := elf_view.render_sprite.get_global_transform_with_canvas()
	var corners := [
		transform * Vector2(source_rect.position),
		transform * Vector2(source_rect.end.x, source_rect.position.y),
		transform * Vector2(source_rect.end),
		transform * Vector2(source_rect.position.x, source_rect.end.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for point in corners.slice(1):
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _fixed_character_crop_rect(image_size: Vector2i) -> Rect2i:
	var foot_screen := hero_view.get_global_transform_with_canvas() * Vector2.ZERO
	var desired := Rect2i(int(foot_screen.x) - 130, int(foot_screen.y) - 205, 260, 230)
	return _clamp_rect(desired, image_size)


func _expanded_clamped_rect(rect: Rect2i, margin: int, image_size: Vector2i) -> Rect2i:
	return _clamp_rect(rect.grow(margin), image_size)


func _clamp_rect(rect: Rect2i, image_size: Vector2i) -> Rect2i:
	var x := clampi(rect.position.x, 0, maxi(0, image_size.x - 1))
	var y := clampi(rect.position.y, 0, maxi(0, image_size.y - 1))
	var end_x := clampi(rect.end.x, x + 1, image_size.x)
	var end_y := clampi(rect.end.y, y + 1, image_size.y)
	return Rect2i(x, y, end_x - x, end_y - y)


func _measure_quality_fps() -> Dictionary:
	for _index in range(90):
		await get_tree().process_frame
	var samples: Array[float] = []
	var deadline := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		var fps := Engine.get_frames_per_second()
		if fps > 10.0:
			samples.append(fps)
		await get_tree().process_frame
	var average := 0.0
	var minimum := INF
	for sample in samples:
		average += sample
		minimum = minf(minimum, sample)
	if not samples.is_empty():
		average /= samples.size()
	else:
		minimum = 0.0
	return {"average_fps": average, "minimum_fps": minimum, "samples": samples.size()}


func _wait_render_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _write_json(path: String, value: Dictionary) -> void:
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		_errors.append("Impossible d'écrire %s." % path)
		return
	output.store_string(JSON.stringify(value, "  "))
	output.close()


func _capture(filename: String) -> String:
	await RenderingServer.frame_post_draw
	var resource_path := "%s/%s" % [SCREENSHOT_DIR, filename]
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(absolute_path)
	if result != OK:
		_errors.append("Échec de capture : %s (code %d)." % [resource_path, result])
		return ""
	_screenshots.append(resource_path)
	return resource_path


func _check_character_not_clipped(label: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(elf_view):
		return
	var image := elf_view.character_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_errors.append("%s : texture du SubViewport indisponible." % label)
		return
	var border := 2
	for x in range(image.get_width()):
		for y in [border, image.get_height() - 1 - border]:
			if image.get_pixel(x, y).a > 0.02:
				_errors.append("%s touche le bord vertical du SubViewport." % label)
				return
	for y in range(image.get_height()):
		for x in [border, image.get_width() - 1 - border]:
			if image.get_pixel(x, y).a > 0.02:
				_errors.append("%s touche le bord horizontal du SubViewport." % label)
				return


func _vector2_array(value: Vector2) -> Array:
	return [value.x, value.y]


func _update_debug_label() -> void:
	if debug_label == null or not is_instance_valid(elf_view) or hero == null:
		return
	debug_label.text = "Héros: %s  |  cellule %s  |  animation %s\nF1 temporaire  F2 elfe  F3 comparer  F4 mains  F5 Hit  F6 Death  F7 Idle  F8 prochain déplacement: %s" % [
		hero.unit_name,
		hero.grid_pos,
		elf_view.get_elf_visual().get_current_animation(),
		"RUN" if _debug_run_enabled else "WALK",
	]
