extends Node

const ROOM := "res://data/rooms/catabase_routes/route_edce0087c741/room.tres"
const BASELINE := "res://artifacts/dev/braises-cloitre/before/room.tres"
const PROFILE := "res://assets/catabase/combat/braises_cloitre_v1/presentation.tres"
const MANIFEST := "res://assets/catabase/combat/braises_cloitre_v1/manifest.json"


func _ready() -> void:
	var source := load(ROOM) as ArenaDefinition
	var baseline := load(BASELINE) as ArenaDefinition
	if source == null or baseline == null:
		_fail("Missing room or immutable baseline")
		return
	var expected := ArenaSnapshotService.gameplay_fingerprint(baseline)
	if ArenaSnapshotService.gameplay_fingerprint(source) != expected:
		_fail("Gameplay changed since baseline; refusing preparation")
		return
	var arena := source.duplicate(true) as ArenaDefinition
	var profile := load(source.presentation_profile_path).duplicate(true) as BattlePresentationProfile
	profile.profile_id = &"braises_cloitre_v1"
	profile.camera_zoom_multiplier = 1.0
	profile.camera_offset_adjustment = Vector2(-80, -20)
	profile.camera_keep_painting_in_view = true
	if ResourceSaver.save(profile, PROFILE) != OK:
		_fail("Could not save local camera profile")
		return
	arena.presentation_profile_path = PROFILE
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		_fail("Studio runtime synchronization failed")
		return
	if ArenaSnapshotService.gameplay_fingerprint(arena) != expected:
		_fail("Visual preparation altered gameplay")
		return
	if ResourceSaver.save(arena, ROOM) != OK:
		_fail("Could not save room")
		return
	var reloaded := ResourceLoader.load(ROOM, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	if reloaded == null or ArenaSnapshotService.gameplay_fingerprint(reloaded) != expected:
		_fail("Reloaded gameplay differs")
		return
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	record["gameplay_fingerprint"] = expected
	record["gameplay_unchanged_after_reload"] = true
	record["room_sha256"] = FileAccess.get_sha256(ROOM)
	var output := FileAccess.open(MANIFEST, FileAccess.WRITE)
	output.store_string(JSON.stringify(record, "  ") + "\n")
	output.close()
	print("BRAISES_CLOITRE_PREPARED: ", JSON.stringify({ "ok": true, "gameplay": expected }))
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(2)
