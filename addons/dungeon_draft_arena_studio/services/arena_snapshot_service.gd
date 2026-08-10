@tool
class_name ArenaSnapshotService
extends RefCounted

## Autorite de snapshot pour la partie Arena uniquement. Les champs gameplay,
## les preferences editeur et les projections runtime sont volontairement
## exclus de l'empreinte Arena.


static func to_arena_snapshot(arena: ArenaDefinition) -> Dictionary:
	var snapshot := RoomIntegrationFieldPolicy.signature(
		arena, RoomIntegrationFieldPolicy.ARENA_OWNED
	)
	# The profile is bundle-local payload. Its semantic identity must not change
	# merely because staging and publication give it different resource paths.
	if arena != null and arena.modular_visual_profile != null:
		var profile_snapshot := arena.modular_visual_profile.to_dict()
		profile_snapshot.erase("resource_path")
		snapshot["modular_visual_profile"] = RoomIntegrationFieldPolicy.stable_value(
			profile_snapshot
		)
	return snapshot


static func to_room_snapshot(arena: ArenaDefinition) -> Dictionary:
	return RoomDataSnapshotService.to_room_snapshot(arena)


static func to_runtime_projection(arena: ArenaDefinition) -> ArenaRuntimeState:
	return ArenaRuntimeProjectionService.build(arena)


static func arena_fingerprint(arena: ArenaDefinition) -> String:
	return JSON.stringify(to_arena_snapshot(arena), "", true).sha256_text()


static func gameplay_fingerprint(arena: ArenaDefinition) -> String:
	return RoomDataSnapshotService.gameplay_fingerprint(arena)


static func room_fingerprint(arena: ArenaDefinition) -> String:
	return RoomDataSnapshotService.room_fingerprint(arena)


static func capture(arena: ArenaDefinition) -> Dictionary:
	return RoomDataSnapshotService.capture(arena)


static func restore(arena: ArenaDefinition, snapshot: Dictionary) -> bool:
	return RoomDataSnapshotService.restore(arena, snapshot)
