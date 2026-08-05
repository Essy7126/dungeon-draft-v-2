@tool
class_name ArenaValidator
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]


static func validate(arena: ArenaDefinition, check_duplicate_id := true) -> ArenaValidationReport:
	var report := ArenaValidationReport.new()
	report.generated_at = Time.get_datetime_string_from_system(true)
	if arena == null:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR,
			&"arena_missing",
			"Aucune map n'est ouverte."
		)
		return report
	report.arena_id = arena.arena_id
	_validate_identity(arena, report, check_duplicate_id)
	_validate_calibration(arena, report)
	_validate_cells(arena, report)
	_validate_visual_resources(arena, report)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_validate_runtime(arena, report)
	_build_metrics(arena, report)
	return report


static func _validate_identity(
		arena: ArenaDefinition,
		report: ArenaValidationReport,
		check_duplicate_id: bool
	) -> void:
	if str(arena.arena_id).strip_edges().is_empty():
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"missing_id",
			"La map doit posseder un identifiant.")
	if arena.display_name.strip_edges().is_empty():
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"missing_name",
			"La map doit posseder un nom visible.")
	if check_duplicate_id and _has_duplicate_id(arena):
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"duplicate_id",
			"Une autre arene utilise deja cet identifiant.")
	if arena.visual_mode != ArenaDefinition.VisualMode.MODULAR \
			and arena.background_path.is_empty():
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"missing_background",
			"Ajoutez une image de fond avant de tester la map.")
	elif not arena.background_path.is_empty() \
			and not arena.background_path.begins_with("res://") \
			and not arena.background_path.begins_with("uid://"):
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"absolute_background_path",
			"L'image doit etre importee dans le projet, pas liee par un chemin local.")
	elif not arena.background_path.is_empty() \
			and not ResourceLoader.exists(arena.background_path):
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"background_not_found",
			"L'image de fond est introuvable dans le projet.")
	if arena.schema_version != ArenaDefinition.CURRENT_SCHEMA_VERSION:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"schema_incompatible",
			"La version des donnees doit etre migree avant utilisation.")
	if arena.battle_scene == null:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"runtime_scene_missing",
			"La scene de combat reelle ne peut pas etre construite.")
	if arena.encounter_definition == null:
		report.add_message(
			ArenaValidationMessage.Severity.WARNING, &"encounter_missing",
			"Aucune rencontre n'est associee ; le test direct utilisera sa configuration de secours.")
	report.add_message(
		ArenaValidationMessage.Severity.INFO, &"visual_mode",
		"Mode visuel : %s." % ["PAINTED", "MODULAR", "HYBRID"][arena.visual_mode])
	report.add_message(
		ArenaValidationMessage.Severity.INFO, &"battle_scene",
		"Scene de bataille : %s." % (
			arena.battle_scene.resource_path if arena.battle_scene != null else "absente"
		))


static func _validate_calibration(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	if arena.grid_size.x <= 0 or arena.grid_size.y <= 0:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"invalid_dimensions",
			"Les dimensions de grille doivent etre positives.")
	elif arena.grid_size.x > 64 or arena.grid_size.y > 64:
		report.add_message(
			ArenaValidationMessage.Severity.WARNING, &"large_grid",
			"Cette grille depasse la cible de production verifiee de 64 x 64.")
	var transform_validation := GridTransformService.validate_snapshot(
		GridTransformSnapshot.from_arena(arena)
	)
	if not bool(transform_validation.get("ok", false)):
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"non_invertible_grid",
			"La grille ne peut pas etre utilisee : %s" % transform_validation.get(
				"error", "transformation invalide"
			),
			GridTransformService.INVALID_CELL, &"restart_calibration")
	if arena.source_image_size.x > 0 and arena.source_image_size.y > 0 \
			and arena.grid_size.x > 0 and arena.grid_size.y > 0:
		var bounds := GridTransformService.grid_bounds(
			GridTransformSnapshot.from_arena(arena), arena.grid_size
		)
		var image_bounds := Rect2(Vector2.ZERO, Vector2(arena.source_image_size))
		var visible_area := bounds.intersection(image_bounds).get_area()
		var ratio := visible_area / maxf(bounds.get_area(), 0.000001)
		if ratio <= 0.0:
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"grid_outside_image",
				"La grille se trouve entierement hors de l'image native."
			)
		elif ratio < 0.5:
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"grid_mostly_outside_image",
				"Une grande partie de la grille se trouve hors de l'image native."
			)
	if arena.visual_mode != ArenaDefinition.VisualMode.MODULAR \
			and (arena.calibration_cells.size() < 3 \
			or arena.calibration_cells.size() != arena.calibration_pixels.size()):
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"calibration_incomplete",
			"Terminez les trois clics de calibration.")
	elif arena.painted_map_visual_data != null:
		var unique := {}
		for cell in arena.calibration_cells:
			if not arena.is_in_bounds(cell):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"anchor_out_of_bounds",
					"Une ancre de calibration se trouve hors de la grille.", cell
				)
			elif unique.has(cell):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"duplicate_anchor",
					"Deux ancres de calibration ciblent la meme cellule.", cell
				)
			unique[cell] = true
		var fitted := GridTransformService.fit_affine(
			arena.calibration_cells, arena.calibration_pixels, arena.grid_size
		)
		if not bool(fitted.get("ok", false)):
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"anchor_distribution",
				"Les ancres sont insuffisamment reparties pour un ajustement fiable."
			)
		var rms := arena.painted_map_visual_data.calibration_rms()
		if rms > GridTransformService.QUALITY_ACCEPTABLE_RMS:
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"calibration_error",
				"L'alignement de la grille est a verifier (erreur %.1f px)." % rms)
		var maximum := arena.painted_map_visual_data.calibration_max_error()
		if maximum > GridTransformService.QUALITY_ACCEPTABLE_RMS * 2.0:
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"calibration_max_error",
				"Une ancre presente une erreur maximale elevee (%.1f px)." % maximum
			)


static func _validate_cells(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	var seen := {}
	for definition in arena.cells:
		if definition == null:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"missing_cell_resource",
				"Une definition de case est manquante.")
			continue
		var cell := definition.coordinate
		if seen.has(cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"duplicate_cell",
				"Cette case est definie plusieurs fois.", cell)
		seen[cell] = true
		if not arena.is_in_bounds(cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"cell_out_of_bounds",
				"Cette case se trouve hors des dimensions de la map.", cell)
		if definition.border and definition.playable:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"playable_border",
				"Une case de bordure ne peut pas etre jouable.", cell,
				&"make_border_non_playable")
		if not ArenaTerrainRegistry.has(definition.terrain_id):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"unknown_terrain",
				"Le terrain '%s' n'existe pas dans le registre partage." % definition.terrain_id,
				cell)
		elif definition.defined:
			var terrain_entry := ArenaTerrainRegistry.get_entry(definition.terrain_id)
			var visual_path := str(terrain_entry.get("visual", ""))
			if visual_path.is_empty() and arena.visual_mode != ArenaDefinition.VisualMode.PAINTED:
				report.add_message(
					ArenaValidationMessage.Severity.WARNING, &"terrain_without_visual",
					"Le terrain '%s' n'a pas de visuel modulaire." % definition.terrain_id,
					cell)
	if arena.playable_cells().is_empty():
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"no_playable_cell",
			"La map ne contient aucune case jouable.")
	if arena.border_cells().is_empty():
		report.add_message(
			ArenaValidationMessage.Severity.WARNING, &"missing_border",
			"La bordure de securite n'a pas encore ete creee.",
			GridTransformService.INVALID_CELL, &"create_border")
	_validate_obstacles_and_spawns(arena, report)


static func _validate_obstacles_and_spawns(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	var occupied := {}
	var hero_count := 0
	var enemy_count := 0
	for obstacle in arena.obstacles:
		if obstacle == null or not arena.is_in_bounds(obstacle.cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"invalid_obstacle",
				"Un obstacle se trouve hors de l'arene.")
			continue
		if obstacle.wall_id != &"":
			if not ArenaWallRegistry.has(obstacle.wall_id):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"unknown_wall",
					"Le mur '%s' n'existe pas dans le registre partage." % obstacle.wall_id,
					obstacle.cell)
			elif obstacle.wall_config == null \
					and ArenaWallRegistry.config_for(obstacle.wall_id) == null:
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"wall_config_missing",
					"La WallConfig du mur '%s' est absente." % obstacle.wall_id,
					obstacle.cell)
			var wall_visual := str(ArenaWallRegistry.get_entry(obstacle.wall_id).get("visual", ""))
			if wall_visual.is_empty() or not ResourceLoader.exists(wall_visual):
				report.add_message(
					ArenaValidationMessage.Severity.WARNING, &"wall_thumbnail_missing",
					"Le mur '%s' n'a pas de miniature disponible." % obstacle.wall_id,
					obstacle.cell)
	for spawn in arena.spawns:
		if spawn == null:
			continue
		if spawn.is_hero():
			hero_count += 1
		elif spawn.is_enemy():
			enemy_count += 1
		var definition := arena.get_cell_definition(spawn.cell)
		if definition == null or not definition.defined:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"spawn_outside",
				"%s est place hors de l'arene." % spawn.display_label(), spawn.cell)
		elif definition.border:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"spawn_on_border",
				"%s est place sur la bordure de securite." % spawn.display_label(),
				spawn.cell, &"move_spawn_to_nearest_valid")
		elif not definition.playable or arena.obstacle_at(spawn.cell) != null:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"spawn_blocked",
				"%s ne possede pas de position de depart valide." % spawn.display_label(),
				spawn.cell, &"move_spawn_to_nearest_valid")
		if occupied.has(spawn.cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"spawn_collision",
				"Deux unites utilisent la meme position de depart.", spawn.cell)
		occupied[spawn.cell] = true
	if hero_count < 3:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"missing_heroes",
			"La map ne peut pas etre testee : le trio Elfe, Mage et Guerrier ne dispose pas de trois positions valides.")
	if enemy_count == 0:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"missing_enemies",
			"Ajoutez au moins une position de depart ennemie.")
	for objective in arena.objectives:
		if objective == null or not arena.is_in_bounds(objective.cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"objective_out_of_bounds",
				"Un objectif est place hors de l'arene.",
				objective.cell if objective != null else GridTransformService.INVALID_CELL)
	for decoration in arena.decorations:
		if decoration == null or not arena.is_in_bounds(decoration.cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"decoration_out_of_bounds",
				"Un prop est place hors de l'arene.",
				decoration.cell if decoration != null else GridTransformService.INVALID_CELL)
		elif decoration.scene_path.is_empty() or not ResourceLoader.exists(decoration.scene_path):
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"prop_without_preview",
				"Le prop '%s' utilisera le marqueur de secours." % decoration.decoration_id,
				decoration.cell)


static func _validate_visual_resources(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	if arena.visual_mode in [ArenaDefinition.VisualMode.MODULAR, ArenaDefinition.VisualMode.HYBRID]:
		if arena.modular_visual_profile == null:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"modular_profile_missing",
				"Le profil visuel modulaire obligatoire est absent.")
		else:
			for terrain_id in arena.modular_visual_profile.terrain_ids:
				if not ArenaTerrainRegistry.has(terrain_id):
					report.add_message(
						ArenaValidationMessage.Severity.ERROR, &"profile_unknown_terrain",
						"Le profil visuel reference un terrain inconnu : %s." % terrain_id)
			for wall_id in arena.modular_visual_profile.wall_ids:
				if not ArenaWallRegistry.has(wall_id):
					report.add_message(
						ArenaValidationMessage.Severity.ERROR, &"profile_unknown_wall",
						"Le profil visuel reference un mur inconnu : %s." % wall_id)
	if arena.visual_mode == ArenaDefinition.VisualMode.HYBRID:
		var has_overlay := arena.cells.any(func(cell):
			return cell != null and cell.defined and cell.terrain_id not in [&"normal", &"stone"]
		) or not arena.obstacles.is_empty() or not arena.decorations.is_empty()
		if not has_overlay:
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"hybrid_without_overlays",
				"La map hybride ne contient aucun overlay dynamique.")
	if arena.visual_mode != ArenaDefinition.VisualMode.MODULAR \
			and arena.foreground_path.is_empty():
		report.add_message(
			ArenaValidationMessage.Severity.WARNING, &"foreground_missing",
			"Aucun foreground n'est configure.")


static func _validate_runtime(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	var grid := ArenaRuntimeBridge.build_grid(arena)
	if grid == null:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"grid_build_failed",
			"La grille de combat ne peut pas etre construite.")
		return
	var signature := ArenaVisualAssembler.structural_signature(arena)
	if signature.is_empty() or not signature.has("runtime"):
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"renderer_build_failed",
			"L'assembleur visuel partage ne peut pas construire la map.")
		return
	var playable := arena.playable_cells()
	if playable.is_empty():
		return
	var pathfinder := Pathfinder.new(grid)
	var reachable := pathfinder.get_reachable(
		playable[0], arena.grid_size.x * arena.grid_size.y
	)
	reachable.append(playable[0])
	var isolated: Array[Vector2i] = []
	for cell in playable:
		if not reachable.has(cell) and not arena.intentionally_isolated_cells.has(cell):
			isolated.append(cell)
	if not isolated.is_empty():
		report.add_message(
			ArenaValidationMessage.Severity.WARNING, &"isolated_cells",
			"%d cases jouables sont isolees du reste de l'arene." % isolated.size(),
			isolated[0], &"select_isolated_cells")
	var narrow_count := 0
	for cell in playable:
		var neighbors := 0
		for direction in DIRECTIONS:
			if grid.is_terrain_interactable(cell + direction):
				neighbors += 1
		if neighbors <= 1:
			narrow_count += 1
	if narrow_count > 0:
		report.add_message(
			ArenaValidationMessage.Severity.WARNING, &"narrow_passages",
			"%d cases forment des passages tres etroits." % narrow_count)
	if not arena.hero_spawn_zone.is_empty() and not arena.enemy_spawn_zone.is_empty():
		var path := pathfinder.find_path(
			arena.hero_spawn_zone[0], arena.enemy_spawn_zone[0]
		)
		if path.is_empty():
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"camps_disconnected",
				"Les heros ne peuvent pas rejoindre le camp ennemi.")


static func _build_metrics(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	var grid := ArenaRuntimeBridge.build_grid(arena)
	var components := 0
	var remaining := arena.playable_cells()
	while not remaining.is_empty() and grid != null:
		components += 1
		var start := remaining[0]
		var connected := Pathfinder.new(grid).get_reachable(
			start, arena.grid_size.x * arena.grid_size.y
		)
		connected.append(start)
		for cell in connected:
			remaining.erase(cell)
	var camp_distance := -1
	if grid != null and not arena.hero_spawn_zone.is_empty() \
			and not arena.enemy_spawn_zone.is_empty():
		var path := Pathfinder.new(grid).find_path(
			arena.hero_spawn_zone[0], arena.enemy_spawn_zone[0]
		)
		camp_distance = maxi(0, path.size() - 1) if not path.is_empty() else -1
	report.metrics = {
		"dimensions": [arena.grid_size.x, arena.grid_size.y],
		"defined_cells": arena.defined_cells().size(),
		"playable_cells": arena.playable_cells().size(),
		"border_cells": arena.border_cells().size(),
		"obstacles": arena.obstacles.size(),
		"components": components,
		"minimum_camp_distance": camp_distance,
		"spawns": arena.spawns.size(),
		"terrains": _terrain_ids(arena),
		"walls": _wall_ids(arena),
		"objectives": arena.objectives.size(),
		"props": arena.decorations.size(),
		"visual_mode": arena.visual_mode,
		"visual_profile": str(arena.theme_id),
		"battle_scene": arena.battle_scene.resource_path if arena.battle_scene != null else "",
	}
	report.add_message(
		ArenaValidationMessage.Severity.INFO, &"map_summary",
		"%d cases jouables, %d cases de bordure, %d obstacle(s), %d spawn(s)." % [
			arena.playable_cells().size(), arena.border_cells().size(),
			arena.obstacles.size(), arena.spawns.size(),
		]
	)


static func _terrain_ids(arena: ArenaDefinition) -> Array[String]:
	var ids: Array[String] = []
	for definition in arena.cells:
		if definition != null and not ids.has(str(definition.terrain_id)):
			ids.append(str(definition.terrain_id))
	ids.sort()
	return ids


static func _wall_ids(arena: ArenaDefinition) -> Array[String]:
	var ids: Array[String] = []
	for obstacle in arena.obstacles:
		if obstacle != null and obstacle.wall_id != &"" and not ids.has(str(obstacle.wall_id)):
			ids.append(str(obstacle.wall_id))
	ids.sort()
	return ids


static func _has_duplicate_id(arena: ArenaDefinition) -> bool:
	var directory := DirAccess.open(ArenaSerializer.CANONICAL_ROOT)
	if directory == null:
		return false
	for file_name in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var path := ArenaSerializer.CANONICAL_ROOT.path_join(file_name)
		if path == arena.resource_path:
			continue
		var other := load(path) as ArenaDefinition
		if other != null and other.arena_id == arena.arena_id:
			return true
	return false
