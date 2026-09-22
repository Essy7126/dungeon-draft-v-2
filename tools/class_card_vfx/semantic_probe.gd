extends "combat_probe.gd"
## Reproducible real casts, native pixels, independently sampled presentation time.
const PILOTS := ["a_dagger", "t_burn", "t_flamewall", "t_glacier"]
const NOTES := [
	"Impact dirigé · 0,32 s · traînée au moment du coup confirmé",
	"Ignition · 0,68 s · braises maintenues pendant l'état réel",
	"Croix de feu · 2 tours de terrain · dégâts au début du tour",
	"Croix de givre · 2 tours de terrain · malus de PM à l'entrée",
]
var heading: Label
var caption: Label
var clock_label: Label


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/semantics/"
	pair_distance = 2
	captured_frames = 240


func _exercise() -> void:
	_overlay()
	var normal_zoom: Vector2 = battle.camera.zoom / 2.4
	for index in PILOTS.size():
		var id: String = PILOTS[index]
		heading.text = Cards.row(id)[2]
		caption.text = NOTES[index]
		DirAccess.make_dir_recursive_absolute(output_path + id)
		_cast(id, target.grid_pos)
		var frozen := _state()
		var terrain_cells: Array = battle.terrain_effects.active_surface_cells()
		_check(
			not router.effects.is_empty() or not router.surface_holds.is_empty(),
			id + " creates visible presentation",
		)
		if id in ["t_flamewall", "t_glacier"]:
			_check(
				router.surface_holds.size() == terrain_cells.size(),
				id + " covers only actual surface cells",
			)
		for frame in 60:
			var seconds := frame / 30.0
			clock_label.text = "Lecture VFX · %.2f s   |   Caméra ×2,4 · IA suspendue" % seconds
			_sample_all(seconds)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(
				output_path + id + "/%03d.png" % frame
			)
			if result != OK:
				_check(false, "Frame save failed: " + id)
		_check(_state() == frozen, id + " visual playback preserves HP and status duration")
		if not router.surface_holds.is_empty():
			_check(_ground_order_correct(), id + " ground remains above its base tile")
		# A second view checks how much survives at the actual combat camera scale.
		battle.camera.zoom = normal_zoom
		_sample_all(.09 if id == "a_dagger" else .8)
		clock_label.text = "Échelle de combat · IA suspendue"
		await _capture(id + "_normal")
		battle.camera.zoom = normal_zoom * 2.4
		if id == "t_burn":
			var hp_before := target.current_hp
			var prior: Array = router.effects.duplicate()
			target.process_statuses()
			_check(target.current_hp < hp_before, "Burn tick comes from actual status damage")
			clock_label.text = "Contrôle : dégâts périodiques réels · début du tour de la cible"
			_sample_new_tick(prior)
			await _capture(id + "_tick")
			target.tick_statuses()
			_check(target.has_status(&"class_burn"), "Burn remains after its first status turn")
			target.tick_statuses()
			_check(router.holds.is_empty(), "Burn hold ends on actual duration expiry")
		elif id == "t_flamewall":
			var hp_before := target.current_hp
			var prior: Array = router.effects.duplicate()
			battle.terrain_effects.on_turn_start(target)
			_check(
				target.current_hp < hp_before,
				"Fire-ground tick comes from actual terrain damage",
			)
			clock_label.text = "Contrôle : dégâts du sol réels · début du tour de la cible"
			_sample_new_tick(prior)
			await _capture(id + "_tick")
		if id in ["t_flamewall", "t_glacier"]:
			battle.terrain_effects.tick_all_effects()
			_check(not router.surface_holds.is_empty(), id + " remains after one terrain round")
			battle.terrain_effects.tick_all_effects()
			_check(router.surface_holds.is_empty(), id + " expires after two terrain rounds")
		for state in target.get_active_statuses().duplicate():
			target.remove_status(state.data.get_effective_status_id())
		for cell in terrain_cells:
			battle.terrain_effects.clear_effect(cell)
		_check(
			router.holds.is_empty() and router.surface_holds.is_empty(),
			id + " removes durable visuals with real state",
		)
		# Let authored outros finish, then start the next isolated cast.
		for fx in router.ground_effects:
			if is_instance_valid(fx):
				fx.manual = false
		for fx in router.effects:
			if is_instance_valid(fx):
				fx.manual = false
		for fx in router.echoes:
			if is_instance_valid(fx):
				fx.manual = false
		await get_tree().create_timer(.8).timeout
		await _capture(id + "_expired")
	_finish()


func _sample_new_tick(prior: Array) -> void:
	# Preserve already-finished impacts and established ground. Only the newly
	# emitted tick is sampled near its peak; rewinding the cast would fake a double hit.
	for fx in router.effects:
		if is_instance_valid(fx) and fx not in prior:
			fx.manual = true
			fx.sample(.12)


func _sample_all(seconds: float) -> void:
	for fx in router.effects:
		if is_instance_valid(fx) and not fx.closed:
			fx.manual = true
			fx.sample(seconds)
	for fx in router.ground_effects:
		if is_instance_valid(fx) and not fx.closed:
			fx.manual = true
			fx.sample(seconds)
	for fx in router.echoes:
		if is_instance_valid(fx) and not fx.closed:
			fx.manual = true
			fx.sample(seconds)


func _overlay() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(.018, .035, .044, .92)
	panel.position = Vector2(32, 30)
	panel.size = Vector2(1040, 138)
	canvas.add_child(panel)
	heading = Label.new()
	heading.position = Vector2(56, 43)
	heading.add_theme_font_size_override("font_size", 30)
	canvas.add_child(heading)
	caption = Label.new()
	caption.position = Vector2(56, 90)
	caption.add_theme_font_size_override("font_size", 20)
	canvas.add_child(caption)
	clock_label = Label.new()
	clock_label.position = Vector2(56, 127)
	clock_label.add_theme_font_size_override("font_size", 15)
	canvas.add_child(clock_label)
