extends "res://tools/class_card_vfx/semantic_probe.gd"
const ApprovedPlayer := preload("res://vfx/class_cards/approved/player.gd")
const SPELLS := ["g_hook", "t_glacier", "a_reap", "r_scatter"]
const INTENTS := [
	"Accroche → traction réelle → ouverture",
	"Éclosion → rosettes basses → expiration après 2 tours",
	"Une seule taille · bonus confirmé à 35 % PV ou moins",
	"Cinq flèches · croix réelle · une frappe simultanée",
]
var capture_mode := false
var busy := false
var normal_zoom := Vector2.ONE
var home := Vector2i.ZERO
var buttons: Array[Button] = []


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/approved/combat/"
	pair_distance = 3
	captured_frames = 0
	capture_mode = "--capture-approved" in OS.get_cmdline_user_args()


func _exercise() -> void:
	_overlay()
	var canvas: CanvasLayer = heading.get_parent()
	(canvas.get_child(0) as ColorRect).size = Vector2(1300, 182)
	normal_zoom = battle.camera.zoom / 2.4
	var found := false
	for cell: Vector2i in _central_cells():
		var valid := true
		for x in range(5):
			for y in range(-1, 2):
				var p := cell + Vector2i(x, y)
				var occupant: Unit = battle.grid.get_unit(p)
				valid = (
					valid and battle.grid.is_walkable(p)
					and (occupant == null or occupant in [hero, target])
				)
		if valid:
			home = cell
			found = true
			break
	_check(found, "Open production tiles accommodate the true five-cell area")
	if not found:
		await _finish()
		return
	var row := HBoxContainer.new()
	row.position = Vector2(56, 166)
	canvas.add_child(row)
	for id in SPELLS + ["a_reap_bonus", "camera"]:
		var button := Button.new()
		button.text = (
			"Caméra"
			if id == "camera"
			else ("Moisson ≤35 %"
				if id == "a_reap_bonus"
				else Cards.row(id)[2])
		)
		row.add_child(button)
		buttons.append(button)
		button.pressed.connect(
			func():
				if id == "camera":
					battle.camera.zoom = normal_zoom if battle.camera.zoom != normal_zoom else normal_zoom * 2.4
				else:
					_replay(id.trim_suffix("_bonus"), id.ends_with("_bonus")),
		)
	if capture_mode:
		battle.grid_view.set_process_unhandled_input(false)
		battle.grid_view.update_hover(Vector2(-100000, -100000))
		for button in buttons:
			button.disabled = true
		for id in SPELLS:
			await _record(id)
		await _record("a_reap", true)
		await _frost_lifecycle()
		for id in SPELLS:
			await _public_command(id)
		await _receipt_and_resume()
		await _finish()
	else:
		await _replay("g_hook")


func _stage(id: String, bonus := false) -> Spell:
	for cell in battle.terrain_effects.active_surface_cells():
		battle.terrain_effects.clear_effect(cell)
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	for state in target.get_active_statuses().duplicate():
		target.remove_status(state.data.get_effective_status_id())
	hero.start_turn()
	var ready_spell := Cards.make_spell(id)
	while hero.get_spell_cooldown_remaining(ready_spell) > 0:
		hero.start_turn()
	hero.current_ap = hero.max_ap.get_int()
	target.max_hp.base_value = 1000
	target.current_hp = 350 if bonus else 1000
	target.is_alive = true
	# Move target away before placing the hero; both remain grid-owned.
	var distance := 1 if id == "a_reap" else 3
	_move(target, home + Vector2i.RIGHT * distance)
	_move(hero, home)
	battle.camera.global_position = (
		battle._unit_views[hero].global_position + battle._unit_views[target].global_position
	) * .5 + Vector2(0, -35)
	session.cards.hand.assign([session.cards.add_copy(id)])
	heading.text = Cards.row(id)[2] + (" · bonus ≤ 35 % PV" if bonus else " · Blender / cel")
	caption.text = INTENTS[SPELLS.find(id)]
	return Cards.make_spell(id)


func _replay(id: String, bonus := false) -> void:
	if busy:
		return
	busy = true
	for button in buttons:
		button.disabled = true
	await _public_command(id, bonus)
	await get_tree().create_timer(1.1).timeout
	for button in buttons:
		button.disabled = false
	busy = false


func _record(id: String, bonus := false) -> void:
	var spell := _stage(id, bonus)
	var label := id + ("_bonus" if bonus else "")
	DirAccess.make_dir_recursive_absolute(output_path + label)
	var cell := target.grid_pos
	var prepared: Node = router.prepare_sentence(hero, spell, cell)
	var contact: float = prepared.CONTACT if prepared != null else 0.0
	if prepared != null:
		prepared.manual = true
	var committed := false
	var report := { }
	var frozen: Array = []
	for frame in 42:
		var time := float(frame) / 30.0
		if not committed and time + .00001 >= contact:
			report = battle.spell_caster.cast(hero, spell, cell)
			_check(not report.get("failed", false), "Real cast succeeds: " + label)
			_check(report.has("card_vfx"), "Pre-impact evidence exists: " + label)
			frozen = _state()
			committed = true
		for fx in router.effects:
			if is_instance_valid(fx) and not fx.closed:
				fx.manual = true
				fx.sample(time if fx == prepared else maxf(0, time - contact))
		for fx in router.ground_effects:
			if is_instance_valid(fx) and not fx.closed:
				fx.manual = true
				fx.sample(time)
		clock_label.text = "%.2f s · %d PA · caméra ×2,4 · IA suspendue" % [time, spell.ap_cost]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(
			get_viewport().get_texture().get_image().save_png(
				output_path + label + "/%03d.png" % frame
			) == OK,
			"Frame " + label + "/" + str(frame),
		)
		captured_frames += 1
		if frame == int(round(contact * 30.0)) + 2:
			battle.camera.zoom = normal_zoom
			clock_label.text = "Échelle normale de combat · impact confirmé"
			await _capture(label + "_normal")
			battle.camera.zoom = normal_zoom * 2.4
	_check(_state() == frozen, "Presentation preserves resolved combat values: " + label)
	_check(router.echoes.is_empty(), "No duplicated projectile: " + label)
	if id == "g_hook":
		_check(target.grid_pos == home + Vector2i.RIGHT, "Pull stops at the real adjacent cell")
		_check(
			battle._unit_views[target].global_position.is_equal_approx(
				VFXManager._grid_cell_global(target.grid_pos)
			),
			"Chain ends with view on the logical destination",
		)
	if id == "r_scatter":
		_check(
			prepared.destinations.size() == 5 and prepared.hit_points.size() == 1,
			"Five cells and one enemy contact",
		)
	if id == "a_reap":
		_check(prepared.empowered == bonus, "Only the pre-hit threshold enables Moisson bonus")
	if id == "t_glacier":
		_check(router.surface_holds.size() == 5, "Five actual frost rosettes")
		_check(_ground_order_correct(), "Frost is above base tiles and below actors")
	casts.append(
		{ "id": id, "bonus": bonus, "hp_damage": report.get("hp_damage_total", 0), "frames": 42 }
	)


func _frost_lifecycle() -> void:
	var spell := _stage("t_glacier")
	var report: Dictionary = battle.spell_caster.cast(hero, spell, target.grid_pos)
	_check(not report.get("failed", false), "Ice lifecycle cast succeeds")
	await get_tree().create_timer(.9).timeout
	var ice_cell := target.grid_pos
	_move(target, home + Vector2i(4, 1))
	target.remove_status(&"ecosystem_ice")
	_move(target, ice_cell)
	battle.terrain_effects.on_enter_cell(target, target.grid_pos)
	_check(target.has_status(&"ecosystem_ice"), "Entering ice applies the real movement reduction")
	var garden: Node = router.surface_holds.get(target.grid_pos)
	_check(garden != null and garden.pulse_age < .1, "An actual icy entry emits ankle chips")
	await _capture("frost_entry")
	battle.terrain_effects.tick_all_effects()
	_check(router.surface_holds.size() == 5, "Ice persists after one round")
	battle.terrain_effects.tick_all_effects()
	_check(router.surface_holds.is_empty(), "Ice retires after the second real round")
	await get_tree().create_timer(.4).timeout
	_check(
		garden == null or not is_instance_valid(garden) or garden.closed,
		"No lingering ice canopy",
	)
	await _capture("frost_expired")


func _public_command(id: String, bonus := false) -> void:
	var spell := _stage(id, bonus)
	battle.turn_queue = TurnQueue.new()
	battle._setup_state()
	hero.initiative.base_value = 1000
	battle.turn_queue.setup([hero, target])
	battle.turn_queue.advance()
	battle.presentation_state.clear_locks()
	battle.presentation_state.begin_player_turn()
	var ap := hero.current_ap
	var hp := target.current_hp
	battle._on_request_cast_spell(spell, target.grid_pos)
	var deadline := Time.get_ticks_msec() + 5000
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not battle._spell_resolution_pending, "Public input releases: " + id)
	_check(hero.current_ap == ap - spell.ap_cost, "Public input pays once: " + id)
	_check(target.current_hp < hp, "Public input commits real damage: " + id)
	_check(router.sentence_preparations.is_empty(), "Public input consumes preparation: " + id)
	clock_label.text = "Commande normale du combat · impact confirmé"
	await get_tree().create_timer(.5).timeout
	if capture_mode:
		await _capture(id + "_public")


func _receipt_and_resume() -> void:
	for child in get_children():
		if child is CanvasLayer:
			child.hide()
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	_check(
		router.effects.is_empty() and router.surface_holds.is_empty(),
		"Shutdown clears all new VFX",
	)
	GameManager._combat_report_tracker.discard()
	_check(session.combat_won(), "Fixture victory reaches Cards receipt")
	var checkpoint := "user://approved_cards_journey.json"
	_check(GameManager.save_expedition(checkpoint), "Production service saves receipt")
	var deck := session.cards.active.duplicate()
	var node_id := session.route.current_node_id
	var receipt: Node = load("res://ui/expedition/ExpeditionScreen.tscn").instantiate()
	add_child(receipt)
	await get_tree().create_timer(.3).timeout
	_check(receipt.find_child("ClassLootContinue", true, false) != null, "Actual receipt mounted")
	await _capture("journey_receipt")
	receipt.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = null
	var resumed := GameManager.resume_expedition(checkpoint)
	_check(resumed, "Resume loads the saved run")
	if resumed:
		await get_tree().scene_changed
		await get_tree().create_timer(.4).timeout
		session = GameManager.expedition
		_check(
			session.cards.active == deck and session.route.current_node_id == node_id,
			"Resume preserves deck and destination",
		)
		var screen := get_tree().current_scene
		var button := screen.find_child("ClassLootContinue", true, false) as Button
		_check(button != null, "Resume restores the unreviewed receipt")
		await _capture("journey_resumed")
		if button != null:
			button.pressed.emit()
			await get_tree().create_timer(.2).timeout
			_check(session.class_combat_receipt_reviewed(), "Continue commits receipt review")
		_check(
			router.effects.is_empty() and not router.is_card_battle(),
			"No VFX survives the receipt or resume",
		)
		screen.queue_free()
		get_tree().current_scene = null
		await get_tree().process_frame
	ExpeditionSaveService.remove_snapshot(checkpoint)
