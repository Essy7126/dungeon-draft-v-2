extends "res://tools/class_card_vfx/combat_probe.gd"
## Isolated Studio battle. Uses Battle's real request/release/resolve/recovery path.
const S19 := preload("res://characters/achilles/2d/passe_rive_s19_catalog.gd")
var capture_mode := false
var busy := false
var mirrored := false
var label: Label
var buttons: Array[Button] = []
var sample_names: Array[String] = []
var captured_release := false
var initial_hp := 0
var hp_before_release := true
var last_report: Dictionary = {}
var release_state: Dictionary = {}
var current_card := ""


func _ready() -> void:
	hero_variants = {"achilles": "passe_rive"}
	pair_distance = 2
	output_path = "res://artifacts/dev/passe_rive_s19/"
	capture_mode = "--s19-capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--s19-output="):
			output_path = arg.trim_prefix("--s19-output=").replace("\\", "/") + "/"
	super._ready()


func _exercise() -> void:
	battle._setup_state()
	battle.turn_queue = TurnQueue.new()
	battle.turn_queue.setup([hero])
	battle.turn_queue.start()
	battle.presentation_state.set_lock(&"battle_not_started", false)
	battle.turn_state.begin_player_turn()
	EventBus.action_resolved.connect(_resolved)
	var visual: Node = battle._unit_views[hero]._optional_visual
	_check(visual is PasseRiveAutoSpriteView and visual.uses_s19_cards(), "Real Cards battle selects S19 Passe-Rive")
	visual.cast_release_reached.connect(_release)
	_build_ui()
	if not capture_mode:
		label.text = "Choisis une carte. Impacts et dégâts réels ; cibles et PA réinitialisés pour l’essai."
		return
	for id in S19.Data.CARDS:
		await _play_card(id)
	for id in S19.ALIASES:
		await _play_card(id, false)
	mirrored = true
	await _play_card("a_dagger")
	# Actual status removal owns the hold, never a visual timeout.
	mirrored = false
	await _play_card("t_mark", false)
	var key := "%s:class_marked" % target.get_instance_id()
	_check(router.holds.has(key), "S19 mark persists after recovery")
	if router.holds.has(key):
		_check(router.holds[key].fx is preload("res://vfx/class_cards/passe_rive_s19_effect.gd"), "Actual mark owns S19 badge")
	await _capture("mark_held")
	target.remove_status(&"class_marked")
	await get_tree().create_timer(0.5).timeout
	_check(not router.holds.has(key), "Status removal removes S19 hold")
	await _capture("mark_removed")
	_finish()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(270, 600)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PASSE-RIVE · EN COMBAT"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	for id in S19.Data.CARDS:
		var button := Button.new()
		button.text = S19.Data.CARDS[id].title
		button.custom_minimum_size = Vector2(260, 43)
		button.pressed.connect(func(): _play_card(id))
		buttons.append(button)
		box.add_child(button)
	var flip := Button.new()
	flip.text = "Inverser la direction"
	flip.pressed.connect(func(): mirrored = not mirrored)
	box.add_child(flip)
	var remove := Button.new()
	remove.text = "Retirer le sceau"
	remove.pressed.connect(func(): target.remove_status(&"class_marked"))
	box.add_child(remove)
	var speed := Button.new()
	speed.text = "Vitesse ×1 / ×0,5"
	speed.pressed.connect(func(): Engine.time_scale = 0.5 if Engine.time_scale == 1.0 else 1.0)
	box.add_child(speed)
	label = Label.new()
	label.custom_minimum_size = Vector2(260, 100)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)


func _position_pair(distance: int) -> bool:
	for cell in _central_cells():
		var other: Vector2i = cell + Vector2i(-distance if mirrored else distance, 0)
		var free_a: bool = not battle.grid.has_unit(cell) or cell in [hero.grid_pos, target.grid_pos]
		var free_b: bool = not battle.grid.has_unit(other) or other in [hero.grid_pos, target.grid_pos]
		if battle.grid.is_walkable(cell) and battle.grid.is_walkable(other) and free_a and free_b and cell != target.grid_pos and other != hero.grid_pos:
			_move(hero, cell)
			_move(target, other)
			battle.camera.global_position = (battle._unit_views[hero].global_position + battle._unit_views[target].global_position) * 0.5 + Vector2(-40, -45)
			return true
	return false


func _play_card(id: String, capture := true) -> void:
	if busy:
		return
	busy = true
	for button in buttons:
		button.disabled = true
	current_card = id
	var card := S19.card(id)
	var spell := Cards.make_spell(id)
	_check(_position_pair(maxi(1, spell.min_range)), "Legal range for " + id)
	for unit: Unit in battle.units:
		unit.current_hp = unit.max_hp.get_int()
		unit.esquive.base_value = 0
	hero.current_ap = hero.max_ap.get_int()
	session.cards.hand.assign([session.cards.add_copy(id)])
	last_report = {}
	release_state = {}
	captured_release = false
	hp_before_release = true
	initial_hp = target.current_hp
	label.text = card.title + "\nPréparation…"
	var suffix := "_left" if mirrored else ""
	var visual: Node = battle._unit_views[hero]._optional_visual
	var backend: Node = visual.sprite_backend
	# This is exactly the production player's cast request, including its locks.
	battle._on_request_cast_spell(spell, target.grid_pos)
	var deadline := Time.get_ticks_msec() + 10000
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		if not captured_release and target.current_hp != initial_hp:
			hp_before_release = false
		if capture_mode and capture:
			var time: float = backend._action_elapsed
			if time >= float(card.confirm_ms) / 1000.0 - 0.12 and time < float(card.confirm_ms) / 1000.0:
				await _capture_once(id + suffix + "_anticipation")
			if captured_release and time >= float(card.confirm_ms) / 1000.0 + 0.075:
				await _capture_once(id + suffix + "_contact")
		await get_tree().process_frame
	_check(not battle._spell_resolution_pending, id + " recovery unlocks actual battle")
	_check(hp_before_release, id + " no damage before release")
	_check(not last_report.is_empty() and not last_report.get("failed", false), id + " resolves through Battle")
	_check(release_state.get("animation", "") == card.clip and release_state.get("frame", -1) == int(card.confirm_frame), id + " exact release pose in production")
	_check(backend.body.current_clip == "PR_IDLE", id + " returns to S18 guard")
	var authored_fx := 0
	for fx in router.effects:
		if is_instance_valid(fx) and fx.recipe.get("s19_card", "") == card.id:
			authored_fx += 1
	# Some short contacts are already over at recovery; record them at release instead.
	casts.append({"id": id, "mirrored": mirrored, "release": release_state, "report": _compact_report(), "hp_before_release": hp_before_release})
	label.text = card.title + "\n" + str(initial_hp - target.current_hp) + " dégâts · retour en garde\n" + ("Sceau actif : 1 activation" if target.has_status(&"class_marked") else "")
	await get_tree().create_timer(0.3).timeout
	if capture_mode and capture:
		await _capture_once(id + suffix + "_recovery")
	busy = false
	for button in buttons:
		button.disabled = false


func _release() -> void:
	if busy:
		captured_release = true
		release_state = battle._unit_views[hero]._optional_visual.sprite_backend.get_runtime_state()
		label.text = S19.card(current_card).title + "\nContact confirmé par le moteur…"


func _resolved(unit: Unit, _action_id: StringName, kind: StringName, report: Dictionary) -> void:
	if unit == hero and kind == &"spell":
		last_report = report


func _compact_report() -> Dictionary:
	return {"failed": last_report.get("failed", true), "impact_cells": last_report.get("visual_impact_cells", []), "ap_before": last_report.get("ap_before", -1), "ap_after": last_report.get("ap_after", -1)}


func _capture_once(id: String) -> void:
	if id not in sample_names:
		sample_names.append(id)
		await _capture(id)
