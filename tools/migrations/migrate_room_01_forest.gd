extends Node

## Guarded one-shot migration for the historical room_01_forest ownership
## divergence. Default mode is read-only. Pass --apply only after fixture tests.

const BUNDLE := "res://data/arenas/produced/room_01_forest"
const RUN := "res://data/runs/first_run.tres"
const ROOM_INDEX := 0
const EXPECTED_SHA256 := {
	"res://data/runs/first_run.tres": "657b9c1700e10a59624a5c83602cc4dee3af88a9f60bdd0ee0f9eb24cdcc6bc1",
	"res://data/arenas/produced/room_01_forest/arena.tres": "34af275b7ea8a4a5f2ca87cf807a188bb6f6c0570e977fab018bdf896f58607f",
	"res://data/arenas/produced/room_01_forest/arena_principal.tres": "a42afc632cb0fe27e8a4dc93bef87401c19b5bc751576bdd2b38f438d10b72e4",
	"res://data/arenas/produced/room_01_forest/modular_visual_profile.tres": "18e27b8b0527ec0b1de489cf7eab4d2d4b986fc99f2d2c62bc0b0a647a7c60a9",
	"res://data/arenas/produced/room_01_forest/production_manifest.json": "0bb0c700412a2136cfe08b8bfa32567ea65373ee31600a1e09b435981899409b",
}


func _ready() -> void:
	var apply := "--apply" in OS.get_cmdline_user_args()
	var guards := _verify_guards()
	if not bool(guards.get("ok", false)):
		print("ROOM_01_FOREST_MIGRATION_GUARD_FAILED ", JSON.stringify(guards))
		get_tree().quit(2)
		return
	var migration_plan := ArenaBundleOwnershipMigrationService.plan(
		BUNDLE, RUN, ROOM_INDEX
	)
	print("ROOM_01_FOREST_MIGRATION_DRY_RUN ", JSON.stringify(
		_summarize(migration_plan)
	))
	if not bool(migration_plan.get("ok", false)):
		get_tree().quit(3)
		return
	if not apply:
		print("ROOM_01_FOREST_MIGRATION_READY apply=false")
		get_tree().quit(0)
		return
	var result := ArenaBundleOwnershipMigrationService.execute(
		BUNDLE, RUN, ROOM_INDEX
	)
	print("ROOM_01_FOREST_MIGRATION_RESULT ", JSON.stringify(_summarize(result)))
	get_tree().quit(0 if bool(result.get("ok", false)) else 4)


func _verify_guards() -> Dictionary:
	var actual := {}
	var mismatches := PackedStringArray()
	for path in EXPECTED_SHA256:
		if not FileAccess.file_exists(path):
			mismatches.append("%s:missing" % path)
			continue
		var sha256 := FileAccess.get_sha256(path)
		actual[path] = sha256
		if sha256 != str(EXPECTED_SHA256[path]):
			mismatches.append("%s:%s" % [path, sha256])
	return {
		"ok": mismatches.is_empty(),
		"expected": EXPECTED_SHA256,
		"actual": actual,
		"mismatches": mismatches,
	}


func _summarize(value: Dictionary) -> Dictionary:
	var inspection := value.get(
		"final_inspection", value.get("inspection", {})
	) as Dictionary
	var verification := value.get("run_verification", {}) as Dictionary
	return {
		"ok": value.get("ok", false),
		"dry_run": value.get("dry_run", true),
		"status": value.get("status", "PLANNED"),
		"error": value.get("error", ""),
		"bundle_directory": value.get("bundle_directory", BUNDLE),
		"run_path": value.get("run_path", RUN),
		"room_index": value.get("room_index", ROOM_INDEX),
		"room_count": value.get("room_count", -1),
		"foreign_room_path": value.get("foreign_room_path", ""),
		"run_owned_room_path": value.get("run_owned_room_path", ""),
		"gameplay_fingerprint": value.get("gameplay_fingerprint", ""),
		"encounter_fingerprint": value.get("encounter_fingerprint", ""),
		"run_sha256": value.get("run_sha256", ""),
		"foreign_room_sha256": value.get("foreign_room_sha256", ""),
		"manifest_sha256": value.get("manifest_sha256", ""),
		"bundle_state": str(inspection.get("state", &"")),
		"foreign_files": inspection.get("foreign", []),
		"verified_room_path": verification.get("room_path", ""),
		"verified_gameplay_fingerprint": verification.get(
			"gameplay_fingerprint", ""
		),
		"recovery": value.get("recovery", ""),
		"rollback_ok": value.get("rollback_ok", false),
	}
