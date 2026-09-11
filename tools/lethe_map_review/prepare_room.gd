extends Node
const ROOM := "res://data/rooms/catabase_routes/route_f51a86b714b9/room.tres"
const PROFILE := "res://assets/catabase/combat/lethe_traces_v1/presentation.tres"
const EXPECTED_GAMEPLAY := "6c270a92cbce87dae00ba15dfa4bcd9177556bf603df76bb53dd024654364f02"


func _ready() -> void:
	var source := load(ROOM) as ArenaDefinition
	if source == null or ArenaSnapshotService.gameplay_fingerprint(source) != EXPECTED_GAMEPLAY:
		push_error("Lethe II gameplay changed since baseline; refusing preparation")
		get_tree().quit(2)
		return
	var arena := source.duplicate(true) as ArenaDefinition
	var profile := load("res://data/rooms/catabase_expansion/presentation.tres").duplicate(true) as BattlePresentationProfile
	profile.profile_id = &"lethe_traces_v1"
	profile.camera_zoom_multiplier = 1.0
	profile.camera_offset_adjustment = Vector2(-80, 0)
	if ResourceSaver.save(profile, PROFILE) != OK:
		get_tree().quit(3)
		return
	arena.presentation_profile_path = PROFILE
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		get_tree().quit(4)
		return
	if ArenaSnapshotService.gameplay_fingerprint(arena) != EXPECTED_GAMEPLAY:
		push_error("Lethe II preparation altered gameplay")
		get_tree().quit(5)
		return
	if ResourceSaver.save(arena, ROOM) != OK:
		get_tree().quit(6)
		return
	var reloaded := ResourceLoader.load(ROOM, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	var valid := (
		reloaded != null
		and ArenaSnapshotService.gameplay_fingerprint(reloaded) == EXPECTED_GAMEPLAY
	)
	print("LETHE_PREPARED: ", JSON.stringify({ "ok": valid, "gameplay": EXPECTED_GAMEPLAY }))
	get_tree().quit(0 if valid else 7)
