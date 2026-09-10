extends Node

## Separate game process for editor-tool previews. Reads a private draft snapshot;
## the runtime's local session keeps preview transactions out of the active run.
const Service := preload(
	"res://addons/dungeon_draft_arena_studio/halts/services/painted_halt_manifest_service.gd"
)


func _ready() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--halt-preview-draft="):
			path = argument.trim_prefix("--halt-preview-draft=")
	var manifest: Variant = (
		JSON.parse_string(FileAccess.get_file_as_string(path))
		if FileAccess.file_exists(path)
		else null
	)
	if not manifest is Dictionary:
		_fail("Aucune copie de travail valide à prévisualiser.")
		return
	var prepared := Service.prepare_images(manifest)
	if not bool(prepared.get("ok", false)):
		_fail(" · ".join(prepared.get("errors", [])))
		return
	var runtime = load("res://hub/painted_halt/living_halt.gd").new()
	runtime.definition_override = manifest
	runtime.preview_materials = prepared.materials
	runtime.preview_flow = prepared.flow
	runtime.preview_mode = true
	add_child(runtime)


func _fail(message: String) -> void:
	push_error(message)
	var label := Label.new()
	label.text = message
	label.position = Vector2(24, 24)
	add_child(label)
