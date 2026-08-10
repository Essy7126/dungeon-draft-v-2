@tool
class_name ArenaProductionReadinessCertificate
extends Resource

@export var studio_product_version := StudioVersion.PRODUCT_VERSION
@export var generated_by := StudioVersion.GENERATED_BY
@export var arena_fingerprint := ""
@export var gameplay_fingerprint := ""
@export var render_plan_fingerprint := ""
@export var art_manifest_fingerprint := ""
@export_file("*.tres") var run_path := ""
@export var room_index := -1
@export var action: StringName = &"NONE"
@export_dir var target_bundle_path := ""
@export var destination_fingerprint := ""
@export var validation_errors: Array[String] = []
@export var accepted_warnings: Array[Dictionary] = []
@export var preview_logic_valid := false
@export var preview_art_valid := false
@export var preview_game_valid := false
@export var runtime_test_valid := false
@export_file("*.json") var runtime_test_result_path := ""
@export var runtime_test_fingerprint := ""
@export var runtime_test_generated_at := ""
@export var expected_tiles := 0
@export var rendered_tiles := 0
@export var duplicate_tiles := 0
@export var expected_walls := 0
@export var rendered_walls := 0
@export var pathfinding_valid := false
@export var spawn_contract_valid := false
@export var art_alignment_confirmed := false
@export var destination_conflict_state: StringName = &"UNKNOWN"
@export var coverage_gate_valid := false
@export var generated_at := ""
@export var ready := false


func recompute_ready() -> bool:
	ready = validation_errors.is_empty() \
		and preview_logic_valid \
		and preview_art_valid \
		and preview_game_valid \
		and runtime_test_valid \
		and expected_tiles == rendered_tiles \
		and duplicate_tiles == 0 \
		and expected_walls == rendered_walls \
		and pathfinding_valid \
		and spawn_contract_valid \
		and art_alignment_confirmed \
		and coverage_gate_valid \
		and destination_conflict_state not in [
			&"FOREIGN_CONTENT", &"CORRUPT_MANIFEST", &"OWNED_DIRTY",
			&"REFERENCED_INCOMPLETE", &"UNKNOWN",
		]
	return ready


func matches(
		arena: ArenaDefinition,
		current_destination_fingerprint := ""
	) -> bool:
	if arena == null or ArenaSnapshotService.arena_fingerprint(arena) != arena_fingerprint:
		return false
	if ArenaSnapshotService.gameplay_fingerprint(arena) != gameplay_fingerprint:
		return false
	if not current_destination_fingerprint.is_empty() \
			and current_destination_fingerprint != destination_fingerprint:
		return false
	return true


func to_dict() -> Dictionary:
	return {
		"studio_product_version": studio_product_version,
		"generated_by": generated_by,
		"arena_fingerprint": arena_fingerprint,
		"gameplay_fingerprint": gameplay_fingerprint,
		"render_plan_fingerprint": render_plan_fingerprint,
		"art_manifest_fingerprint": art_manifest_fingerprint,
		"run_path": run_path,
		"room_index": room_index,
		"action": str(action),
		"target_bundle_path": target_bundle_path,
		"destination_fingerprint": destination_fingerprint,
		"validation_errors": validation_errors.duplicate(),
		"accepted_warnings": accepted_warnings.duplicate(true),
		"preview_logic_valid": preview_logic_valid,
		"preview_art_valid": preview_art_valid,
		"preview_game_valid": preview_game_valid,
		"runtime_test_valid": runtime_test_valid,
		"runtime_test_result_path": runtime_test_result_path,
		"runtime_test_fingerprint": runtime_test_fingerprint,
		"runtime_test_generated_at": runtime_test_generated_at,
		"expected_tiles": expected_tiles,
		"rendered_tiles": rendered_tiles,
		"duplicate_tiles": duplicate_tiles,
		"expected_walls": expected_walls,
		"rendered_walls": rendered_walls,
		"pathfinding_valid": pathfinding_valid,
		"spawn_contract_valid": spawn_contract_valid,
		"art_alignment_confirmed": art_alignment_confirmed,
		"destination_conflict_state": str(destination_conflict_state),
		"coverage_gate_valid": coverage_gate_valid,
		"generated_at": generated_at,
		"ready": ready,
	}
