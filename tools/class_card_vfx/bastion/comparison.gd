extends "res://tools/class_card_vfx/semantic_probe.gd"
## Real grant, source absorption, break and activation expiry in a production room.
const Bastion := preload("res://vfx/class_cards/bastion/bastion_player.gd")
var busy := false
var capture_mode := false
var normal_zoom := Vector2.ONE
var closeup := true
var buttons: Array[Button] = []
var births: Dictionary = { }


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/bastion/combat/"
	pair_distance = 2
	captured_frames = 0
	capture_mode = "--capture-bastion" in OS.get_cmdline_user_args()


func _exercise() -> void:
	_overlay()
	var canvas: CanvasLayer = heading.get_parent()
	(canvas.get_child(0) as ColorRect).size.y = 188
	normal_zoom = battle.camera.zoom / 2.4
	caption.text = "Déploiement → protection active → absorption → rupture"
	var row := HBoxContainer.new()
	row.position = Vector2(56, 165)
	row.add_theme_constant_override("separation", 12)
	canvas.add_child(row)
	for label in ["Rejouer V1", "Rejouer Blender", "Tester expiration", "Caméra normale / détail"]:
		var button := Button.new()
		button.text = label
		row.add_child(button)
		buttons.append(button)
	buttons[0].pressed.connect(
		func():
			_replay(true),
	)
	buttons[1].pressed.connect(
		func():
			_replay(false),
	)
	buttons[2].pressed.connect(
		func():
			_replay(false, true),
	)
	buttons[3].pressed.connect(
		func():
			closeup = not closeup
			battle.camera.zoom = normal_zoom * (2.4 if closeup else 1.0),
	)
	if capture_mode:
		# Native mouse hover is unrelated to the effect and must not enter recorded frames.
		battle.grid_view.set_process_unhandled_input(false)
		battle.grid_view.update_hover(Vector2(-100000, -100000))
		for button in buttons:
			button.disabled = true
		await _sequence(true)
		await _sequence(false)
		await _expiry_checks()
		await _production_command()
		await _receipt_and_resume()
		await _finish()
	else:
		await _replay(false)


func _grant(legacy: bool) -> Dictionary:
	# A replay is a fresh activation: the real card is limited to one use per activation.
	hero.start_turn()
	hero.clear_shield()
	hero.current_hp = hero.max_hp.get_int()
	hero.current_ap = hero.max_ap.get_int()
	router.clear()
	router.bastion_legacy = legacy
	session.cards.hand.assign([session.cards.add_copy("g_bastion")])
	var ap := hero.current_ap
	var report: Dictionary = battle.spell_caster.cast(
		hero,
		Cards.make_spell("g_bastion"),
		hero.grid_pos,
	)
	_check(
		not report.get("failed", false),
		"Real Bastion cast succeeds: " + str(report.get("reason", "ok")),
	)
	_check(hero.current_ap == ap - 3, "Bastion spends its actual three AP")
	_check(hero.get_shield_value(Bastion.SOURCE_ID) > 0, "Protection exists immediately at grant")
	_check(router.holds.size() == 1, "One active protection sign")
	return {
		"variant": "v1" if legacy else "v2",
		"shield": hero.current_shield,
		"ap": ap - hero.current_ap,
	}


func _hit(amount: int) -> void:
	# Controlled incoming hit, resolved by the real Unit shield transaction.
	var ctx := DamageResolver.HitContext.new()
	ctx.raw_damage = amount
	ctx.ignore_defense = true
	ctx.cannot_be_dodged = true
	ctx.guard_damage_multiplier = hero.get_guard_effectiveness(&"")
	ctx.ability_id = &"bastion_review_hit"
	var before := hero.current_hp
	var result := hero.take_hit(ctx)
	_check(result.shield_damage_absorbed == amount, "Incoming hit is paid by the actual shield")
	_check(hero.current_hp == before, "A fully absorbed hit does not change HP")
	router._process(.2)


func _replay(legacy: bool, expiry := false) -> void:
	if busy:
		return
	busy = true
	for button in buttons:
		button.disabled = true
	_grant(legacy)
	heading.text = "Bastion vivant · " + ("V1 cel" if legacy else "Blender · remparts articulés")
	clock_label.text = "Protection réelle : %d · 3 PA · IA suspendue" % hero.current_shield
	await get_tree().create_timer(1.75).timeout
	if expiry:
		hero.start_turn()
		router._process(.2)
		clock_label.text = "Activation suivante du porteur : expiration réelle de Bastion"
	else:
		_hit(8)
		clock_label.text = "Coup absorbé · protection restante : %d" % hero.current_shield
		await get_tree().create_timer(.6).timeout
		_hit(hero.current_shield)
		clock_label.text = "Protection épuisée par le coup suivant : rupture"
	await get_tree().create_timer(.65).timeout
	for button in buttons:
		button.disabled = false
	busy = false


func _sample(time: float) -> void:
	for fx in router.effects:
		if not is_instance_valid(fx) or fx.closed:
			continue
		if not births.has(fx):
			births[fx] = time
		fx.manual = true
		fx.sample(time - float(births[fx]))
		if not fx.persistent and time - float(births[fx]) >= fx.duration:
			fx.cancel()


func _sequence(legacy: bool) -> void:
	var variant := "v1" if legacy else "v2"
	births.clear()
	casts.append(_grant(legacy))
	var shield_before := hero.current_shield
	DirAccess.make_dir_recursive_absolute(output_path + variant)
	for frame in 90:
		var time := frame / 30.0
		if frame == 48:
			_check(
				hero.current_shield == shield_before,
				"Animation seconds preserve the guard duration",
			)
			_hit(8)
		if frame == 66:
			_hit(hero.current_shield)
			_check(
				hero.current_shield == 0 and router.holds.is_empty(),
				"Actual depletion removes the active sign",
			)
		_sample(time)
		heading.text = "Bastion vivant · " + (
			"V1 cel" if legacy else "Blender · remparts articulés"
		)
		clock_label.text = "%.2f s · %s · Garde : %d" % [
			time,
			"déploiement" if frame < 48 else "absorption" if frame < 66 else "rupture",
			hero.current_shield,
		]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(
			get_viewport().get_texture().get_image().save_png(
				output_path + variant + "/%03d.png" % frame
			) == OK,
			variant + " frame %d" % frame,
		)
		captured_frames += 1
		if frame in [12, 24, 45, 51, 70, 88]:
			await _capture(variant + "_%d" % frame)
	_check(
		casts[0].shield == casts[-1].shield and casts[0].ap == casts[-1].ap,
		"V1/V2 preserve grant and cost",
	)


func _expiry_checks() -> void:
	births.clear()
	_grant(false)
	_sample(0)
	_sample(.4)
	battle.camera.zoom = normal_zoom
	clock_label.text = "Échelle de combat · protection confirmée"
	await _capture("normal_deployment")
	battle.camera.zoom = normal_zoom * 2.4
	_sample(1.6)
	# Expire just Bastion while another shield source remains.
	hero.add_sourced_shield(&"bastion_probe_other", 7)
	hero.start_turn()
	router._process(.2)
	_check(
		hero.get_shield_value(Bastion.SOURCE_ID) == 0 and hero.current_shield == 7,
		"Bastion expires independently of another shield",
	)
	var key := "%s:shield" % hero.get_instance_id()
	_check(
		router.holds.has(key) and not router.holds[key].fx is Bastion,
		"Remaining shield returns to the generic sign",
	)
	_sample(1.72)
	clock_label.text = "Bastion expiré · une autre source de garde reste active"
	await _capture("source_expiry")
	_grant(false)
	router.clear()
	router._restore_unit_holds()
	_check(
		router.holds.size() == 1 and router.holds[key].fx is Bastion,
		"Restored Bastion has its sign without another deployment",
	)
	var effects_count: int = router.effects.size()
	hero.current_ap = 0
	var failed: Dictionary = battle.spell_caster.cast(
		hero,
		Cards.make_spell("g_bastion"),
		hero.grid_pos,
	)
	_check(
		failed.get("failed", false) and router.effects.size() == effects_count,
		"Rejected cast has no deployment",
	)
	# Several real states occupy the same rail; shield remains one slot.
	var target_home := target.grid_pos
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var melee_cell: Vector2i = hero.grid_pos + direction
		if battle.grid.is_walkable(melee_cell) and not battle.grid.has_unit(melee_cell):
			_move(target, melee_cell)
			break
	for id in ["a_open", "a_cut", "t_burn", "g_prison", "t_disrupt"]:
		hero.current_ap = hero.max_ap.get_int()
		target.current_hp = target.max_hp.get_int()
		session.cards.hand.assign([session.cards.add_copy(id)])
		var state_cast: Dictionary = battle.spell_caster.cast(
			hero,
			Cards.make_spell(id),
			target.grid_pos,
		)
		_check(
			not state_cast.get("failed", false),
			"State fixture cast " + id + ": " + str(state_cast.get("reason", "ok")),
		)
	_move(target, target_home)
	# Reuse the actual applied status resources to load the protected actor's rail too.
	for state in target.get_active_statuses():
		hero.apply_status(state.data, target)
	_check(
		router.holds.values().filter(
			func(held):
				return held.unit == hero,
		).size()
		>= 6,
		"Bastion shares one compact rail with five actual states",
	)
	await get_tree().create_timer(1.5).timeout
	clock_label.text = "États réels en rangée compacte · aucun empilement de remparts"
	await _capture("status_rail")


func _production_command() -> void:
	# Use the same public Battle input boundary as a played card.
	for state in hero.get_active_statuses().duplicate():
		hero.remove_status(state.data.get_effective_status_id())
	hero.start_turn()
	battle.turn_queue = TurnQueue.new()
	battle._setup_state()
	hero.initiative.base_value = 1000
	battle.turn_queue.setup([hero, target])
	battle.turn_queue.advance()
	battle.presentation_state.clear_locks()
	battle.presentation_state.begin_player_turn()
	hero.clear_shield()
	hero.current_ap = hero.max_ap.get_int()
	session.cards.hand.assign([session.cards.add_copy("g_bastion")])
	router.clear()
	var ap := hero.current_ap
	battle._on_request_cast_spell(Cards.make_spell("g_bastion"), hero.grid_pos)
	var deadline := Time.get_ticks_msec() + 4000
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not battle._spell_resolution_pending, "Public Battle command releases input")
	_check(
		hero.current_ap == ap - 3 and hero.get_shield_value(Bastion.SOURCE_ID) > 0,
		"Public Battle command commits one payment and protection",
	)
	clock_label.text = "Commande normale du combat · Bastion confirmé"
	await _capture("production_command")


func _receipt_and_resume() -> void:
	var guard_before := hero.current_shield
	for child in get_children():
		if child is CanvasLayer:
			child.hide()
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	_check(
		router.effects.is_empty() and router.holds.is_empty(),
		"Shutdown frees panels and active signs",
	)
	_check(hero.current_shield == guard_before, "Visual shutdown never consumes guard")
	GameManager._combat_report_tracker.discard()
	_check(session.combat_won(), "Fixture victory reaches Cards receipt")
	var checkpoint := "user://bastion_cards_journey.json"
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
			router.holds.is_empty() and router.effects.is_empty() and not router.is_card_battle(),
			"No Bastion survives receipt and resume",
		)
		screen.queue_free()
		get_tree().current_scene = null
		await get_tree().process_frame
	ExpeditionSaveService.remove_snapshot(checkpoint)
