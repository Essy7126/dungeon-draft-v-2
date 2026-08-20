class_name AchillesTheorycraftSnapshotExporter
extends RefCounted

const SCHEMA_VERSION := 1
const ODYSSEY_PATH := "res://data/runs/odyssey.tres"
const USER_THEORYCRAFT_ROOT := "user://theorycraft/achilles"
const MISSION_ARTIFACT_DIRECTORY := "ACHILLES_3D_CHARACTER_THEORYCRAFT_V1_20260820_181248"
const DURABLE_INTEGRATION_ROOT := (
	"C:/Dungeon_Draft_Production/Achilles/Integration/"
	+ MISSION_ARTIFACT_DIRECTORY
)
const FORBIDDEN_OUTPUT_FRAGMENTS := [
	"/dungeon_draft_production/achilles/canonical/",
	"/dungeon-draft-v-2-worktrees/achilles-3d-sword-odyssey-v1-20260820_133257/",
]

var _artifact_root := ""


func build_snapshot() -> Dictionary:
	var run := load(ODYSSEY_PATH) as RunData
	if run == null:
		return {"error": "ODYSSEY_RESOURCE_MISSING", "resource": ODYSSEY_PATH}
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		return {
			"error": "ODYSSEY_HERO_RESOLUTION_FAILED",
			"details": Array(resolution.errors),
		}
	var hero_index := -1
	for index in range(resolution.heroes.size()):
		if resolution.heroes[index].get_effective_unit_id() == &"achilles":
			hero_index = index
			break
	if hero_index < 0:
		return {"error": "ACHILLES_NOT_RESOLVED_FROM_ODYSSEY"}
	var hero := resolution.heroes[hero_index]
	var hero_profile := resolution.hero_profiles[hero_index]
	var progression := hero_profile.progression_profile
	var repository := _repository_identity()
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"repository": repository,
		"achilles": _unit_snapshot(hero, hero_profile),
		"capabilities": _spells_snapshot(progression.spells),
		"disciplines": _disciplines_snapshot(progression.disciplines),
		"odyssey": _run_snapshot(run),
		"enemies": _enemies_snapshot(run),
		"maps": _maps_snapshot(run),
		"source_chain": [
			ODYSSEY_PATH,
			run.content_profile.resource_path,
			progression.resource_path,
			"RunHeroResolver.resolve_runtime_hero_data(run, false)",
		],
		"_provenance": {
			"schema_version": AchillesTheorycraftProvenance.derived(
				"Achilles theorycraft snapshot schema"
			),
			"repository": AchillesTheorycraftProvenance.derived(
				"Read-only repository identity and working-tree classification at project root"
			),
			"achilles": AchillesTheorycraftProvenance.derived(
				"Achilles resolved through Odyssey content and RunHeroResolver",
				[hero_profile.base_unit_data.resource_path, progression.resource_path],
			),
			"capabilities": AchillesTheorycraftProvenance.derived(
				"Ordered live Spell Resources from the resolved Achilles progression profile",
				[progression.resource_path],
			),
			"disciplines": AchillesTheorycraftProvenance.derived(
				"Ordered live DisciplineData Resources from the resolved Achilles progression profile",
				[progression.resource_path],
			),
			"odyssey": AchillesTheorycraftProvenance.observed(ODYSSEY_PATH),
			"enemies": AchillesTheorycraftProvenance.derived(
				"Unique enemy UnitData Resources referenced by Odyssey encounter rosters",
				[ODYSSEY_PATH],
			),
			"maps": AchillesTheorycraftProvenance.derived(
				"Static room and grid metadata read from the ordered Odyssey rooms",
				[ODYSSEY_PATH],
			),
			"source_chain": AchillesTheorycraftProvenance.derived(
				"Authoritative Odyssey runtime resolution chain",
				[ODYSSEY_PATH, run.content_profile.resource_path, progression.resource_path],
			),
		},
	}
	var fingerprint_input := snapshot.duplicate(true)
	snapshot["snapshot_sha"] = AchillesTheorycraftJson.fingerprint(fingerprint_input)
	snapshot._provenance["snapshot_sha"] = AchillesTheorycraftProvenance.derived(
		"SHA-256 of canonical snapshot before self-field",
		[repository.get("commit", "")],
	)
	return AchillesTheorycraftJson.canonicalize(snapshot)


func build_provenance_index(snapshot: Dictionary) -> Dictionary:
	var entries := {}
	_collect_provenance(snapshot, "", entries)
	return {
		"schema_version": SCHEMA_VERSION,
		"snapshot_sha": snapshot.get("snapshot_sha", ""),
		"entries": AchillesTheorycraftJson.canonicalize(entries),
	}


func export_snapshot(root: String) -> Dictionary:
	if not _is_non_production_destination(root):
		return {"ok": false, "error": "PRODUCTION_DESTINATION_FORBIDDEN"}
	var snapshot := build_snapshot()
	if snapshot.has("error"):
		return {"ok": false, "error": snapshot.error}
	var absolute := ProjectSettings.globalize_path(root)
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	if error != OK:
		return {"ok": false, "error": error_string(error)}
	var outputs := {
		"snapshot": root.path_join("achilles_theorycraft_snapshot.json"),
		"markdown": root.path_join("achilles_theorycraft_snapshot.md"),
		"provenance": root.path_join("snapshot_provenance.json"),
	}
	if not _write_text(outputs.snapshot, AchillesTheorycraftJson.stringify(snapshot)):
		return {"ok": false, "error": "SNAPSHOT_WRITE_FAILED"}
	if not _write_text(outputs.markdown, to_markdown(snapshot)):
		return {"ok": false, "error": "MARKDOWN_WRITE_FAILED"}
	if not _write_text(
		outputs.provenance,
		AchillesTheorycraftJson.stringify(build_provenance_index(snapshot))
	):
		return {"ok": false, "error": "PROVENANCE_WRITE_FAILED"}
	return {"ok": true, "paths": outputs, "snapshot_sha": snapshot.snapshot_sha}


func configure_artifact_root(root: String) -> bool:
	var normalized := _normalized_absolute(root)
	if normalized.is_empty() or not _is_mission_artifact_root(normalized):
		return false
	if _is_forbidden_absolute(normalized):
		return false
	_artifact_root = normalized.trim_suffix("/")
	return true


func to_markdown(snapshot: Dictionary) -> String:
	var unit: Dictionary = snapshot.get("achilles", {})
	var repository: Dictionary = snapshot.get("repository", {})
	var lines := PackedStringArray([
		"# Achilles Theorycraft Snapshot",
		"",
		"- Schema: `%s`" % snapshot.get("schema_version", ""),
		"- Repository: `%s`" % repository.get("repository", "NOT_MEASURED"),
		"- Branch: `%s`" % repository.get("branch", "NOT_MEASURED"),
		"- Commit: `%s`" % repository.get("commit", "NOT_MEASURED"),
		"- Commit date: `%s`" % repository.get("commit_date", "NOT_MEASURED"),
		"- Source classification: `%s`" % repository.get("source_classification", "NOT_MEASURED"),
		"- Worktree dirty: `%s`" % repository.get("worktree_dirty", "NOT_MEASURED"),
		"- Source-state note: %s" % repository.get("source_state_note", "NOT_MEASURED"),
		"- Snapshot SHA-256: `%s`" % snapshot.get("snapshot_sha", ""),
		"",
		"## Runtime authority",
		"",
		"`odyssey.tres -> odyssey_content_profile.tres -> achilles_progression_profile.tres -> RunHeroResolver`",
		"",
		"## Achilles",
		"",
		"- Character: `%s`" % unit.get("character_id", ""),
		"- HP/AP/MP: `%s / %s / %s`" % [
			unit.get("max_hp", ""), unit.get("max_ap", ""), unit.get("max_mp", "")
		],
		"- Active slots: `%s`" % unit.get("active_spell_slots", ""),
		"- Basic attack enabled: `%s`" % unit.get("basic_attack_enabled", ""),
		"",
		"## Capabilities",
		"",
	])
	for ability in snapshot.get("capabilities", []):
		lines.append("- `%s` - %s PA - range %s..%s - `%s`" % [
			ability.get("name", ability.get("id", "")),
			ability.get("ap_cost", ""),
			ability.get("minimum_range", ""),
			ability.get("maximum_range", ""),
			ability.get("resource_path", ""),
		])
	lines.append_array(PackedStringArray([
		"",
		"## Honesty boundary",
		"",
		"Map-dependent range coverage, line-of-sight, choke points, kite windows and recovery paths remain `NOT_MEASURED` unless an exact adapter supplies them.",
		"",
	]))
	return "\n".join(lines)


func _repository_identity() -> Dictionary:
	var project_root := ProjectSettings.globalize_path("res://")
	var repository := _git(["-C", project_root, "config", "--get", "remote.origin.url"])
	var branch := _git(["-C", project_root, "rev-parse", "--abbrev-ref", "HEAD"])
	var commit := _git(["-C", project_root, "rev-parse", "HEAD"])
	var commit_date := _git(["-C", project_root, "show", "-s", "--format=%cI", "HEAD"])
	var worktree_status := _git([
		"-C", project_root, "status", "--porcelain", "--untracked-files=normal",
	])
	var worktree_dirty := not worktree_status.is_empty()
	var version_info := Engine.get_version_info()
	var data := {
		"repository": repository if not repository.is_empty() else null,
		"branch": branch if not branch.is_empty() else null,
		"commit": commit if not commit.is_empty() else null,
		"date": commit_date if not commit_date.is_empty() else null,
		"commit_date": commit_date if not commit_date.is_empty() else null,
		"godot_version": str(version_info.get("string", "")),
		"worktree_dirty": worktree_dirty,
		"source_classification": (
			"PRE_COMMIT_SOURCE_HEAD" if worktree_dirty else "COMMITTED_SOURCE_HEAD"
		),
		"source_state_note": (
			"Snapshot reads the current working tree; regenerate after the implementation commit."
			if worktree_dirty
			else "Snapshot reads a clean committed working tree."
		),
		"_provenance": {},
	}
	for field in ["repository", "branch", "commit", "date", "commit_date"]:
		data._provenance[field] = (
			AchillesTheorycraftProvenance.derived("Read-only git command at project root")
			if data[field] != null
			else AchillesTheorycraftProvenance.not_measured("Git executable or metadata unavailable")
		)
	data._provenance["godot_version"] = AchillesTheorycraftProvenance.observed(
		"Engine.get_version_info()"
	)
	data._provenance["worktree_dirty"] = AchillesTheorycraftProvenance.derived(
		"git status --porcelain --untracked-files=normal at project root"
	)
	for field in ["source_classification", "source_state_note"]:
		data._provenance[field] = AchillesTheorycraftProvenance.derived(
			"Classification derived from repository commit and working-tree state"
		)
	return data


func _unit_snapshot(hero: UnitData, profile: RunHeroProfile) -> Dictionary:
	var source := profile.base_unit_data.resource_path
	var progression := profile.progression_profile.resource_path
	var visual_path := hero.visual_scene.resource_path if hero.visual_scene != null else ""
	var data := {
		"resource_path": source,
		"character_id": str(hero.get_effective_unit_id()),
		"name": hero.unit_name,
		"max_hp": hero.max_hp,
		"initiative": hero.initiative,
		"max_ap": hero.max_ap,
		"max_mp": hero.max_mp,
		"attack_power": hero.attack_power,
		"basic_attack_enabled": hero.basic_attack_enabled,
		"active_spell_slots": hero.active_spell_slots,
		"visual_scene": visual_path,
		"progression_profile": progression,
		"tags": null,
		"_provenance": {},
	}
	for field in [
		"resource_path", "character_id", "name", "max_hp", "initiative", "max_ap",
		"max_mp", "attack_power", "basic_attack_enabled", "visual_scene",
	]:
		data._provenance[field] = AchillesTheorycraftProvenance.observed(
			"%s#%s" % [source, field]
		)
	for field in ["active_spell_slots", "progression_profile"]:
		data._provenance[field] = AchillesTheorycraftProvenance.observed(
			"%s#%s" % [progression, field]
		)
	data._provenance.tags = AchillesTheorycraftProvenance.not_measured(
		"UnitData exposes no generic design tags field."
	)
	return data


func _spells_snapshot(spells: Array[Spell]) -> Array:
	var result: Array = []
	for spell in spells:
		if spell != null:
			result.append(_spell_snapshot(spell))
	return result


func _spell_snapshot(spell: Spell) -> Dictionary:
	var source := spell.resource_path
	var action := TheorycraftActionSpec.from_spell(spell)
	var data := {
		"resource_path": source,
		"id": str(spell.get_effective_spell_id()),
		"name": spell.spell_name,
		"ap_cost": spell.ap_cost,
		"minimum_range": spell.minimum_range,
		"maximum_range": spell.spell_range,
		"area": action.area,
		"zone": action.area,
		"targeting": action.conditions,
		"damage": spell.damage,
		"shield": spell.shield_grant,
		"movement": action.mobility,
		"push": spell.push_distance,
		"once_per_activation": spell.once_per_activation,
		"max_uses_per_combat": spell.max_uses_per_combat,
		"cooldown_activations": spell.cooldown_activations,
		"discipline": str(spell.discipline_id),
		"tags": null,
		"_provenance": {},
	}
	for field in data.keys():
		if field != "_provenance" and field != "tags":
			data._provenance[field] = AchillesTheorycraftProvenance.observed(
				"%s#%s" % [source, field]
			)
	data._provenance.tags = AchillesTheorycraftProvenance.not_measured(
		"Spell exposes no generic design tags field."
	)
	return data


func _disciplines_snapshot(disciplines: Array[DisciplineData]) -> Array:
	var result: Array = []
	for discipline in disciplines:
		if discipline == null:
			continue
		var ranks: Array = []
		var thresholds: Array = []
		var upgrades: Array = []
		for rank in discipline.ranks:
			if rank == null:
				continue
			var choices: Array = []
			for choice in rank.choices:
				if choice == null:
					continue
				choices.append({
					"id": str(choice.upgrade_id),
					"name": choice.display_name,
					"target_spell_id": str(choice.target_spell_id),
					"modifier_count": choice.spell_modifiers.size(),
					"resource_path": choice.resource_path,
				})
				upgrades.append(choices[choices.size() - 1])
			thresholds.append(rank.required_total_xp)
			ranks.append({
				"rank": rank.rank,
				"required_total_xp": rank.required_total_xp,
				"choices": choices,
			})
		var source := discipline.resource_path
		var diagnostics := Array(SkillTreeResolver.validate_discipline(discipline))
		result.append({
			"resource_path": source,
			"id": str(discipline.discipline_id),
			"name": discipline.display_name,
			"ranks": ranks,
			"thresholds": thresholds,
			"upgrades": upgrades,
			"validation_diagnostics": diagnostics,
			"prerequisites": null,
			"exclusions": null,
			"_provenance": {
				"resource_path": AchillesTheorycraftProvenance.observed(source),
				"id": AchillesTheorycraftProvenance.observed("%s#discipline_id" % source),
				"name": AchillesTheorycraftProvenance.observed("%s#display_name" % source),
				"ranks": AchillesTheorycraftProvenance.observed("%s#ranks" % source),
				"thresholds": AchillesTheorycraftProvenance.derived(
					"Ordered DisciplineRankData.required_total_xp values", [source]
				),
				"upgrades": AchillesTheorycraftProvenance.derived(
					"Flattened ordered DisciplineRankData.choices", [source]
				),
				"validation_diagnostics": AchillesTheorycraftProvenance.derived(
					"SkillTreeResolver.validate_discipline", [source]
				),
				"prerequisites": AchillesTheorycraftProvenance.not_measured(
					"DisciplineData exposes no prerequisite field."
				),
				"exclusions": AchillesTheorycraftProvenance.not_measured(
					"DisciplineData exposes no exclusion field."
				),
			},
		})
	return result


func _run_snapshot(run: RunData) -> Dictionary:
	var rooms: Array = []
	for index in range(run.rooms.size()):
		var room := run.rooms[index]
		rooms.append({
			"index": index + 1,
			"resource_path": room.resource_path,
			"name": room.room_name,
			"encounter": room.encounter_definition.resource_path \
				if room.encounter_definition != null else "",
			"flow_encounter_count": room.get_wave_count(),
			"_provenance": {
				"index": AchillesTheorycraftProvenance.derived("Ordered RunData.rooms index"),
				"resource_path": AchillesTheorycraftProvenance.observed("%s#rooms" % run.resource_path),
				"name": AchillesTheorycraftProvenance.observed("%s#room_name" % room.resource_path),
				"encounter": AchillesTheorycraftProvenance.observed("%s#encounter_definition" % room.resource_path),
				"flow_encounter_count": AchillesTheorycraftProvenance.derived(
					"RoomData.get_wave_count()", [room.resource_path]
				),
			},
		})
	var economy := run.economy_profile
	var starting_items: Array = []
	if economy != null:
		for item in economy.starting_items:
			if item != null:
				starting_items.append({
					"item_id": str(item.item_id),
					"quantity": item.quantity,
				})
	var economy_path := economy.resource_path if economy != null else ""
	var data := {
		"resource_path": run.resource_path,
		"name": run.run_name,
		"seed": run.default_seed,
		"target_duration_minutes": run.target_duration_minutes,
		"extended_duration_minutes": run.extended_duration_minutes,
		"room_flow_mode": str(run.get_room_flow_mode_name()),
		"rooms": rooms,
		"economy_resource": economy_path,
		"starting_inventory": starting_items,
		"equipment_rewards_enabled": economy.equipment_rewards_enabled \
			if economy != null else null,
		"rewards": {
			"equipment_enabled": economy.equipment_rewards_enabled,
			"equipment_pool_tag": str(economy.equipment_reward_pool_tag),
		} if economy != null else null,
		"_provenance": {},
	}
	for field in [
		"resource_path", "name", "seed", "target_duration_minutes",
		"extended_duration_minutes", "room_flow_mode", "rooms",
	]:
		data._provenance[field] = AchillesTheorycraftProvenance.observed(
			"%s#%s" % [run.resource_path, field]
		)
	for field in ["economy_resource", "starting_inventory", "equipment_rewards_enabled", "rewards"]:
		data._provenance[field] = (
			AchillesTheorycraftProvenance.observed("%s#%s" % [economy_path, field])
			if economy != null else AchillesTheorycraftProvenance.not_measured("No economy profile")
		)
	return data


func _enemies_snapshot(run: RunData) -> Array:
	var by_path := {}
	for room_index in range(run.rooms.size()):
		var room := run.rooms[room_index]
		if room.encounter_definition == null:
			continue
		for enemy in room.encounter_definition.expanded_roster():
			if enemy == null:
				continue
			var source := enemy.resource_path
			if not by_path.has(source):
				by_path[source] = _enemy_snapshot(enemy)
			var use_rooms: Array = by_path[source].rooms
			if not use_rooms.has(room_index + 1):
				use_rooms.append(room_index + 1)
			by_path[source].rooms = use_rooms
	var paths: Array = by_path.keys()
	paths.sort()
	var result: Array = []
	for path in paths:
		result.append(by_path[path])
	return result


func _enemy_snapshot(enemy: UnitData) -> Dictionary:
	var spells: Array = []
	for spell in enemy.spells:
		if spell != null:
			spells.append(_spell_snapshot(spell))
	var source := enemy.resource_path
	var data := {
		"resource_path": source,
		"id": str(enemy.get_effective_unit_id()),
		"name": enemy.unit_name,
		"max_hp": enemy.max_hp,
		"max_ap": enemy.max_ap,
		"max_mp": enemy.max_mp,
		"attack_power": enemy.attack_power,
		"armor": enemy.armure,
		"basic_attack_enabled": enemy.basic_attack_enabled,
		"capabilities": spells,
		"rooms": [],
		"_provenance": {},
	}
	for field in data.keys():
		if field != "_provenance" and field != "rooms":
			data._provenance[field] = AchillesTheorycraftProvenance.observed(
				"%s#%s" % [source, field]
			)
	data._provenance.rooms = AchillesTheorycraftProvenance.derived(
		"Membership in Odyssey encounter rosters"
	)
	return data


func _maps_snapshot(run: RunData) -> Array:
	var result: Array = []
	for index in range(run.rooms.size()):
		var room := run.rooms[index]
		var dimensions: Variant = null
		var accessible_count: Variant = null
		var source := room.resource_path
		var dimension_provenance := AchillesTheorycraftProvenance.not_measured(
			"No supported read-only map topology on room."
		)
		if room is ArenaDefinition:
			var arena := room as ArenaDefinition
			dimensions = [arena.grid_size.x, arena.grid_size.y]
			accessible_count = arena.playable_cells().size()
			dimension_provenance = AchillesTheorycraftProvenance.observed(
				"%s#grid_size/cells" % source
			)
		elif room.grid_layout != null:
			dimensions = [room.grid_layout.logical_size.x, room.grid_layout.logical_size.y]
			accessible_count = room.grid_layout.walkable_cells().size()
			dimension_provenance = AchillesTheorycraftProvenance.observed(
				"%s#grid_layout" % source
			)
		result.append({
			"room_index": index + 1,
			"room_resource": source,
			"dimensions": dimensions,
			"accessible_cell_count": accessible_count,
			"hero_spawns": room.hero_spawn_zone.map(func(cell): return [cell.x, cell.y]),
			"enemy_spawns": room.enemy_spawn_zone.map(func(cell): return [cell.x, cell.y]),
			"path_distance": null,
			"line_of_sight": null,
			"choke_points": null,
			"range_coverage": null,
			"_provenance": {
				"room_index": AchillesTheorycraftProvenance.derived("Ordered RunData.rooms index"),
				"room_resource": AchillesTheorycraftProvenance.observed("%s#rooms" % run.resource_path),
				"dimensions": dimension_provenance,
				"accessible_cell_count": dimension_provenance,
				"hero_spawns": AchillesTheorycraftProvenance.observed("%s#hero_spawn_zone" % source),
				"enemy_spawns": AchillesTheorycraftProvenance.observed("%s#enemy_spawn_zone" % source),
				"path_distance": AchillesTheorycraftProvenance.not_measured("No exact start/goal query selected."),
				"line_of_sight": AchillesTheorycraftProvenance.not_measured("No exact actor/target state selected."),
				"choke_points": AchillesTheorycraftProvenance.not_measured("No validated read-only choke adapter used."),
				"range_coverage": AchillesTheorycraftProvenance.not_measured("No exact turn state selected."),
			},
		})
	return result


func _collect_provenance(value: Variant, path: String, output: Dictionary) -> void:
	if value is Dictionary:
		var data := value as Dictionary
		if data.has("_provenance"):
			for field in (data._provenance as Dictionary).keys():
				output["%s/%s" % [path, field]] = data._provenance[field]
		for key in data.keys():
			if str(key) == "_provenance":
				continue
			_collect_provenance(data[key], "%s/%s" % [path, key], output)
	elif value is Array:
		for index in range(value.size()):
			_collect_provenance(value[index], "%s/%d" % [path, index], output)


func _git(arguments: Array[String]) -> String:
	var output: Array = []
	var args := PackedStringArray(arguments)
	var code := OS.execute("git", args, output, true)
	if code != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()


func _is_non_production_destination(path: String) -> bool:
	var stripped := path.strip_edges()
	if stripped.is_empty() or stripped.begins_with("res://"):
		return false
	if stripped == USER_THEORYCRAFT_ROOT or stripped.begins_with(USER_THEORYCRAFT_ROOT + "/"):
		return true
	var absolute := _normalized_absolute(stripped)
	if absolute.is_empty() or _is_forbidden_absolute(absolute) or _artifact_root.is_empty():
		return false
	return absolute == _artifact_root or absolute.begins_with(_artifact_root + "/")


func _normalized_absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ""
	var normalized := path.replace("\\", "/").simplify_path()
	return normalized if normalized.is_absolute_path() else ""


func _is_forbidden_absolute(path: String) -> bool:
	var lowered := (path.trim_suffix("/") + "/").to_lower()
	for fragment in FORBIDDEN_OUTPUT_FRAGMENTS:
		if lowered.contains(fragment):
			return true
	return false


func _is_mission_artifact_root(path: String) -> bool:
	var normalized := _normalized_absolute(path)
	if normalized.is_empty():
		return false
	var local_root_path := ProjectSettings.globalize_path("res://")
	local_root_path = local_root_path.path_join("artifacts")
	local_root_path = local_root_path.path_join(MISSION_ARTIFACT_DIRECTORY)
	var local_root := _normalized_absolute(local_root_path)
	var durable_root := _normalized_absolute(DURABLE_INTEGRATION_ROOT)
	return normalized.to_lower() in [local_root.to_lower(), durable_root.to_lower()]


func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	return true
