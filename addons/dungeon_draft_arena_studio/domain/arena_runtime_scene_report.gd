@tool
class_name ArenaRuntimeSceneReport
extends ArenaReadinessSection

## Preuve issue d'une vraie scene de bataille. Les fingerprints et la topologie
## rattachent cette preuve a la working ArenaDefinition qui a ete demandee.
@export_file("*.tscn") var expected_battle_scene_path := ""
@export_file("*.tscn") var battle_scene_path := ""
@export_file("*.gd") var scene_script_path := ""
@export var runtime_scene_inspected := false
@export var script_parse_ok := false
@export var scene_instantiated := false
@export var runtime_ready := false
@export var grid_ready := false
@export var pathfinder_ready := false
@export var render_ready := false
@export var spawn_ready := false
@export var cleanup_ok := false
@export var produced_bundle_loaded := false
@export var configuration: StringName = &""
@export var generated_at := ""
@export var working_fingerprint := ""
@export var temporary_fingerprint := ""
@export var runtime_fingerprint := ""
@export var fingerprints_identical := false
@export var working_topology_hash := ""
@export var temporary_topology_hash := ""
@export var runtime_topology_hash := ""
@export var topology_hashes_identical := false
@export var expected_floor_hash := ""
@export var rendered_floor_hash := ""


func battle_scene_matches() -> bool:
	if battle_scene_path.is_empty():
		return false
	return expected_battle_scene_path.is_empty() \
		or battle_scene_path == expected_battle_scene_path


func fingerprints_match() -> bool:
	return fingerprints_identical \
		and not working_fingerprint.is_empty() \
		and working_fingerprint == temporary_fingerprint \
		and working_fingerprint == runtime_fingerprint


func topology_matches() -> bool:
	return topology_hashes_identical \
		and not working_topology_hash.is_empty() \
		and working_topology_hash == temporary_topology_hash \
		and working_topology_hash == runtime_topology_hash


func diagnostics_ready() -> bool:
	return runtime_scene_inspected \
		and battle_scene_matches() \
		and script_parse_ok \
		and scene_instantiated \
		and runtime_ready \
		and grid_ready \
		and pathfinder_ready \
		and render_ready \
		and spawn_ready \
		and fingerprints_match() \
		and topology_matches() \
		and not produced_bundle_loaded


func runtime_contract_satisfied() -> bool:
	return passed() and errors.is_empty() and diagnostics_ready()


func to_dict() -> Dictionary:
	var result: Dictionary = super.to_dict()
	result.merge({
		"expected_battle_scene_path": expected_battle_scene_path,
		"battle_scene_path": battle_scene_path,
		"scene_script_path": scene_script_path,
		"runtime_scene_inspected": runtime_scene_inspected,
		"script_parse_ok": script_parse_ok,
		"scene_instantiated": scene_instantiated,
		"runtime_ready": runtime_ready,
		"grid_ready": grid_ready,
		"pathfinder_ready": pathfinder_ready,
		"render_ready": render_ready,
		"spawn_ready": spawn_ready,
		"cleanup_ok": cleanup_ok,
		"produced_bundle_loaded": produced_bundle_loaded,
		"configuration": str(configuration),
		"generated_at": generated_at,
		"working_fingerprint": working_fingerprint,
		"temporary_fingerprint": temporary_fingerprint,
		"runtime_fingerprint": runtime_fingerprint,
		"fingerprints_identical": fingerprints_identical,
		"working_topology_hash": working_topology_hash,
		"temporary_topology_hash": temporary_topology_hash,
		"runtime_topology_hash": runtime_topology_hash,
		"topology_hashes_identical": topology_hashes_identical,
		"expected_floor_hash": expected_floor_hash,
		"rendered_floor_hash": rendered_floor_hash,
	}, true)
	return result
