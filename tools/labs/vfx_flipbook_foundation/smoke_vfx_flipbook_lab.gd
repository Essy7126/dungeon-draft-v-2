extends SceneTree

const LAB_SCENE := preload("res://tools/labs/vfx_flipbook_foundation/VFXFlipbookFoundationLab.tscn")
const WATCHDOG_SECONDS := 15.0

var _finished := false


func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_arm_watchdog")


func _arm_watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	push_error("VFX_FLIPBOOK_LAUNCHER_SMOKE_FAIL watchdog timeout")
	quit(1)


func _run() -> void:
	var lab: VFXFlipbookFoundationLab = LAB_SCENE.instantiate() as VFXFlipbookFoundationLab
	get_root().add_child(lab)
	await process_frame
	await process_frame
	lab.clear()
	lab.play()
	await create_timer(0.08).timeout
	if lab.current_instances.is_empty() or lab.current_instances[0].elapsed <= 0.0:
		_fail("Play n'a pas avancé l'animation.", lab)
		return
	lab.pause()
	var paused_elapsed: float = lab.current_instances[0].elapsed
	await create_timer(0.05).timeout
	if not is_equal_approx(lab.current_instances[0].elapsed, paused_elapsed):
		_fail("Pause n'a pas suspendu l'animation.", lab)
		return
	lab.resume()
	await create_timer(0.05).timeout
	if lab.current_instances[0].elapsed <= paused_elapsed:
		_fail("Resume n'a pas repris l'animation.", lab)
		return
	lab.scrub_to(0.25)
	var snapshot := lab.inspection_snapshot()
	if snapshot.visuals.is_empty() or int(snapshot.visuals[0].frame) != 8:
		_fail("Le scrub absolu à 25 % n'a pas produit la frame 8.", lab)
		return
	lab.clear()
	if not lab.current_instances.is_empty() or lab.vfx_layer.get_child_count() != 0:
		_fail("Clear a laissé un résidu VFX.", lab)
		return
	lab.free()
	_finished = true
	print("VFX_FLIPBOOK_LAUNCHER_SMOKE_PASS frame=8 residual=0")
	quit(0)


func _fail(message: String, lab: Node) -> void:
	_finished = true
	push_error("VFX_FLIPBOOK_LAUNCHER_SMOKE_FAIL %s" % message)
	if is_instance_valid(lab):
		lab.free()
	quit(1)
