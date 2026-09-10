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
	for id: String in ["strike", "dash", "shot", "guard", "sweep", "bash"]:
		lab.reset_lab()
		assert(lab.cast_action(id), "Cast must start")
		for i in range(360):
			lab.advance(1.0 / 240.0)
			lab._update_sprite()
		assert(lab.release_count == 1, "One release per action")
		assert(lab.active.is_empty(), "Action must finish")
		if id in ["strike", "shot", "sweep", "bash"]:
			assert(lab.hit_count == 1, "Front target must receive one hit")
		else:
			assert(lab.hit_count == 0, "Dash and guard must not deal damage")
		if id == "dash":
			assert(lab.actor_position.x > 325 and lab.actor_position.x <= 420, "Dash collision")
	print("PASSE_RIVE_NATIVE_OK: 6 actions, single releases, hit timing, recovery, dash collision")
	quit(0)
