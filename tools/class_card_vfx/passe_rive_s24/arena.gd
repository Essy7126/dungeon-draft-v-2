extends "res://tools/class_card_vfx/combat_probe.gd"
## Real card request; only this Studio fixture opts into the single-facing prototype.
const KickBackend := preload("res://tools/class_card_vfx/passe_rive_s24/kick_backend.gd")
const HeelContact := preload("res://tools/class_card_vfx/passe_rive_s24/heel_contact.gd")
var capture_mode := false
var busy := false
var recording := false
var movie: Array[Image] = []
var samples: Array[Dictionary] = []
var pictures: Dictionary = { }
var release_state: Dictionary = { }
var last_report: Dictionary = { }
var releases := 0
var label: Label
var play_button: Button
var visual: Node
var original_cell: Vector2i
var original_target: Vector2i
var hp_before := 0
var no_early_effect := true


func _ready() -> void:
	hero_variants = { "achilles": "passe_rive" }
	output_path = "res://artifacts/dev/passe_rive_s24/"
	capture_mode = "--s24-capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--s24-output="):
			output_path = arg.trim_prefix("--s24-output=").replace("\\", "/") + "/"
	super._ready()


func _exercise() -> void:
	get_window().title = "Passe-Rive — Coup de talon haut · animatique B"
	battle._setup_state()
	battle.turn_queue = TurnQueue.new()
	battle.turn_queue.setup([hero])
	battle.turn_queue.start()
	battle.presentation_state.set_lock(&"battle_not_started", false)
	battle.turn_state.begin_player_turn()
	if not EventBus.unit_pushed.is_connected(battle._on_unit_pushed):
		EventBus.unit_pushed.connect(battle._on_unit_pushed)
	EventBus.action_resolved.connect(_resolved)
	EventBus.spell_cast.connect(_contact)
	visual = battle._unit_views[hero]._optional_visual
	_setup_review_backend()
	visual.cast_release_reached.connect(_release)
	_build_ui()
	_check(_position_pair(), "Three free SE cells for melee contact and one-cell push")
	visual.set_facing(Vector2i.RIGHT)
	visual.play_idle()
	await get_tree().create_timer(1.8).timeout
	print("PASSE_RIVE_S24_READY")
	if capture_mode:
		await _play_kick()
		_finish()


func _setup_review_backend() -> void:
	var old: Node = visual.sprite_backend
	old.set_backend_active(false)
	old.shutdown()
	old.queue_free()
	visual.sprite_backend = null
	visual._active_backend = null
	visual.sprite_profile = visual.sprite_profile.duplicate()
	visual.sprite_profile.backend_script = KickBackend
	visual._initialize_sprite_backend()
	visual._sync_cards_mode()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	label = Label.new()
	label.text = "COUP DE TALON HAUT · PROTOTYPE B\nChassé de profil · direction SE\n1 PA · repousse d’une case"
	box.add_child(label)
	play_button = Button.new()
	play_button.text = "Jouer le coup de talon"
	play_button.custom_minimum_size = Vector2(320, 48)
	play_button.pressed.connect(_play_kick)
	box.add_child(play_button)
	var speed := Button.new()
	speed.text = "Vitesse ×1 / ×0,5"
	speed.pressed.connect(
		func():
			Engine.time_scale = 0.5 if Engine.time_scale == 1.0 else 1.0,
	)
	box.add_child(speed)
	var note := Label.new()
	note.text = "Animatique : 8 poses · 0,65 s\nDirection unique à valider avant production."
	box.add_child(note)


func _position_pair() -> bool:
	for cell in _central_cells():
		var valid := true
		for offset in 3:
			var at: Vector2i = cell + Vector2i.RIGHT * offset
			valid = (
				valid and battle.grid.is_walkable(at)
				and (not battle.grid.has_unit(at) or at in [hero.grid_pos, target.grid_pos])
			)
		if valid and cell != target.grid_pos and cell + Vector2i.RIGHT != hero.grid_pos:
			_move(hero, cell)
			_move(target, cell + Vector2i.RIGHT)
			for unit in [hero, target]:
				battle._unit_views[unit].synchronize_external_movement()
			battle.camera.global_position = battle._unit_views[hero].global_position + Vector2(
				55,
				-45,
			)
			return true
	return false


func _play_kick() -> void:
	if busy:
		return
	busy = true
	play_button.disabled = true
	_check(_position_pair(), "Legal cast lane")
	visual.set_facing(Vector2i.RIGHT)
	visual.play_idle()
	for unit: Unit in battle.units:
		unit.current_hp = unit.max_hp.get_int()
		unit.esquive.base_value = 0
	hero.current_ap = hero.max_ap.get_int()
	var ap_before := hero.current_ap
	session.cards.hand.assign([session.cards.add_copy("a_push")])
	original_cell = hero.grid_pos
	original_target = target.grid_pos
	hp_before = target.current_hp
	releases = 0
	release_state = { }
	last_report = { }
	no_early_effect = true
	var spell := Cards.make_spell("a_push")
	_check(battle.spell_caster.get_cast_failure_reason(hero, spell, target.grid_pos) == &"", "Real Coup de talon is legal")
	label.text = "COUP DE TALON · B\nPréparation → talon → retour"
	recording = capture_mode
	await get_tree().create_timer(0.3).timeout
	battle._on_request_cast_spell(spell, target.grid_pos)
	var deadline := Time.get_ticks_msec() + 10000
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		if releases == 0:
			no_early_effect = (
				no_early_effect and target.current_hp == hp_before
				and target.grid_pos == original_target
			)
		await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	recording = false
	_check(not battle._spell_resolution_pending, "Battle unlocks after recovery")
	_check(no_early_effect, "No damage or displacement before heel release")
	_check(releases == 1, "Exactly one release")
	_check(
		release_state.get("animation") == KickBackend.KICK and release_state.get("frame") == 4,
		"Heel contact pose owns release",
	)
	_check(
		not last_report.is_empty() and not last_report.get("failed", false),
		"Real Battle resolves card",
	)
	_check(hero.current_ap == ap_before - 1, "One AP consumed")
	_check(hero.grid_pos == original_cell, "Caster remains on original cell")
	_check(target.grid_pos == original_target + Vector2i.RIGHT, "Target pushed exactly one cell")
	_check(target.current_hp < hp_before, "Target receives actual card damage")
	_check(
		str(visual.sprite_backend.get_runtime_state().animation).begins_with("idle_")
		and not visual.sprite_backend.kick.visible,
		"Returns to native unarmed idle",
	)
	casts.append(
		{
			"id": "a_push",
			"release": release_state,
			"hero": str(hero.grid_pos),
			"target": str(target.grid_pos),
			"damage": hp_before - target.current_hp,
			"ap_spent": ap_before - hero.current_ap,
		}
	)
	label.text = "COUP DE TALON · B\n%d dégâts · recul d’une case\nRetour au repos" % (
		hp_before - target.current_hp
	)
	busy = false
	play_button.disabled = false


func _release() -> void:
	if busy:
		releases += 1
		release_state = visual.sprite_backend.get_runtime_state()


func _resolved(unit: Unit, _action: StringName, kind: StringName, report: Dictionary) -> void:
	if unit == hero and kind == &"spell":
		last_report = report


func _contact(caster: Unit, spell: Spell, report: Dictionary) -> void:
	if caster != hero or spell.spell_id != &"class_a_push" or report.get("failed", false):
		return
	# This scene replaces only the oversized stock gust, after a confirmed hit.
	# The production router, source art and all combat rules stay unchanged.
	for effect in router.effects:
		if is_instance_valid(effect) and not effect.closed and effect.recipe.get("id") == "a_push":
			effect.cancel()
	if report.get("damaged_enemies", []).is_empty():
		return
	var accent := HeelContact.new()
	visual.sprite_backend.add_child(accent)
	accent.position = visual.sprite_backend.get_vfx_origin()
	accent.z_index = 3


func _process(_delta: float) -> void:
	if not recording:
		return
	await RenderingServer.frame_post_draw
	if not recording:
		return
	movie.append(get_viewport().get_texture().get_image())
	samples.append(
		{
			"time_ms": Time.get_ticks_msec(),
			"state": visual.sprite_backend.get_runtime_state(),
			"target_cell": str(target.grid_pos),
			"target_world": str(battle._unit_views[target].position),
		}
	)


func _capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	pictures[id] = get_viewport().get_texture().get_image()


func _finish() -> void:
	for id in pictures:
		pictures[id].save_png(output_path + id + ".png")
	for i in movie.size():
		_check(movie[i].save_png(output_path + "frames/%04d.png" % i) == OK, "Capture %d" % i)
	captured_frames = movie.size() + pictures.size()
	FileAccess.open(output_path + "samples.json", FileAccess.WRITE).store_string(
		JSON.stringify(samples, "\t")
	)
	movie.clear()
	super._finish()
