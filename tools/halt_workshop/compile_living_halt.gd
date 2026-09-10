extends SceneTree
## Load the verifier in normal project scope, after autoload initialization.
## Instantiating outside the tree compiles its dependencies without running _ready.

const SUPPORTED_SCENES := [
	"res://tools/halt_workshop/VerifyLivingHalt.tscn",
	"res://tools/halt_workshop/VerifyProductionHalt.tscn",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_path: String = SUPPORTED_SCENES[0]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--compile-scene="):
			scene_path = argument.trim_prefix("--compile-scene=")
	if scene_path not in SUPPORTED_SCENES:
		push_error("HALT_VERIFIER_COMPILE_FAILED: unsupported verifier scene")
		quit(1)
		return
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("HALT_VERIFIER_COMPILE_FAILED: scene could not load")
		quit(1)
		return
	var instance := scene.instantiate()
	if instance == null:
		push_error("HALT_VERIFIER_COMPILE_FAILED: scene could not instantiate")
		quit(1)
		return
	var script := instance.get_script() as Script
	var valid: bool = script != null and script.can_instantiate() and instance.has_method("_run")
	instance.free()
	if not valid:
		push_error("HALT_VERIFIER_COMPILE_FAILED: verifier script missing or invalid")
		quit(1)
		return
	print("HALT_VERIFIER_COMPILED")
	quit(0)
