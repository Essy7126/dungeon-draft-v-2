extends Node

## Capture reproductible de la vraie salle I de l'Odyssée.
##
## La taille du viewport est imposée au lancement par `--resolution`. Le runner
## ne redimensionne jamais la fenêtre pendant son exécution : il vérifie que
## `--capture-size=<largeur>x<hauteur>` correspond bien au viewport reçu.

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const TRANSITION_SCENE: PackedScene = preload("res://ui/Transitionsalle.tscn")
const INVALID_CELL := Vector2i(-1, -1)
const READY_DEADLINE_MSEC := 12000
const TURN_DEADLINE_MSEC := 16000
const REQUIRED_COMBAT_CAPTURE_COUNT := 5

var _requested_size := Vector2i.ZERO
var _output_dir := ""
var _original_reduced_motion := false
var _original_time_scale := 1.0
var _original_mouse_position := Vector2.ZERO
var _pointer_parked := false
var _finishing := false
var _battle = null
var _report := {
	"schema": "dd.odyssey.room-01-showcase.v1",
	"status": "FAIL",
	"requested_size": [0, 0],
	"actual_size": [0, 0],
	"run_path": "res://data/runs/odyssey.tres",
	"room_path": "",
	"room_name": "",
	"launch_contract": {
		"runtime_resize_used": false,
		"required_argument": "--capture-size=<WIDTH>x<HEIGHT>",
	},
	"transition": {},
	"checks": {},
	"captures": [],
	"warnings": [],
	"failures": [],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_original_reduced_motion = GameManager.is_reduced_motion_enabled()
	_original_time_scale = Engine.time_scale
	_requested_size = _parse_capture_size(
		_argument_value("--capture-size=")
	)
	if _requested_size == Vector2i.ZERO:
		_fail(
			"Argument invalide ou absent : utilisez "
			+ "--capture-size=1920x1080 (ou 1280x720)."
		)
		_finish()
		return
	_report.requested_size = _vector_to_array(_requested_size)
	_output_dir = "res://artifacts/odyssey_room01_showcase/%dx%d" % [
		_requested_size.x,
		_requested_size.y,
	]
	var output_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_output_dir)
	)
	if output_error != OK:
		_fail("Impossible de créer le dossier de sortie : %s" % _output_dir)
		_finish()
		return

	await _settle(4)
	var actual_size := _viewport_size()
	_report.actual_size = _vector_to_array(actual_size)
	_check(
		"launch_size_matches_requested_size",
		actual_size == _requested_size,
		(
			"Le viewport %dx%d ne correspond pas à --capture-size=%dx%d. "
			+ "Passez aussi --resolution %dx%d au moteur."
		) % [
			actual_size.x,
			actual_size.y,
			_requested_size.x,
			_requested_size.y,
			_requested_size.x,
			_requested_size.y,
		],
	)
	if actual_size != _requested_size:
		_finish()
		return
	_original_mouse_position = get_viewport().get_mouse_position()
	# Écarte le pointeur des cartes du HUD avant leur création. Il est restauré
	# à la fermeture pour ne pas laisser un tooltip fortuit polluer les preuves.
	Input.warp_mouse(Vector2(float(actual_size.x) * 0.5, 4.0))
	_pointer_parked = true
	await _settle(2)

	RenderingServer.set_default_clear_color(Color(0.015, 0.020, 0.027, 1.0))
	GameManager.cleanup_run_state()
	var capture_run := RUN.duplicate(false) as RunData
	if capture_run == null:
		_fail("La ressource réelle de l'Odyssée ne peut pas être dupliquée.")
		_finish()
		return
	var room_paths: Array[String] = []
	for room_value in capture_run.rooms:
		var configured_room := room_value as RoomData
		room_paths.append(
			configured_room.resource_path if configured_room != null else ""
		)
	var produced_room_paths := [
		(
			"res://data/arenas/produced/"
			+ "catabase_room_01_frail_hellspawn/arena.tres"
		),
		(
			"res://data/arenas/produced/"
			+ "catabase_room_02_ash_gate/arena.tres"
		),
		(
			"res://data/arenas/produced/"
			+ "catabase_room_03_judgement/arena.tres"
		),
	]
	_check(
		"produced_odyssey_arena_bundle",
		room_paths == produced_room_paths,
		"odyssey.tres ne référence pas exactement les trois arènes Catabase "
		+ "produites et validées ; capture interrompue.",
	)
	_report.launch_contract["room_paths"] = room_paths
	if room_paths != produced_room_paths:
		_finish()
		return
	# Stabilise uniquement la graine de cette instance de capture. Les salles et
	# leurs scènes restent les ressources canoniques de l'Odyssée.
	capture_run.randomize_seed_each_run = false
	var resolution := RunHeroResolver.resolve_runtime_hero_data(
		capture_run, false
	)
	if resolution == null or not resolution.is_valid() \
			or resolution.heroes.size() != 1:
		_fail("Le resolver runtime ne fournit pas exactement Achille.")
		_finish()
		return
	if not GameManager._prepare_preconfigured_run(
		capture_run, resolution.heroes
	):
		_fail("La préparation réelle de la run Odyssée a échoué.")
		_finish()
		return
	GameManager.current_room_index = 0
	var room := GameManager.get_current_room() as RoomData
	if room == null or room.battle_scene == null:
		_fail("La salle I de l'Odyssée ou sa battle_scene est absente.")
		_finish()
		return
	_report.room_path = room.resource_path
	_report.room_name = room.room_name
	_check(
		"real_odyssey_room_01_selected",
		room == capture_run.rooms[0] and room.resource_path == (
			"res://data/arenas/produced/"
			+ "catabase_room_01_frail_hellspawn/arena.tres"
		),
		"La salle active n'est pas l'arène produite de la salle I Catabase.",
	)

	await _capture_real_transition()
	# Les captures de combat montrent les animations et le feedback d'impact.
	GameManager.set_reduced_motion_enabled(false)
	await _capture_real_battle(room)
	_finish()


func _capture_real_transition() -> void:
	# Reduced motion place immédiatement le dossier dans son état final et évite
	# qu'une capture CI dépende de la cadence des premières frames.
	GameManager.set_reduced_motion_enabled(true)
	var transition := TRANSITION_SCENE.instantiate()
	if transition == null:
		_warn("Transitionsalle.tscn n'a pas pu être instanciée.")
		_report.transition = {"captured": false, "reason": "instantiate_failed"}
		return
	add_child(transition)
	await _settle(6)
	var snapshot := {}
	if is_instance_valid(transition) and transition.has_method(
		"get_presentation_snapshot_for_test"
	):
		snapshot = transition.call("get_presentation_snapshot_for_test")
	var record := await _capture(
		"00_transition_salle_1.png",
		"transition_salle_1",
		{
			"runtime_snapshot": snapshot,
			"current_room_index": GameManager.current_room_index,
		},
		false,
		2,
	)
	_report.transition = {
		"captured": bool(record.get("saved", false)),
		"real_manager_state": (
			GameManager.get_active_run_data() != null
			and GameManager.get_current_room() != null
		),
		"room_number": str(snapshot.get("room_number", "")),
		"room_name": str(snapshot.get("room_name", "")),
		"cta": str(snapshot.get("cta", "")),
		"focus_owner": _focus_owner_path(),
	}
	if not bool(record.get("saved", false)):
		_warn("La transition réelle n'a pas été capturée ; poursuite du combat.")
	if is_instance_valid(transition):
		transition.queue_free()
	await _settle(4)


func _capture_real_battle(room: RoomData) -> void:
	_battle = room.battle_scene.instantiate()
	if _battle == null:
		_fail("La battle_scene réelle de la salle I ne peut pas être instanciée.")
		return
	add_child(_battle)
	if not await _wait_for_deployment_ready(_battle):
		_fail("Le déploiement réel de la salle I n'est pas devenu disponible.")
		return

	var deployment = _battle.get("_deployment")
	var deploy_cells: Array[Vector2i] = deployment.get_available_cells()
	var deploy_cell: Vector2i = deployment.get_preferred_cursor_cell()
	if deploy_cell == INVALID_CELL and not deploy_cells.is_empty():
		deploy_cell = deploy_cells[0]
	if deploy_cell != INVALID_CELL:
		_battle._set_grid_cursor(deploy_cell)
	var deployment_highlights := _grid_highlights(_battle)
	_check(
		"deployment_state_ready",
		deployment.is_active() and deploy_cell != INVALID_CELL \
			and not deployment_highlights.is_empty(),
		"Le déploiement n'expose pas de cellule ou de surbrillance valide.",
	)
	await _capture(
		"01_deploiement.png",
		"deployment",
		{
			"deployment_active": deployment.is_active(),
			"available_cell_count": deploy_cells.size(),
			"preferred_cell": _vector_to_array(deploy_cell),
			"highlight_count": deployment_highlights.size(),
			"cursor_cell": _vector_to_array(_grid_cursor(_battle)),
		},
	)
	if not deployment.is_active() or deploy_cell == INVALID_CELL:
		return

	deployment.on_cell_clicked(deploy_cell)
	var hero_context := await _wait_for_room_hero(_battle)
	var hero := hero_context.get("hero") as Unit
	if hero == null:
		_fail("Achille n'a pas été créé après son déploiement réel.")
		return
	if not await _wait_for_player_turn(_battle, hero):
		_fail("Le tour joueur d'Achille n'est pas devenu interactif à temps.")
		return
	await _wait_for_turn_intro_banner_hidden(_battle)
	_battle._set_grid_cursor(hero.grid_pos)
	var active_unit = _battle.get_active_unit()
	_check(
		"player_turn_idle",
		active_unit == hero and _battle.turn_state != null \
			and _battle.turn_state.current == TurnState.State.IDLE,
		"Le tour joueur n'est pas en état IDLE sur Achille.",
	)
	await _capture(
		"02_tour_joueur.png",
		"player_turn",
		{
			"active_unit": str(hero.unit_id),
			"hero_cell": _vector_to_array(hero.grid_pos),
			"ap": hero.current_ap,
			"mp": hero.current_mp,
			"turn_state": _turn_state_name(_battle),
			"focus_owner": _focus_owner_path(),
		},
	)

	await _capture_move_targeting(_battle, hero)
	await _capture_spell_targeting(_battle, hero)
	await _capture_critical_impact(_battle, hero)


func _capture_move_targeting(battle, hero: Unit) -> void:
	var idle_baseline := await _rendered_viewport_image(1)
	var reachable: Array = battle.pathfinder.get_reachable(
		hero.grid_pos, hero.current_mp, hero
	)
	var destination := _farthest_reachable_destination(
		battle, hero.grid_pos, reachable, hero
	)
	battle._on_move_pressed()
	if destination != INVALID_CELL:
		battle._set_grid_cursor(destination)
	var highlights := _grid_highlights(battle)
	var feedback := _grid_feedback(battle)
	var state_is_move: bool = (
		battle.turn_state.current == TurnState.State.MOVE
	)
	_check(
		"move_targeting_state",
		state_is_move and destination != INVALID_CELL \
			and highlights.has(destination) \
			and feedback.has(destination) \
			and _grid_cursor(battle) == destination,
		"Le ciblage déplacement n'affiche pas une destination focalisée valide.",
	)
	var capture_record := await _capture(
		"03_ciblage_deplacement.png",
		"movement_targeting",
		{
			"turn_state": _turn_state_name(battle),
			"origin": _vector_to_array(hero.grid_pos),
			"destination": _vector_to_array(destination),
			"reachable_count": reachable.size(),
			"highlight_count": highlights.size(),
			"feedback_marker_count": feedback.size(),
			"cursor_cell": _vector_to_array(_grid_cursor(battle)),
		},
	)
	var rendered_delta := _pixel_difference_metrics(
		idle_baseline, get_viewport().get_texture().get_image()
	)
	capture_record["visual_delta_from_idle"] = rendered_delta
	_check(
		"move_targeting_visible_in_capture",
		battle.turn_state.current == TurnState.State.MOVE \
			and _grid_highlights(battle).has(destination) \
			and _grid_feedback(battle).has(destination) \
			and int(rendered_delta.get("strong_changed_samples", 0)) >= 12,
		"La preuve déplacement ne conserve pas ses marqueurs au rendu.",
	)
	battle.cancel_active_selection()
	await _settle(3)


func _capture_spell_targeting(battle, hero: Unit) -> void:
	var sweep := _find_spell(hero, &"achilles_sweep")
	if sweep == null:
		_fail("Le sort Balayage d'Achille est absent de la vraie run.")
		return
	var idle_baseline := await _rendered_viewport_image(1)
	battle._on_spell_pressed(sweep)
	battle._set_grid_cursor(hero.grid_pos)
	var highlights := _grid_highlights(battle)
	var feedback := _grid_feedback(battle)
	var state_is_spell: bool = (
		battle.turn_state.current == TurnState.State.TARGET_SPELL
	)
	_check(
		"spell_targeting_state",
		state_is_spell and highlights.has(hero.grid_pos) \
			and feedback.has(hero.grid_pos) \
			and _grid_cursor(battle) == hero.grid_pos,
		"Le ciblage de Balayage n'affiche pas sa cible primaire réelle.",
	)
	var capture_record := await _capture(
		"04_ciblage_sort_balayage.png",
		"spell_targeting",
		{
			"spell_id": str(sweep.get_effective_spell_id()),
			"turn_state": _turn_state_name(battle),
			"primary_cell": _vector_to_array(hero.grid_pos),
			"highlight_count": highlights.size(),
			"feedback_marker_count": feedback.size(),
			"cursor_cell": _vector_to_array(_grid_cursor(battle)),
		},
	)
	var rendered_delta := _pixel_difference_metrics(
		idle_baseline, get_viewport().get_texture().get_image()
	)
	capture_record["visual_delta_from_idle"] = rendered_delta
	_check(
		"spell_targeting_visible_in_capture",
		battle.turn_state.current == TurnState.State.TARGET_SPELL \
			and _grid_highlights(battle).has(hero.grid_pos) \
			and _grid_feedback(battle).has(hero.grid_pos) \
			and int(rendered_delta.get("strong_changed_samples", 0)) >= 12,
		"La preuve Balayage ne conserve pas cible/highlight/feedback au rendu.",
	)
	battle.cancel_active_selection()
	await _settle(3)


func _capture_critical_impact(battle, hero: Unit) -> void:
	var enemy := _first_living_enemy(battle)
	if enemy == null:
		_fail("Aucun ennemi vivant n'est disponible pour l'impact critique.")
		return
	battle._set_grid_cursor(enemy.grid_pos)
	var idle_baseline := await _rendered_viewport_image(1)
	enemy.current_shield = 0
	var hp_before := enemy.current_hp
	var damage_result = enemy.take_damage(
		8,
		hero,
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE,
		{
			"force_crit": true,
			"ignore_defense": true,
			"cannot_be_dodged": true,
			"impact_id": &"odyssey_room01_showcase_critical",
			"action_id": &"odyssey_room01_showcase",
		},
	)
	# Deux frames : la première draine le feedback flottant, la seconde rend le
	# burst au cœur du hit-stop (Engine.time_scale reste à zéro brièvement).
	await _settle(2)
	var impact := battle.get_node_or_null("ImpactJuice") as ImpactJuice
	var floating := battle.get_node_or_null(
		"FloatingTextSpawner"
	) as CombatFeedbackController
	var impact_snapshot := (
		impact.get_debug_snapshot() if impact != null else {}
	)
	var floating_snapshot := (
		floating.get_debug_snapshot() if floating != null else {}
	)
	var damage_applied := hp_before - enemy.current_hp
	var critical_resolved := (
		damage_result != null and bool(damage_result.is_crit)
	)
	_check(
		"critical_impact_feedback",
		critical_resolved and damage_applied > 0 \
			and str(impact_snapshot.get("last_burst_kind", "")) == "critical" \
			and str(impact_snapshot.get("last_punch_kind", "")) == "critical" \
			and int(floating_snapshot.get("active_count", 0)) > 0,
		"L'impact réel n'a pas produit le burst, le punch et le texte critique.",
	)
	var capture_record := await _capture(
		"05_impact_critique.png",
		"critical_impact",
		{
			"target_unit": str(enemy.unit_id),
			"target_cell": _vector_to_array(enemy.grid_pos),
			"hp_before": hp_before,
			"hp_after": enemy.current_hp,
			"damage_applied": damage_applied,
			"critical_resolved": critical_resolved,
			"impact": {
				"active_burst_count": int(
					impact_snapshot.get("active_burst_count", 0)
				),
				"last_burst_kind": str(
					impact_snapshot.get("last_burst_kind", "")
				),
				"last_punch_kind": str(
					impact_snapshot.get("last_punch_kind", "")
				),
				"camera_punch_active": bool(
					impact_snapshot.get("camera_punch_active", false)
				),
			},
			"floating_text_active_count": int(
				floating_snapshot.get("active_count", 0)
			),
		},
		true,
		0,
	)
	var rendered_delta := _pixel_difference_metrics(
		idle_baseline, get_viewport().get_texture().get_image()
	)
	capture_record["visual_delta_from_idle"] = rendered_delta
	var impact_after_render := (
		impact.get_debug_snapshot() if impact != null else {}
	)
	var floating_after_render := (
		floating.get_debug_snapshot() if floating != null else {}
	)
	_check(
		"critical_feedback_visible_in_capture",
		int(impact_after_render.get("active_burst_count", 0)) > 0 \
			and int(floating_after_render.get("active_count", 0)) > 0 \
			and int(rendered_delta.get("strong_changed_samples", 0)) >= 12,
		"La preuve critique ne conserve pas burst/texte/delta visuel au rendu.",
	)
	# Laisse le contrôleur propriétaire terminer son hit-stop avec une horloge
	# non affectée par time_scale, avant le nettoyage du SceneTree.
	await get_tree().create_timer(0.20, true, false, true).timeout


func _wait_for_deployment_ready(battle) -> bool:
	var deadline := Time.get_ticks_msec() + READY_DEADLINE_MSEC
	while is_instance_valid(battle) and Time.get_ticks_msec() < deadline:
		var deployment = battle.get("_deployment")
		if battle.get("grid") != null and battle.get("grid_view") != null \
				and deployment != null and deployment.is_active() \
				and not deployment.get_available_cells().is_empty():
			await _settle(3)
			return true
		await get_tree().process_frame
	return false


func _wait_for_room_hero(battle) -> Dictionary:
	var deadline := Time.get_ticks_msec() + READY_DEADLINE_MSEC
	while is_instance_valid(battle) and Time.get_ticks_msec() < deadline:
		var heroes: Array = battle.units.filter(func(value):
			return value != null and (value as Unit).team == 0
		)
		if heroes.size() == 1:
			var hero := heroes[0] as Unit
			var views := battle.get("_unit_views") as Dictionary
			var view = views.get(hero)
			if is_instance_valid(view):
				await _settle(4)
				return {"hero": hero, "view": view}
		await get_tree().process_frame
	return {}


func _wait_for_player_turn(battle, hero: Unit) -> bool:
	var deadline := Time.get_ticks_msec() + TURN_DEADLINE_MSEC
	while is_instance_valid(battle) and is_instance_valid(hero) \
			and Time.get_ticks_msec() < deadline:
		if battle.get_active_unit() == hero and battle.turn_state != null \
				and battle.turn_state.current == TurnState.State.IDLE:
			return true
		await get_tree().process_frame
	return false


func _wait_for_turn_intro_banner_hidden(battle) -> bool:
	if battle.action_bar == null \
			or not battle.action_bar.has_method("get_turn_intro_banner"):
		return true
	var banner = battle.action_bar.call("get_turn_intro_banner")
	if banner == null:
		return true
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(banner) and banner.visible \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return not is_instance_valid(banner) or not banner.visible


func _farthest_reachable_destination(
		battle,
		origin: Vector2i,
		reachable: Array,
		hero: Unit
	) -> Vector2i:
	var best := INVALID_CELL
	var best_cost := -1
	for value in reachable:
		var cell := value as Vector2i
		if cell == origin:
			continue
		var path: Array = battle.pathfinder.find_path(origin, cell, hero)
		var cost := int(
			battle.pathfinder.path_cost_breakdown(path, hero).get("total", -1)
		)
		if path.size() >= 2 and cost >= 0 and cost <= hero.current_mp \
				and cost > best_cost:
			best = cell
			best_cost = cost
	return best


func _find_spell(hero: Unit, spell_id: StringName) -> Spell:
	for spell_value in hero.spells:
		var spell := spell_value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _first_living_enemy(battle) -> Unit:
	for unit_value in battle.units:
		var unit := unit_value as Unit
		if unit != null and unit.team == 1 and unit.is_alive:
			return unit
	return null


func _grid_highlights(battle) -> Dictionary:
	var grid_view = battle.get("grid_view")
	if is_instance_valid(grid_view) and grid_view.has_method(
		"get_highlight_snapshot"
	):
		return grid_view.get_highlight_snapshot()
	return {}


func _grid_feedback(battle) -> Dictionary:
	var grid_view = battle.get("grid_view")
	if is_instance_valid(grid_view) and grid_view.has_method(
		"get_cell_feedback_snapshot"
	):
		return grid_view.get_cell_feedback_snapshot()
	return {}


func _grid_cursor(battle) -> Vector2i:
	var grid_view = battle.get("grid_view")
	if is_instance_valid(grid_view) and grid_view.has_method("get_cursor_cell"):
		return grid_view.get_cursor_cell()
	return INVALID_CELL


func _turn_state_name(battle) -> String:
	if battle == null or battle.get("turn_state") == null:
		return "MISSING"
	match battle.turn_state.current:
		TurnState.State.IDLE:
			return "IDLE"
		TurnState.State.MOVE:
			return "MOVE"
		TurnState.State.TARGET_MELEE:
			return "TARGET_MELEE"
		TurnState.State.TARGET_SPELL:
			return "TARGET_SPELL"
		TurnState.State.ANIMATING:
			return "ANIMATING"
		_:
			return str(battle.turn_state.current)


func _capture(
		file_name: String,
		stage: String,
		metadata: Dictionary = {},
		required := true,
		settle_frames := 3
	) -> Dictionary:
	await _settle(settle_frames)
	# La coroutine reprend au début de la frame ; attendre sa fin garantit que la
	# texture lue contient bien les marqueurs/texte créés pendant cette frame.
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var resource_path := _output_dir.path_join(file_name)
	var global_path := ProjectSettings.globalize_path(resource_path)
	var save_error := ERR_CANT_CREATE
	if image != null and not image.is_empty():
		save_error = image.save_png(global_path)
	var dimensions := Vector2i.ZERO
	if image != null and not image.is_empty():
		dimensions = Vector2i(image.get_width(), image.get_height())
	var image_metrics := _image_metrics(image)
	var saved := save_error == OK and dimensions == _requested_size \
		and float(image_metrics.get("luminance_range", 0.0)) > 0.015
	var record := {
		"stage": stage,
		"file": file_name,
		"resource_path": resource_path,
		"absolute_path": global_path,
		"saved": saved,
		"save_error": save_error,
		"size": _vector_to_array(dimensions),
		"sha256": (
			FileAccess.get_sha256(global_path).to_upper()
			if save_error == OK else ""
		),
		"image_metrics": image_metrics,
		"metadata": metadata.duplicate(true),
	}
	_report.captures.append(record)
	if not saved:
		var message := "Capture invalide (%s), erreur=%d, taille=%dx%d." % [
			stage,
			save_error,
			dimensions.x,
			dimensions.y,
		]
		if required:
			_fail(message)
		else:
			_warn(message)
	return record


func _rendered_viewport_image(settle_frames := 0) -> Image:
	await _settle(settle_frames)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _pixel_difference_metrics(before: Image, after: Image) -> Dictionary:
	if before == null or after == null or before.is_empty() or after.is_empty() \
			or before.get_size() != after.get_size():
		return {
			"sample_count": 0,
			"changed_samples": 0,
			"strong_changed_samples": 0,
			"maximum_channel_delta": 0.0,
		}
	var changed := 0
	var strong_changed := 0
	var sample_count := 0
	var maximum_delta := 0.0
	var step := 4
	for y in range(0, after.get_height(), step):
		for x in range(0, after.get_width(), step):
			var before_color := before.get_pixel(x, y)
			var after_color := after.get_pixel(x, y)
			var delta := maxf(
				absf(before_color.r - after_color.r),
				maxf(
					absf(before_color.g - after_color.g),
					absf(before_color.b - after_color.b),
				),
			)
			maximum_delta = maxf(maximum_delta, delta)
			if delta >= 0.025:
				changed += 1
			if delta >= 0.12:
				strong_changed += 1
			sample_count += 1
	return {
		"sample_count": sample_count,
		"changed_samples": changed,
		"strong_changed_samples": strong_changed,
		"maximum_channel_delta": snappedf(maximum_delta, 0.0001),
	}


func _image_metrics(image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return {
			"sample_count": 0,
			"opaque_sample_count": 0,
			"minimum_luminance": 0.0,
			"maximum_luminance": 0.0,
			"luminance_range": 0.0,
		}
	var minimum := 1.0
	var maximum := 0.0
	var sample_count := 0
	var opaque_count := 0
	var step := maxi(
		8, int(mini(image.get_width(), image.get_height()) / 48.0)
	)
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var color := image.get_pixel(x, y)
			var luminance := (
				color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			)
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
			sample_count += 1
			if color.a > 0.02:
				opaque_count += 1
	return {
		"sample_count": sample_count,
		"opaque_sample_count": opaque_count,
		"minimum_luminance": snappedf(minimum, 0.0001),
		"maximum_luminance": snappedf(maximum, 0.0001),
		"luminance_range": snappedf(maximum - minimum, 0.0001),
	}


func _viewport_size() -> Vector2i:
	var value := get_viewport().get_visible_rect().size
	return Vector2i(roundi(value.x), roundi(value.y))


func _parse_capture_size(raw_value: String) -> Vector2i:
	var normalized := raw_value.strip_edges().to_lower()
	var parts := normalized.split("x", false)
	if parts.size() != 2 or not parts[0].is_valid_int() \
			or not parts[1].is_valid_int():
		return Vector2i.ZERO
	var parsed := Vector2i(int(parts[0]), int(parts[1]))
	if parsed.x < 640 or parsed.y < 360 or parsed.x > 7680 \
			or parsed.y > 4320:
		return Vector2i.ZERO
	return parsed


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _focus_owner_path() -> String:
	var owner := get_viewport().gui_get_focus_owner()
	return str(owner.get_path()) if is_instance_valid(owner) else ""


func _vector_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


func _check(name: String, passed: bool, message: String) -> void:
	_report.checks[name] = passed
	if not passed:
		_fail(message)


func _warn(message: String) -> void:
	if not _report.warnings.has(message):
		_report.warnings.append(message)
	push_warning(message)


func _fail(message: String) -> void:
	if not _report.failures.has(message):
		_report.failures.append(message)
	push_error(message)


func _settle(frame_count: int) -> void:
	for _frame in maxi(0, frame_count):
		await get_tree().process_frame


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	_finalize_and_quit.call_deferred()


func _finalize_and_quit() -> void:
	Engine.time_scale = _original_time_scale
	if is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	GameManager.cleanup_run_state()
	# Les backends 3D utilisent des SubViewport. Leur laisser plusieurs frames
	# de destruction évite de quitter alors que leurs ressources GPU sont encore
	# dans la file de libération.
	await _settle(16)
	GameManager.set_reduced_motion_enabled(_original_reduced_motion)
	var required_combat_captures := 0
	for record_value in _report.captures:
		var record := record_value as Dictionary
		if bool(record.get("saved", false)) \
				and str(record.get("stage", "")) != "transition_salle_1":
			required_combat_captures += 1
	_report.checks["five_required_combat_captures_saved"] = (
		required_combat_captures == REQUIRED_COMBAT_CAPTURE_COUNT
	)
	if required_combat_captures != REQUIRED_COMBAT_CAPTURE_COUNT:
		_fail(
			"Le runner a produit %d/%d captures de combat requises." % [
				required_combat_captures,
				REQUIRED_COMBAT_CAPTURE_COUNT,
			]
		)
	_report.status = "PASS" if _report.failures.is_empty() else "FAIL"
	_report["completed_at_unix"] = Time.get_unix_time_from_system()
	_report["godot_version"] = str(
		Engine.get_version_info().get("string", "")
	)
	if not _output_dir.is_empty():
		var report_path := _output_dir.path_join("showcase_report.json")
		var global_report_path := ProjectSettings.globalize_path(report_path)
		var file := FileAccess.open(global_report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_report, "\t"))
			file.close()
			print(
				"ODYSSEY_ROOM01_SHOWCASE %s %s" % [
					_report.status,
					global_report_path,
				]
			)
		else:
			push_error("Impossible d'écrire le rapport : %s" % report_path)
	if _pointer_parked:
		Input.warp_mouse(_original_mouse_position)
	get_tree().quit(0 if _report.failures.is_empty() else 1)
