@tool
class_name ArenaValidator
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]

static var _cache := {}


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
	var cache_key := ArenaSnapshotService.room_fingerprint(arena)
	if not check_duplicate_id and _cache.has(cache_key):
		var cached := (_cache[cache_key] as ArenaValidationReport).duplicate(true) \
			as ArenaValidationReport
		cached.set_meta("cache_hit", true)
		return cached
	report.arena_id = arena.arena_id
	var runtime_state := ArenaRuntimeProjectionService.build(arena)
	_validate_identity(arena, report, check_duplicate_id)
	_validate_calibration(arena, report, runtime_state)
	_validate_cells(arena, report)
	_validate_visual_resources(arena, report)
	_validate_field_coverage(report)
	_validate_runtime(arena, report, runtime_state)
	_validate_topology_parity(arena, report)
	_build_metrics(arena, report, runtime_state)
	report.set_meta("cache_hit", false)
	if not check_duplicate_id:
		_cache[cache_key] = report.duplicate(true)
	return report


static func clear_cache() -> void:
	_cache.clear()


static func cache_size() -> int:
	return _cache.size()


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
		report: ArenaValidationReport,
		runtime_state: ArenaRuntimeState
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
	elif runtime_state != null and runtime_state.visual_data != null:
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
		var rms := runtime_state.visual_data.calibration_rms()
		if rms > GridTransformService.QUALITY_ACCEPTABLE_RMS:
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"calibration_error",
				"L'alignement de la grille est a verifier (erreur %.1f px)." % rms)
		var maximum := runtime_state.visual_data.calibration_max_error()
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
	var verified_overrides: Array[Dictionary] = []
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
		else:
			var terrain_entry := ArenaTerrainRegistry.get_entry(definition.terrain_id)
			var expected_defined := definition.terrain_id != &"void"
			var expected_playable := bool(terrain_entry.get("walkable", false)) \
				and not definition.border
			var expected_type := int(terrain_entry.get("cell_type", GridData.CellType.HOLE))
			var mismatches: Array[String] = []
			if definition.defined != expected_defined:
				mismatches.append("defined")
			if definition.playable != expected_playable:
				mismatches.append("playable")
			if definition.cell_type != expected_type:
				mismatches.append("cell_type")
			if definition.terrain_id == &"void" and (definition.defined or definition.playable):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"void_cell_coherence",
					"Une case void ne peut etre ni definie ni jouable.", cell
				)
			elif not mismatches.is_empty():
				var justified := not definition.production_note.strip_edges().is_empty()
				if justified:
					verified_overrides.append({
						"cell": cell,
						"fields": mismatches.duplicate(),
						"justification": definition.production_note,
					})
				else:
					report.add_message(
						ArenaValidationMessage.Severity.ERROR,
						&"terrain_coherence_mismatch",
						"L'override de terrain touche %s sans justification." % \
							", ".join(mismatches),
						cell, &"align_cell_with_terrain_registry"
					)
			var visual_path := str(terrain_entry.get("visual", ""))
			if definition.defined and (visual_path.is_empty() \
					or not ResourceLoader.exists(visual_path)) \
					and arena.visual_mode != ArenaDefinition.VisualMode.PAINTED:
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"terrain_without_visual",
					"Le terrain '%s' n'a pas de visuel modulaire." % definition.terrain_id,
					cell)
	if not verified_overrides.is_empty():
		report.add_message(
			ArenaValidationMessage.Severity.INFO,
			&"terrain_overrides_verified",
			"%d override(s) de terrain verifie(s) et coherents." % \
				verified_overrides.size(),
			verified_overrides[0].cell,
			&"",
			JSON.stringify(verified_overrides, "  ")
		)
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
	_validate_vortex_pairs(arena, report)


static func _validate_obstacles_and_spawns(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	var occupied := {}
	var required_heroes := {
		ArenaSpawnDefinition.Kind.HERO_1: 0,
		ArenaSpawnDefinition.Kind.HERO_2: 0,
		ArenaSpawnDefinition.Kind.HERO_3: 0,
	}
	var hero_pool_count := 0
	var enemy_count := 0
	var obstacle_cells := {}
	var obstacle_ids := {}
	for obstacle in arena.obstacles:
		if obstacle == null or not arena.is_in_bounds(obstacle.cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"invalid_obstacle",
				"Un obstacle se trouve hors de l'arene.")
			continue
		if obstacle_cells.has(obstacle.cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"duplicate_obstacle_cell",
				"Deux obstacles occupent la meme cellule.", obstacle.cell
			)


		obstacle_cells[obstacle.cell] = true
		if obstacle.obstacle_id == &"" or obstacle_ids.has(obstacle.obstacle_id):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"duplicate_obstacle_id",
				"Chaque obstacle doit posseder un identifiant unique.", obstacle.cell
			)
		obstacle_ids[obstacle.obstacle_id] = true
		if not DIRECTIONS.has(obstacle.orientation):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"obstacle_orientation_invalid",
				"L'orientation de l'obstacle doit etre cardinale.", obstacle.cell
			)
		var expected_flags := _obstacle_preset_flags(obstacle.preset)
		for flag in expected_flags:
			if bool(obstacle.get(flag)) != bool(expected_flags[flag]):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"obstacle_preset_flag_mismatch",
					"Le preset et le flag %s ne sont pas coherents." % flag,
					obstacle.cell, &"apply_obstacle_preset"
				)
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
			elif obstacle.wall_config != null \
					and ArenaWallRegistry.id_for_config(obstacle.wall_config) != obstacle.wall_id:
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"wall_config_mismatch",
					"La WallConfig ne correspond pas au wall_id selectionne.",
					obstacle.cell
				)
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
			hero_pool_count += 1
			if spawn.required:
				required_heroes[spawn.kind] = int(required_heroes.get(spawn.kind, 0)) + 1
		elif spawn.is_enemy():
			enemy_count += 1
		if not DIRECTIONS.has(spawn.facing):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"spawn_facing_invalid",
				"L'orientation du spawn doit etre cardinale.", spawn.cell
			)
		if spawn.kind == ArenaSpawnDefinition.Kind.ENEMY_GROUP and spawn.group_id == &"":
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"spawn_group_id_missing",
				"Un spawn de groupe ennemi requiert un group_id.", spawn.cell
			)
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
		elif not definition.playable \
				or (arena.obstacle_at(spawn.cell) != null \
					and arena.obstacle_at(spawn.cell).blocks_movement):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"spawn_blocked",
				"%s ne possede pas de position de depart valide." % spawn.display_label(),
				spawn.cell, &"move_spawn_to_nearest_valid")
		if occupied.has(spawn.cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"spawn_collision",
				"Deux unites utilisent la meme position de depart.", spawn.cell)
		occupied[spawn.cell] = true
	for kind in required_heroes:
		if int(required_heroes[kind]) != 1:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"required_hero_spawn_contract",
				"Chaque emplacement HERO_1, HERO_2 et HERO_3 doit exister exactement une fois en obligatoire."
			)
	if hero_pool_count < 3:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"hero_pool_too_small",
			"Le pool de deploiement heros doit contenir au moins trois cellules.")
		# Code historique conserve pour les integrations et rapports existants.
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"missing_heroes",
			"La map ne peut pas etre testee : trois positions heros valides sont requises."
		)
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
		elif not ArenaObjectiveRegistry.has(objective.objective_type):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"objective_type_unknown",
				"Le type d'objectif '%s' n'est pas enregistre." % objective.objective_type,
				objective.cell
			)
		else:
			var obstacle := arena.obstacle_at(objective.cell)
			if obstacle != null and obstacle.blocks_movement:
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"objective_obstacle_collision",
					"Un objectif obligatoire ne peut pas etre masque par un obstacle bloquant.",
					objective.cell
				)
	for decoration in arena.decorations:
		if decoration == null or not arena.is_in_bounds(decoration.cell):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"decoration_out_of_bounds",
				"Un prop est place hors de l'arene.",
				decoration.cell if decoration != null else GridTransformService.INVALID_CELL)
		elif not ArenaDecorationLayerRegistry.has(decoration.layer):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"decoration_layer_unknown",
				"La couche de decoration '%s' n'est pas enregistree." % decoration.layer,
				decoration.cell
			)
		elif decoration.scene_path.is_empty() or not ResourceLoader.exists(decoration.scene_path):
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"prop_without_preview",
				"Le prop '%s' utilisera le marqueur de secours." % decoration.decoration_id,
				decoration.cell)


static func _validate_vortex_pairs(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	if arena.vortex_pairs.is_empty():
		_validate_vortex_networks(arena, report)
		return
	var catalog := ArenaCatalogService.interactive(&"vortex")
	if catalog == null:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"vortex_catalog_missing",
			"La définition de catalogue du vortex est absente."
		)
		return
	var pair_ids := {}
	var occupied_cells := {}
	for pair in arena.vortex_pairs:
		if pair == null:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"vortex_pair_missing",
				"Une paire de vortex est vide."
			)
			continue
		if pair.pair_id == &"" or pair_ids.has(pair.pair_id):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"vortex_pair_id_invalid",
				"Chaque paire de vortex doit posséder un pair_id unique.",
				pair.entry_cell
			)
		pair_ids[pair.pair_id] = true
		if pair.entry_cell == pair.exit_cell:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"vortex_endpoints_identical",
				"L'entrée et la sortie d'un vortex doivent être distinctes.",
				pair.entry_cell
			)
		for cell in [pair.entry_cell, pair.exit_cell]:
			if not ArenaDynamicEditingService.is_valid_vortex_cell(arena, cell):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"vortex_endpoint_invalid",
					"Le vortex doit être sur une dalle définie, praticable, hors bordure et non bloquée.",
					cell
				)
			if occupied_cells.has(cell):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"vortex_endpoint_reused",
					"Une cellule ne peut appartenir qu'à une seule paire de vortex.",
					cell
				)
			occupied_cells[cell] = pair.pair_id
		if pair.traversal_contract != catalog.traversal_contract:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"vortex_traversal_contract_mismatch",
				"Le contrat de traversée du vortex ne correspond pas au catalogue.",
				pair.entry_cell
			)
		if not pair.runtime_enabled:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"vortex_runtime_disabled",
				"Une paire de vortex de production doit activer son runtime.",
				pair.entry_cell
			)
	if not catalog.is_production_certified():
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"vortex_catalog_uncertified",
			"Le catalogue Vortex doit certifier runtime, Pathfinder, IA et production."
		)
	_validate_vortex_networks(arena, report)


static func _validate_vortex_networks(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	var ids := {}
	var occupied := {}
	for network in arena.vortex_networks:
		if network == null:
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"vortex_network_missing",
				"Un réseau de vortex est vide."
			)
			continue
		if network.network_id == &"" or ids.has(network.network_id):
			report.add_message(
				ArenaValidationMessage.Severity.ERROR, &"vortex_network_id_invalid",
				"Chaque réseau doit posséder un network_id unique."
			)
		ids[network.network_id] = true
		if network.cells.is_empty():
			report.add_message(
				ArenaValidationMessage.Severity.WARNING, &"vortex_network_empty",
				"Le réseau '%s' ne contient aucune dalle." % network.display_name
			)
		for cell in network.unique_cells():
			if occupied.has(cell):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"vortex_network_cell_reused",
					"Une cellule ne peut appartenir qu'à un réseau.", cell
				)
			occupied[cell] = network.network_id
			if not ArenaDynamicEditingService.is_valid_vortex_cell(arena, cell):
				report.add_message(
					ArenaValidationMessage.Severity.ERROR, &"vortex_network_cell_invalid",
					"Le réseau contient une destination invalide.", cell
				)


static func _validate_visual_resources(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	var theme_resolution := ArenaThemeRegistry.resolve(arena)
	if not bool(theme_resolution.get("ok", false)):
		report.add_message(
			ArenaValidationMessage.Severity.WARNING, &"theme_surface_configuration_missing",
			"Le theme '%s' ne fournit aucune configuration de surface ; aucun fallback silencieux ne sera applique." % arena.theme_id,
			GridTransformService.INVALID_CELL, &"choose_registered_theme",
			str(theme_resolution.get("warning", ""))
		)
	elif bool(theme_resolution.get("fallback_used", false)):
		report.add_message(
			ArenaValidationMessage.Severity.INFO, &"theme_alias_resolved",
			"L'alias de theme '%s' est resolu explicitement vers '%s'." % [
				theme_resolution.requested_theme_id,
				theme_resolution.resolved_theme_id,
			]
		)
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
			ArenaValidationMessage.Severity.INFO, &"foreground_missing",
			"Aucun foreground n'est configure.")


static func _validate_field_coverage(report: ArenaValidationReport) -> void:
	var coverage := ArenaRuntimeFieldCoverageService.scan()
	if not bool(coverage.production_gate_valid):
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"runtime_field_coverage_incomplete",
			"La couverture des champs runtime contient %d champ(s) inconnu(s) et %d champ(s) gameplay non supporte(s)." % [
				coverage.unknown.size(), coverage.unsupported_gameplay.size(),
			]
		)


static func _validate_runtime(
		arena: ArenaDefinition,
		report: ArenaValidationReport,
		runtime_state: ArenaRuntimeState
	) -> void:
	var grid := runtime_state.grid if runtime_state != null else null
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
	var visual_report := ArenaVisualAssembler.inspect(arena)
	if not visual_report.valid:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR,
			&"visual_assembly_incomplete",
			"Le sol visuel réel est incomplet : %d dalle(s) rendue(s) sur %d attendue(s)." % [
				visual_report.rendered_terrain_node_count,
				visual_report.expected_terrain_cell_count,
			]
		)
	var tactical := ArenaTacticalMetricsService.analyze(arena, runtime_state)
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
	var topology := tactical.get("topology", {}) as Dictionary
	var corridor_count := int(topology.get("width_one_corridor_count", 0))
	var articulation_count := int(topology.get("articulation_point_count", 0))
	if corridor_count > 0 or articulation_count > 0:
		var location := GridTransformService.INVALID_CELL
		var corridor_cells: Array = topology.get("width_one_corridors", [])
		if not corridor_cells.is_empty():
			location = corridor_cells[0]
		report.add_message(
			ArenaValidationMessage.Severity.WARNING, &"narrow_passages",
			"%d cellule(s) de corridor et %d articulation(s) tactique(s) sont a verifier." % [
				corridor_count, articulation_count,
			], location, &"select_chokepoints")
	var camps := tactical.get("camps", {}) as Dictionary
	if int(camps.get("unreachable_pair_count", 0)) > 0:
		report.add_message(
			ArenaValidationMessage.Severity.ERROR, &"camps_disconnected",
			"%d paire(s) heros-ennemi ne disposent d'aucun chemin." % int(
				camps.unreachable_pair_count
			)
		)


static func _validate_topology_parity(
		arena: ArenaDefinition,
		report: ArenaValidationReport
	) -> void:
	var topology := ArenaTopologySignatureService.build(arena)
	var plan := ArenaTerrainRenderPlanService.build(arena)
	var visual := ArenaVisualAssembler.inspect(arena)
	var duplicates: Array[String] = []
	for key in visual.terrain_nodes:
		if int((visual.terrain_nodes[key] as Dictionary).get("duplication_count", 1)) > 1:
			duplicates.append(str(key))
	var parity := ArenaTopologyParityReport.compare_floor_sets(
		plan.get("expected_floor_cells", []), visual.terrain_nodes.keys(),
		topology.removed_cells, duplicates
	)
	report.add_message(
		ArenaValidationMessage.Severity.INFO,
		&"topology_summary",
		"Topologie : %d cellules definies, %d dalles attendues, %d rendues, %d case(s) retiree(s) rendue(s), %d inattendue(s), %d manquante(s)." % [
			topology.counts.defined_cells,
			plan.get("expected_floor_cells", []).size(),
			visual.terrain_nodes.size(),
			parity.removed_cells_rendered.size(),
			parity.unexpected_cells.size(),
			parity.missing_cells.size(),
		],
		GridTransformService.INVALID_CELL,
		&"",
		JSON.stringify(parity.to_dict(), "  ")
	)
	if parity.valid:
		return
	var divergent := []
	divergent.append_array(parity.removed_cells_rendered)
	divergent.append_array(parity.unexpected_cells)
	divergent.append_array(parity.missing_cells)
	divergent.append_array(parity.duplicate_cells)
	var location := ArenaTopologySignatureService.key_to_coordinate(str(divergent[0])) \
		if not divergent.is_empty() else GridTransformService.INVALID_CELL
	report.add_message(
		ArenaValidationMessage.Severity.ERROR,
		&"topology_floor_mismatch",
		"TOPOLOGIE STUDIO / RUNTIME DIFFERENTE : %d case(s) retiree(s) sont encore rendues." % parity.removed_cells_rendered.size(),
		location,
		&"recalculate_topology",
		JSON.stringify(parity.to_dict(), "  ")
	)


static func _build_metrics(
		arena: ArenaDefinition,
		report: ArenaValidationReport,
		runtime_state: ArenaRuntimeState
	) -> void:
	var tactical := ArenaTacticalMetricsService.analyze(arena, runtime_state)
	var topology := tactical.get("topology", {}) as Dictionary
	var camps := tactical.get("camps", {}) as Dictionary
	var spawn_metrics := tactical.get("spawns", {}) as Dictionary
	report.metrics = {
		"dimensions": [arena.grid_size.x, arena.grid_size.y],
		"defined_cells": arena.defined_cells().size(),
		"playable_cells": arena.playable_cells().size(),
		"border_cells": arena.border_cells().size(),
		"obstacles": arena.obstacles.size(),
		"components": int(topology.get("components", 0)),
		"minimum_camp_distance": int(camps.get("minimum_distance", -1)),
		"median_camp_distance": float(camps.get("median_distance", -1.0)),
		"average_camp_distance": float(camps.get("average_distance", -1.0)),
		"p90_camp_distance": int(camps.get("p90_distance", -1)),
		"maximum_camp_distance": int(camps.get("maximum_distance", -1)),
		"spawns": spawn_metrics,
		"terrains": _terrain_ids(arena),
		"walls": _wall_ids(arena),
		"objectives": arena.objectives.size(),
		"props": arena.decorations.size(),
		"visual_mode": arena.visual_mode,
		"visual_profile": str(arena.theme_id),
		"battle_scene": arena.battle_scene.resource_path if arena.battle_scene != null else "",
		"visual_assembly": ArenaVisualAssembler.inspect(arena).to_dict(),
		"tactical": tactical,
		"runtime_field_coverage": ArenaRuntimeFieldCoverageService.scan(),
	}
	report.add_message(
		ArenaValidationMessage.Severity.INFO, &"map_summary",
		"%d cases jouables, %d cases de bordure, %d obstacle(s), %d spawn(s)." % [
			arena.playable_cells().size(), arena.border_cells().size(),
			arena.obstacles.size(), arena.spawns.size(),
		]
	)


static func _obstacle_preset_flags(preset: int) -> Dictionary:
	match preset:
		ArenaObstacleDefinition.Preset.LOW_OBSTACLE:
			return {
				"blocks_movement": true, "blocks_line_of_sight": false,
				"blocks_projectiles": false, "blocks_push": true,
			}
		ArenaObstacleDefinition.Preset.PASSABLE_DECOR:
			return {
				"blocks_movement": false, "blocks_line_of_sight": false,
				"blocks_projectiles": false, "blocks_push": false,
			}
		ArenaObstacleDefinition.Preset.CLIFF:
			return {
				"blocks_movement": true, "blocks_line_of_sight": false,
				"blocks_projectiles": false, "blocks_push": true,
			}
		_:
			return {
				"blocks_movement": true, "blocks_line_of_sight": true,
				"blocks_projectiles": true, "blocks_push": true,
			}


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
