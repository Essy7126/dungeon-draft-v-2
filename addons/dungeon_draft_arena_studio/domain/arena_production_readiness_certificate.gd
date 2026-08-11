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
@export var automatic_runtime_smoke_valid := false
@export var automatic_runtime_smoke_result := {}
@export var manual_test_performed := false
@export_file("*.json") var runtime_test_result_path := ""
@export var runtime_test_fingerprint := ""
@export var runtime_test_generated_at := ""
@export var expected_tiles := 0
@export var rendered_tiles := 0
@export var duplicate_tiles := 0
@export var canonical_topology_hash := ""
@export var temporary_topology_hash := ""
@export var runtime_topology_hash := ""
@export var expected_floor_hash := ""
@export var rendered_floor_hash := ""
@export var removed_cells_rendered: Array[String] = []
@export var unexpected_cells: Array[String] = []
@export var missing_cells: Array[String] = []
@export var topology_gate_valid := false
@export var expected_walls := 0
@export var rendered_walls := 0
@export var pathfinding_valid := false
@export var spawn_contract_valid := false
@export var art_alignment_confirmed := false
@export var destination_conflict_state: StringName = &"UNKNOWN"
@export var coverage_gate_valid := false
@export var generated_at := ""
@export var validation_profile := ArenaIntegrationGatePolicy.Profile.PRODUCTION
@export var blocking_errors: Array[Dictionary] = []
@export var acknowledgement_warnings: Array[Dictionary] = []
@export var information: Array[Dictionary] = []
@export var automatic_actions: Array[String] = []
@export var ready := false


func recompute_ready() -> bool:
	# Compatibilite des certificats anterieurs : runtime_test_valid representait
	# le smoke local lorsque le runner interactif n'avait pas ete lance.
	if not automatic_runtime_smoke_valid and runtime_test_valid:
		automatic_runtime_smoke_valid = true
	var gate := ArenaIntegrationGatePolicy.evaluate_certificate(
		self, validation_profile
	)
	blocking_errors.assign(gate.blocking_errors)
	acknowledgement_warnings.assign(gate.acknowledgement_warnings)
	information.assign(gate.information)
	automatic_actions.assign(gate.automatic_actions)
	ready = bool(gate.ready_to_integrate)
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
		"automatic_runtime_smoke_valid": automatic_runtime_smoke_valid,
		"automatic_runtime_smoke_result": automatic_runtime_smoke_result.duplicate(true),
		"manual_test_performed": manual_test_performed,
		"runtime_test_result_path": runtime_test_result_path,
		"runtime_test_fingerprint": runtime_test_fingerprint,
		"runtime_test_generated_at": runtime_test_generated_at,
		"expected_tiles": expected_tiles,
		"rendered_tiles": rendered_tiles,
		"duplicate_tiles": duplicate_tiles,
		"canonical_topology_hash": canonical_topology_hash,
		"temporary_topology_hash": temporary_topology_hash,
		"runtime_topology_hash": runtime_topology_hash,
		"expected_floor_hash": expected_floor_hash,
		"rendered_floor_hash": rendered_floor_hash,
		"removed_cells_rendered": removed_cells_rendered.duplicate(),
		"unexpected_cells": unexpected_cells.duplicate(),
		"missing_cells": missing_cells.duplicate(),
		"topology_gate_valid": topology_gate_valid,
		"expected_walls": expected_walls,
		"rendered_walls": rendered_walls,
		"pathfinding_valid": pathfinding_valid,
		"spawn_contract_valid": spawn_contract_valid,
		"art_alignment_confirmed": art_alignment_confirmed,
		"destination_conflict_state": str(destination_conflict_state),
		"coverage_gate_valid": coverage_gate_valid,
		"generated_at": generated_at,
		"validation_profile": validation_profile,
		"blocking_errors": blocking_errors.duplicate(true),
		"acknowledgement_warnings": acknowledgement_warnings.duplicate(true),
		"information": information.duplicate(true),
		"automatic_actions": automatic_actions.duplicate(),
		"ready": ready,
	}
