extends SceneTree

const CharacterizationService := preload(
	"res://addons/dungeon_draft_arena_studio/items/services/item_characterization_service.gd"
)


func _init() -> void:
	var output_path := OS.get_environment("ITEM_STUDIO_CHARACTERIZATION_PATH")
	if output_path.is_empty():
		output_path = "res://artifacts/item_studio/characterization.json"
	var result := CharacterizationService.new().write_artifact(output_path)
	var report := result.get("report", {}) as Dictionary
	print("ITEM_STUDIO_CHARACTERIZATION=", JSON.stringify({
		"ok": result.get("ok", false),
		"path": result.get("path", output_path),
		"definition_count": report.get("definition_count", 0),
		"catalog_fingerprint": report.get("production_catalog_fingerprint", ""),
		"errors": report.get("errors", []),
	}))
	quit(0 if result.get("ok", false) else 1)
