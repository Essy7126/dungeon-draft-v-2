extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var scene := load("res://PasseRiveLab.tscn") as PackedScene
	if scene == null:
		push_error("Missing laboratory scene")
		quit(1)
		return
	var lab := scene.instantiate()
	root.add_child(lab)
	await process_frame
	lab.set_process(false)
	if lab.actor.sprite_frames == null or not lab.actor.sprite_frames.has_animation(&"fauche"):
		push_error("Missing Fauche animation; import the standalone project before running smoke")
		quit(1)
		return
	for id: String in [
		"strike",
		"dash",
		"shot",
		"guard",
		"sweep",
		"bash",
		"sky_bow",
		"ivory_bow",
		"vital_harvest",
		"fauche",
	]:
		lab.reset_lab()
		assert(lab.cast_action(id), "Cast must start")
		for i in range(570):
			lab.advance(1.0 / 240.0)
			lab._update_sprite()
		assert(lab.release_count == 1, "One release per action")
		assert(lab.active.is_empty(), "Action must finish")
		if id in [
			"strike",
			"shot",
			"sweep",
			"bash",
			"sky_bow",
			"ivory_bow",
			"vital_harvest",
			"fauche",
		]:
			assert(lab.hit_count == 1, "Front target must receive one hit")
		else:
			assert(lab.hit_count == 0, "Dash and guard must not deal damage")
		if id == "dash":
			assert(lab.actor_position.x > 325 and lab.actor_position.x <= 420, "Dash collision")
	lab.reset_lab()
	lab.cast_action("sky_bow")
	for i in range(80):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(lab.actor.frame == 2 and lab.release_count == 0, "Bow full draw before release")
	for i in range(55):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(
		lab.actor.frame == 3 and lab.lofted_arrows.size() == 1,
		"Bow release frame and arrow synchronized",
	)
	for i in range(250):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(lab.actor.animation == &"sky_bow_idle", "Keep the bow after shooting")
	assert(lab.targets[2].hp == 72, "Lofted arrow hits the far target once")
	lab.reset_lab()
	lab.cast_action("ivory_bow")
	for i in range(360):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(
		lab.actor.frame == 3 and lab.release_count == 0 and lab.charged_arrows.is_empty(),
		"Hold the ivory charge without early release",
	)
	assert(lab.actor_position == Vector2(325, 425), "Charge must keep the actor planted")
	assert(
		absf(float(lab.tremor_material.get_shader_parameter("tremor_pixels"))) > 0.01,
		"Localized charge tremor is active",
	)
	for i in range(30):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(
		lab.actor.frame == 4 and lab.release_count == 1 and lab.charged_arrows.size() == 1,
		"Ivory arrow synchronized with release",
	)
	assert(
		is_zero_approx(float(lab.tremor_material.get_shader_parameter("tremor_pixels"))),
		"Tremor stops at release",
	)
	for i in range(150):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(
		lab.targets[0].hp == 48 and lab.hit_count == 1,
		"Fast arrow damages front target exactly once",
	)
	assert(lab.actor.animation == &"ivory_bow_idle", "Return to bronze bow idle")
	lab.reset_lab()
	lab.cast_action("vital_harvest")
	for i in range(144):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(
		lab.actor.frame == 2 and lab.release_count == 0 and lab.vital_projectiles.is_empty(),
		"Vital charge without early emission",
	)
	assert(lab.actor_position == Vector2(325, 425), "Levitation is visual and keeps ground anchor")
	assert(lab.actor.position.y < 425 - 662 * 0.55 - 17, "Sprite floats above ground")
	lab.fx_enabled = false
	for i in range(6):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(
		lab.actor.frame == 3 and lab.vital_projectiles.size() == 1 and lab.release_count == 1,
		"Chest emission and pose synchronized",
	)
	var energy: Dictionary = lab.vital_projectiles[0]
	var chest: Array = lab.active.spell.vfx.chest[3]
	var expected := Vector2(325, 425) + (Vector2(chest[0], chest[1]) - Vector2(320, 696)) * 0.55
	assert(
		Vector2(energy.start).distance_to(expected) < 0.1,
		"Red impulse starts at elevated chest",
	)
	for i in range(174):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(lab.targets[0].hp == 66 and lab.hit_count == 1, "Vital hit works with effects disabled")
	assert(lab.actor.animation == &"vital_harvest_idle", "Land without a weapon")
	assert(is_equal_approx(lab.actor.position.y, 425 - 662 * 0.55), "Sprite returns to ground")
	lab.reset_lab()
	assert(
		lab.vital_projectiles.is_empty() and lab.vital_bursts.is_empty(),
		"Reset clears vital effects",
	)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_0
	key.pressed = true
	lab._unhandled_key_input(key)
	assert(lab.active.spell.id == "fauche", "Key 0 starts the tenth action")
	for i in range(71):
		lab.advance(1.0 / 240.0)
	assert(lab.release_count == 0, "Fauche must not strike during anticipation")
	for i in range(2):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(lab.actor.frame == 3 and lab.hit_count == 1, "Fauche impact on the strike pose")
	assert(
		lab.actor.sprite_frames.get_frame_texture(&"fauche", 3).get_width() == 1152,
		"Entire spear fits enlarged atlas cell",
	)
	assert(lab.actor_position == Vector2(325, 425), "Fauche keeps ground root planted")
	assert(
		lab.actor.position == Vector2(325, 425) - Vector2(576, 662) * 0.55,
		"Action-specific pivot",
	)
	assert(
		lab.fauche_back.get_index() < lab.actor.get_index()
		and lab.fauche_front.get_index() > lab.actor.get_index(),
		"Wake wraps behind and in front of body",
	)
	for i in range(160):
		lab.advance(1.0 / 240.0)
	lab._update_sprite()
	assert(
		lab.actor.animation == &"fauche_idle" and lab.hit_count == 1,
		"Fauche settles without duplicate impact",
	)
	assert(
		lab.actor.position == Vector2(325, 425) - Vector2(576, 662) * 0.55,
		"No pivot jump on recovery",
	)
	print(
		"PASSE_RIVE_NATIVE_OK: 10 actions, Fauche key 0 and 300 ms hit, wide atlas, stable pivot, layered trail; vital and bow regressions passed"
	)
	quit(0)
