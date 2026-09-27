extends "res://tools/class_card_vfx/semantic_probe.gd"
## Real battle and SpellCaster; interactive replay, plus deterministic native capture.
const Hammer := preload("res://vfx/class_cards/sentence/hammer_player.gd")
var busy := false
var capture_mode := false
var replay_v1: Button
var replay_v2: Button
var closeup := true
var normal_zoom := Vector2.ONE
var heard: Array[StringName] = []


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/sentence/combat/"
	pair_distance = 2
	captured_frames = 0
	capture_mode = "--capture-sentence" in OS.get_cmdline_user_args()


func _exercise() -> void:
	_overlay()
	var canvas: CanvasLayer = get_children().filter(
		func(node):
			return node is CanvasLayer,
	)[0]
	(canvas.get_child(0) as ColorRect).size.y = 188
	normal_zoom = battle.camera.zoom / 2.4
	heading.text = "Sentence du rempart · pilote Blender"
	caption.text = "Marteau d'airain · armement → frappe → retombée"
	var row := HBoxContainer.new()
	row.position = Vector2(56, 165)
	row.add_theme_constant_override("separation", 12)
	canvas.add_child(row)
	replay_v1 = Button.new()
	replay_v1.text = "Rejouer V1"
	replay_v1.pressed.connect(
		func():
			_replay(true),
	)
	row.add_child(replay_v1)
	replay_v2 = Button.new()
	replay_v2.text = "Rejouer Blender"
	replay_v2.pressed.connect(
		func():
			_replay(false),
	)
	row.add_child(replay_v2)
	var camera_button := Button.new()
	camera_button.text = "Caméra normale / détail"
	camera_button.pressed.connect(
		func():
			closeup = not closeup
			battle.camera.zoom = normal_zoom * (2.4 if closeup else 1.0),
	)
	row.add_child(camera_button)
	if capture_mode:
		battle.get_node("CombatAudio").feedback.played.connect(
			func(cue: StringName):
				heard.append(cue),
		)
		replay_v1.disabled = true
		replay_v2.disabled = true
		camera_button.disabled = true
		await _capture_sequence(true)
		await _capture_sequence(false)
		await _production_flow()
		await _boundaries()
		await _receipt_and_resume()
		await _finish()
	else:
		await _replay(false)


func _reset_cast(legacy: bool) -> Spell:
	router.clear()
	router.sentence_legacy = legacy
	target.current_hp = target.max_hp.get_int()
	target.current_shield = 0
	hero.current_ap = hero.max_ap.get_int()
	session.cards.hand.assign([session.cards.add_copy("g_crash")])
	return Cards.make_spell("g_crash")


func _replay(legacy: bool) -> void:
	if busy:
		return
	busy = true
	replay_v1.disabled = true
	replay_v2.disabled = true
	var spell := _reset_cast(legacy)
	heading.text = "Sentence du rempart · " + ("V1 cel" if legacy else "Blender + contact cel")
	var hp_before := target.current_hp
	var ap_before := hero.current_ap
	if not legacy:
		var prepared: Dictionary = await preload("res://vfx/class_cards/sentence/presentation.gd").prepare(
			battle,
			hero,
			spell,
			target.grid_pos,
		)
		_check(not prepared.get("cancelled", false), "Live preparation completes")
		_check(
			target.current_hp == hp_before and hero.current_ap == ap_before,
			"Arming does not spend resources or deal damage",
		)
	var report: Dictionary = battle.spell_caster.cast(hero, spell, target.grid_pos)
	_check(not report.get("failed", false), "Interactive real cast succeeds")
	clock_label.text = "Dégâts réels : %d · PA dépensés : %d · IA suspendue" % [
		hp_before - target.current_hp,
		ap_before - hero.current_ap,
	]
	await get_tree().create_timer(1.4).timeout
	replay_v1.disabled = false
	replay_v2.disabled = false
	busy = false


func _capture_sequence(legacy: bool) -> void:
	heard.clear()
	var name_value := "v1" if legacy else "v2"
	var spell := _reset_cast(legacy)
	var hp_before := target.current_hp
	var ap_before := hero.current_ap
	var fx: Node = null
	if not legacy:
		fx = router.prepare_sentence(hero, spell, target.grid_pos)
		_check(fx != null, "V2 windup exists in actual battle")
		fx.manual = true
	DirAccess.make_dir_recursive_absolute(output_path + name_value)
	for frame in 63:
		var seconds := frame / 30.0
		if frame == 15:
			_check(not heard.has(&"sentence_contact"), "No bronze sound before contact")
			_check(
				target.current_hp == hp_before and hero.current_ap == ap_before,
				name_value + " no damage or AP spend before contact",
			)
			var report: Dictionary = battle.spell_caster.cast(hero, spell, target.grid_pos)
			_check(not report.get("failed", false), name_value + " actual cast succeeds")
			_check(target.current_hp < hp_before, name_value + " contact deals actual damage")
			_check(
				heard.count(&"sentence_contact") == (0 if legacy else 1),
				name_value + " contact selects its own sound exactly once",
			)
			casts.append(
				{
					"id": "g_crash",
					"variant": name_value,
					"damage": hp_before - target.current_hp,
					"ap": ap_before - hero.current_ap,
				}
			)
			if not legacy:
				_check(
					fx.confirmed and router.sentence_preparations.is_empty(),
					"The prepared object becomes the confirmed impact",
				)
		for effect in router.effects:
			if is_instance_valid(effect) and not effect.closed:
				effect.manual = true
				effect.sample(seconds if effect == fx else maxf(0, seconds - .5))
		heading.text = "Sentence du rempart · " + ("V1" if legacy else "Blender + contact cel")
		clock_label.text = "%.2f s · %s · caméra ×2,4" % [
			seconds,
			"préparation" if frame < 15 else "impact confirmé",
		]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(
			output_path + name_value + "/%03d.png" % frame
		)
		_check(error == OK, name_value + " frame %d saved" % frame)
		captured_frames += 1
		if frame in [11, 15, 18, 25]:
			await _capture(name_value + "_%d" % frame)
	if not legacy:
		battle.camera.zoom = normal_zoom
		fx.sample(.50)
		clock_label.text = "0.50 s · contact · caméra normale"
		await _capture("v2_normal_contact")
		battle.camera.zoom = normal_zoom * 2.4
	_check(
		casts.size() < 2 or casts[0].damage == casts[1].damage,
		"V1 and V2 preserve identical damage",
	)


func _boundaries() -> void:
	var spell := _reset_cast(false)
	var hp_before := target.current_hp
	var fx: Node = router.prepare_sentence(hero, spell, target.grid_pos)
	fx.manual = true
	fx.sample(.49)
	router.resolve(hero, spell, { "failed": true })
	_check(
		fx.closed and not fx.confirmed and target.current_hp == hp_before,
		"Failed cast cancels windup without impact",
	)
	spell = _reset_cast(false)
	fx = router.prepare_sentence(hero, spell, target.grid_pos)
	fx.manual = true
	router.resolve(hero, spell, { "visual_impact_cells": [], "action_id": "sentence-miss" })
	_check(fx.closed and not fx.confirmed, "Miss never becomes a hammer hit")
	spell = _reset_cast(false)
	fx = router.prepare_sentence(hero, spell, target.grid_pos)
	router.clear(true)
	_check(
		fx.closed and router.sentence_preparations.is_empty(),
		"Battle closure removes preparations",
	)


func _receipt_and_resume() -> void:
	# A fixture victory checks the production receipt/resume boundary, not a played win.
	router.observing = true
	var spell := _reset_cast(false)
	var hp_before := target.current_hp
	var ap_before := hero.current_ap
	heard.clear()
	battle._on_request_cast_spell(spell, target.grid_pos)
	_check(
		await _wait_until(
			func():
				return router.sentence_preparations.has(hero),
		),
		"Final command enters windup before shutdown",
	)
	var pending_hammer: Node = router.sentence_preparations.get(hero)
	for child in get_children():
		if child is CanvasLayer:
			child.hide()
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	await get_tree().create_timer(.65).timeout
	_check(
		target.current_hp == hp_before and hero.current_ap == ap_before,
		"Scene destruction during windup commits neither hit nor payment",
	)
	_check(not is_instance_valid(pending_hammer), "Scene destruction frees the suspended hammer")
	_check(not heard.has(&"sentence_contact"), "Scene destruction never plays a bronze contact")
	GameManager._combat_report_tracker.discard()
	_check(session.combat_won(), "Fixture victory reaches Cards receipt")
	var checkpoint := "user://sentence_cards_journey.json"
	_check(GameManager.save_expedition(checkpoint), "Production service saves Cards receipt")
	var original_deck := session.cards.active.duplicate()
	var original_node := session.route.current_node_id
	var receipt: Node = load("res://ui/expedition/ExpeditionScreen.tscn").instantiate()
	add_child(receipt)
	await get_tree().create_timer(.3).timeout
	_check(
		receipt.find_child("ClassLootContinue", true, false) != null,
		"Actual Cards receipt is mounted",
	)
	await _capture("journey_receipt")
	receipt.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = null
	var resumed := GameManager.resume_expedition(checkpoint)
	_check(resumed, "Real resume command loads the saved run")
	if resumed:
		await get_tree().scene_changed
		await get_tree().create_timer(.4).timeout
		session = GameManager.expedition
		_check(
			session.cards.active == original_deck and session.route.current_node_id == original_node,
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
			router.sentence_preparations.is_empty() and not router.is_card_battle(),
			"No hammer survives receipt and resume",
		)
		screen.queue_free()
		get_tree().current_scene = null
		await get_tree().process_frame
	ExpeditionSaveService.remove_snapshot(checkpoint)


func _wait_until(predicate: Callable, seconds := 4.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return bool(predicate.call())


func _production_flow() -> void:
	# Actual Battle command path; only turn scheduling is fixture-controlled.
	battle.turn_queue = TurnQueue.new()
	battle._setup_state()
	hero.initiative.base_value = 1000
	battle.turn_queue.setup([hero, target])
	battle.turn_queue.advance()
	battle.presentation_state.clear_locks()
	battle.presentation_state.begin_player_turn()
	var spell := _reset_cast(false)
	var hp_before := target.current_hp
	var ap_before := hero.current_ap
	battle._on_request_cast_spell(spell, target.grid_pos)
	_check(
		await _wait_until(
			func():
				return router.sentence_preparations.has(hero),
		),
		"Battle enters the real pre-cast windup",
	)
	_check(
		target.current_hp == hp_before and hero.current_ap == ap_before,
		"Battle windup has not resolved or spent AP",
	)
	battle._on_request_cast_spell(spell, target.grid_pos)
	_check(router.sentence_preparations.size() == 1, "Player input remains locked during windup")
	_check(
		await _wait_until(
			func():
				return not battle._spell_resolution_pending,
		),
		"Battle releases input after real resolution",
	)
	_check(
		target.current_hp < hp_before and hero.current_ap == ap_before - 3,
		"Battle commits one hit and one payment",
	)
	await _capture("production_command")
	spell = _reset_cast(false)
	hp_before = target.current_hp
	battle._on_request_cast_spell(spell, target.grid_pos)
	_check(
		await _wait_until(
			func():
				return router.sentence_preparations.has(hero),
		),
		"Second command prepares",
	)
	# External mutation is intentional in this failure fixture.
	hero.current_ap = 0
	_check(
		await _wait_until(
			func():
				return not battle._spell_resolution_pending,
		),
		"Unavailable command aborts after preparation",
	)
	_check(target.current_hp == hp_before, "Revalidation prevents damage after resources changed")
	_check(
		router.sentence_preparations.is_empty(),
		"Rejected begin_cast releases the preparation immediately",
	)
