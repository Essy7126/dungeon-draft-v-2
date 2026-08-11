extends SceneTree

const OUTPUT_ROOT := "res://artifacts/vfx_studio_feasibility"
const INVENTORY_JSON := OUTPUT_ROOT + "/vfx_inventory.json"
const INVENTORY_REPORT := OUTPUT_ROOT + "/inventory/vfx_inventory.md"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data_files := _collect_files("res://data")
	var project_files := _collect_visual_source_files()
	var hero_unit_files := data_files.filter(func(path): return path.ends_with(".tres") and path.begins_with("res://data/units/alli"))
	var enemy_unit_files := data_files.filter(func(path): return path.ends_with(".tres") and path.begins_with("res://data/units/ennemie/"))
	var unit_records: Array[Dictionary] = []
	var standalone_spells: Array[Dictionary] = []
	var status_records: Array[Dictionary] = []
	var terrain_records: Array[Dictionary] = []
	var load_failures: Array[String] = []
	var player_spell_paths := {}
	var enemy_spell_paths := {}

	for path in data_files:
		if not path.ends_with(".tres"):
			continue
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			load_failures.append(path)
			continue
		if resource is UnitData and _is_production_content(path):
			var unit := resource as UnitData
			var spell_paths: Array[String] = []
			for spell_value in unit.spells:
				var spell := spell_value as Spell
				if spell == null:
					continue
				var spell_path := spell.resource_path
				if spell_path.is_empty():
					spell_path = "embedded:%s:%s" % [path, spell.get_effective_spell_id()]
				spell_paths.append(spell_path)
				if unit.team == 0:
					player_spell_paths[spell_path] = true
				else:
					enemy_spell_paths[spell_path] = true
			unit_records.append({
				"path": path,
				"unit_id": str(unit.unit_id),
				"display_name": unit.unit_name,
				"team": "PLAYER" if unit.team == 0 else "ENEMY",
				"spell_paths": spell_paths,
				"spell_count": spell_paths.size(),
				"has_custom_visual": unit.visual_scene != null,
				"has_sprite_frames": unit.sprite_frames != null,
			})
		elif resource is Spell and _is_production_content(path):
			standalone_spells.append(_spell_record(resource as Spell, path))
		elif resource is StatusData and _is_production_content(path):
			var status := resource as StatusData
			status_records.append({
				"path": path,
				"status_id": str(status.get_effective_status_id()),
				"display_name": status.status_name,
				"damage_per_turn": status.damage_per_turn,
				"heal_per_turn": status.heal_per_turn,
				"has_vfx": status.vfx_scene != null,
				"vfx_scene": status.vfx_scene.resource_path if status.vfx_scene != null else "",
			})
		elif resource is TerrainEffectData and _is_production_content(path):
			var terrain := resource as TerrainEffectData
			terrain_records.append({
				"path": path,
				"display_name": terrain.effect_name,
				"trigger": terrain.trigger,
				"damage": terrain.damage,
				"applies_status": terrain.applied_status != null,
				"blocks_movement": terrain.blocks_movement,
				"blocks_vision": terrain.blocks_vision,
			})

	unit_records.sort_custom(func(a: Dictionary, b: Dictionary): return a.path < b.path)
	standalone_spells.sort_custom(func(a: Dictionary, b: Dictionary): return a.path < b.path)
	status_records.sort_custom(func(a: Dictionary, b: Dictionary): return a.path < b.path)
	terrain_records.sort_custom(func(a: Dictionary, b: Dictionary): return a.path < b.path)

	var player_spells: Array[Dictionary] = []
	var enemy_spells: Array[Dictionary] = []
	var unreferenced_spells: Array[Dictionary] = []
	for record in standalone_spells:
		var path := str(record.path)
		if player_spell_paths.has(path):
			record["consumer_class"] = "PLAYER"
			player_spells.append(record)
		elif enemy_spell_paths.has(path):
			record["consumer_class"] = "ENEMY"
			enemy_spells.append(record)
		else:
			record["consumer_class"] = "UNREFERENCED_OR_INDIRECT"
			unreferenced_spells.append(record)

	var spell_surface: Array[Dictionary] = []
	spell_surface.append_array(player_spells)
	spell_surface.append_array(enemy_spells)
	spell_surface.append_array(unreferenced_spells)
	var visual_counts := _visual_technology_counts(project_files)
	var vfx_scene_paths := {}
	for spell in spell_surface:
		if not str(spell.vfx_scene).is_empty():
			vfx_scene_paths[str(spell.vfx_scene)] = true
	for status in status_records:
		if not str(status.vfx_scene).is_empty():
			vfx_scene_paths[str(status.vfx_scene)] = true
	for path in project_files:
		if path.begins_with("res://battle/vfx/") and path.ends_with(".tscn"):
			vfx_scene_paths[path] = true

	var passive_paths: Array[String] = []
	for path in data_files:
		if path.ends_with(".tres") and "/upgrades/" in path and _is_production_content(path):
			passive_paths.append(path)
	passive_paths.sort()

	var inventory := {
		"schema_version": 1,
		"repository_head": _git_head(),
		"scope": "HEAD production resources; DEBUG/CHEAT/TEST/PLACEHOLDER paths excluded from production totals",
		"production": {
			"hero_unit_files": hero_unit_files,
			"enemy_unit_files": enemy_unit_files,
			"heroes": unit_records.filter(func(unit): return unit.team == "PLAYER"),
			"enemies": unit_records.filter(func(unit): return unit.team == "ENEMY"),
			"player_spells": player_spells,
			"enemy_spells": enemy_spells,
			"unreferenced_or_indirect_spells": unreferenced_spells,
			"passive_upgrade_resources": passive_paths,
			"statuses": status_records,
			"terrain_effects": terrain_records,
		},
		"counts": {
			"hero_unit_files": hero_unit_files.size(),
			"loadable_heroes": unit_records.filter(func(unit): return unit.team == "PLAYER").size(),
			"enemy_unit_files": enemy_unit_files.size(),
			"loadable_enemy_units": unit_records.filter(func(unit): return unit.team == "ENEMY").size(),
			"standalone_spell_resources": standalone_spells.size(),
			"player_spells": player_spells.size(),
			"enemy_spells": enemy_spells.size(),
			"unreferenced_or_indirect_spells": unreferenced_spells.size(),
			"passive_upgrade_resources": passive_paths.size(),
			"statuses": status_records.size(),
			"terrain_effects": terrain_records.size(),
			"spells_with_vfx": spell_surface.filter(func(spell): return not str(spell.vfx_scene).is_empty()).size(),
			"spells_without_vfx": spell_surface.filter(func(spell): return str(spell.vfx_scene).is_empty()).size(),
			"statuses_with_vfx": status_records.filter(func(status): return bool(status.has_vfx)).size(),
			"statuses_without_vfx": status_records.filter(func(status): return not bool(status.has_vfx)).size(),
			"shield_spells": spell_surface.filter(func(spell): return int(spell.shield_grant) > 0).size(),
			"healing_spells": spell_surface.filter(func(spell): return int(spell.heal) > 0).size(),
			"damaging_spells": spell_surface.filter(func(spell): return int(spell.damage) > 0).size(),
			"status_spells": spell_surface.filter(func(spell): return bool(spell.applies_status)).size(),
			"terrain_spells": spell_surface.filter(func(spell): return bool(spell.places_terrain)).size(),
			"push_spells": spell_surface.filter(func(spell): return int(spell.push_distance) > 0).size(),
			"pull_spells": spell_surface.filter(func(spell): return int(spell.pull_distance) > 0).size(),
			"collision_spells": spell_surface.filter(func(spell): return int(spell.collision_damage) > 0).size(),
			"teleport_spells": spell_surface.filter(func(spell): return bool(spell.teleport)).size(),
			"summon_spells": spell_surface.filter(func(spell): return bool(spell.summon)).size(),
			"aoe_or_line_spells": spell_surface.filter(func(spell): return int(spell.aoe_shape) != Spell.AoeShape.SINGLE or bool(spell.line_from_caster)).size(),
			"distinct_vfx_scenes": vfx_scene_paths.size(),
		},
		"visual_technology": visual_counts,
		"vfx_scene_paths": vfx_scene_paths.keys(),
		"excluded_or_debt": {
			"debug_test_placeholder_tres": data_files.filter(func(path): return path.ends_with(".tres") and not _is_production_content(path)),
			"load_failures": load_failures,
			"unloadable_unit_files": load_failures.filter(func(path): return "/units/" in path),
			"historical_lab_profiles": 6,
			"historical_fireball_variants": 3,
		},
	}
	(inventory.vfx_scene_paths as Array).sort()
	_write_json(INVENTORY_JSON, inventory)
	_write_text(INVENTORY_REPORT, _markdown_report(inventory))
	print("VFX_FEASIBILITY_INVENTORY=%s" % ProjectSettings.globalize_path(INVENTORY_JSON))
	print("VFX_FEASIBILITY_REPORT=%s" % ProjectSettings.globalize_path(INVENTORY_REPORT))
	print("VFX_FEASIBILITY_COUNTS=%s" % JSON.stringify(inventory.counts))
	quit(0)


func _spell_record(spell: Spell, path: String) -> Dictionary:
	return {
		"path": path,
		"spell_id": str(spell.get_effective_spell_id()),
		"display_name": spell.spell_name,
		"vfx_scene": spell.vfx_scene.resource_path if spell.vfx_scene != null else "",
		"vfx_placement": spell.vfx_placement,
		"damage": spell.damage,
		"heal": spell.heal,
		"shield_grant": spell.shield_grant,
		"applies_status": spell.applied_status != null,
		"places_terrain": spell.terrain_effect != null,
		"push_distance": spell.push_distance,
		"pull_distance": spell.pull_distance,
		"collision_damage": spell.collision_damage,
		"teleport": spell.teleport_behind_target,
		"summon": spell.is_summon(),
		"aoe_shape": spell.aoe_shape,
		"aoe_size": spell.aoe_size,
		"line_from_caster": spell.line_from_caster,
		"element": spell.element,
		"impact_delay_seconds": spell.impact_delay_seconds,
	}


func _visual_technology_counts(paths: Array[String]) -> Dictionary:
	var result := {
		"shader_files": 0,
		"material_resource_files": 0,
		"scene_files": 0,
		"vfx_layer_scenes": 0,
		"gpu_particles_nodes": 0,
		"cpu_particles_nodes": 0,
		"animation_player_nodes": 0,
		"shader_material_references": 0,
	}
	for path in paths:
		if path.ends_with(".gdshader"):
			result.shader_files += 1
		if path.ends_with(".material"):
			result.material_resource_files += 1
		if not path.ends_with(".tscn") and not path.ends_with(".tres"):
			continue
		if path.ends_with(".tscn"):
			result.scene_files += 1
		var text := _read_text(path)
		if "name=\"VFXLayer\"" in text or "name = \"VFXLayer\"" in text:
			result.vfx_layer_scenes += 1
		result.gpu_particles_nodes += text.count("type=\"GPUParticles2D\"")
		result.cpu_particles_nodes += text.count("type=\"CPUParticles2D\"")
		result.animation_player_nodes += text.count("type=\"AnimationPlayer\"")
		result.shader_material_references += text.count("ShaderMaterial")
	return result


func _is_production_content(path: String) -> bool:
	var upper := path.to_upper()
	for marker in ["/TEST/", "/TESTS/", "/DEBUG/", "/CHEAT/", "/PLACEHOLDER/"]:
		if marker in upper:
			return false
	return true


func _collect_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var directory_path: String = directories.pop_back()
		var directory := DirAccess.open(directory_path)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if entry.begins_with(".") or entry in [".godot", ".git"]:
				entry = directory.get_next()
				continue
			var path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				directories.append(path)
			else:
				result.append(path)
			entry = directory.get_next()
		directory.list_dir_end()
	result.sort()
	return result


func _collect_visual_source_files() -> Array[String]:
	# Deliberately exclude exported/cached project copies (notably output/) and
	# generated artifacts: they would multiply every scene and shader count.
	var roots: Array[String] = [
		"res://asset",
		"res://assets",
		"res://battle",
		"res://characters",
		"res://core",
		"res://data",
		"res://hub",
		"res://tools/labs/vfx_lab",
		"res://ui",
		"res://units",
	]
	var unique := {}
	for root in roots:
		for path in _collect_files(root):
			unique[path] = true
	var result: Array[String] = []
	for path in unique.keys():
		result.append(str(path))
	result.sort()
	return result


func _git_head() -> String:
	var output: Array = []
	OS.execute("git", PackedStringArray(["rev-parse", "HEAD"]), output, true)
	return str(output[0]).strip_edges() if not output.is_empty() else "UNKNOWN"


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "  ", false))


func _write_text(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Impossible d'ecrire %s" % path)
		return
	file.store_string(content)
	file.close()


func _markdown_report(inventory: Dictionary) -> String:
	var counts := inventory.counts as Dictionary
	var tech := inventory.visual_technology as Dictionary
	var lines: Array[String] = [
		"# Inventaire VFX Studio — Phase A",
		"",
		"- HEAD observé : `%s`" % inventory.repository_head,
		"- Périmètre : ressources du HEAD ; TEST/DEBUG/CHEAT/PLACEHOLDER séparés.",
		"",
		"## Surface de production observée",
		"",
		"| Catégorie | Nombre |",
		"|---|---:|",
	]
	for key in [
		"hero_unit_files", "loadable_heroes", "enemy_unit_files",
		"loadable_enemy_units", "standalone_spell_resources",
		"player_spells", "enemy_spells",
		"passive_upgrade_resources", "statuses", "terrain_effects",
		"spells_with_vfx", "spells_without_vfx", "statuses_with_vfx",
		"statuses_without_vfx", "shield_spells", "healing_spells",
		"damaging_spells", "status_spells", "terrain_spells", "push_spells",
		"pull_spells", "collision_spells", "teleport_spells", "summon_spells",
		"aoe_or_line_spells", "distinct_vfx_scenes",
	]:
		lines.append("| %s | %d |" % [key, int(counts.get(key, 0))])
	lines.append_array([
		"", "## Technologies visuelles observées", "",
		"| Élément | Occurrences |", "|---|---:|",
	])
	for key in tech.keys():
		lines.append("| %s | %d |" % [key, int(tech[key])])
	lines.append_array([
		"", "## Limites de comptage", "",
		"Les sorts sont classés joueur/ennemi par les `UnitData` de production qui les référencent. Les ressources non directement référencées sont conservées séparément. Les événements UI et les consommateurs indirects nécessitent l’audit de code associé et ne sont pas déduits de ces seuls nombres.",
	])
	return "\n".join(lines) + "\n"
