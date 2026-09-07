extends "res://battle/painted/painted_battle.gd"

const STYLE := preload("res://battle/painted/registered_terrain/terrain_style.gd")
const LIMESTONE_SHADER := preload("res://battle/painted/registered_terrain/shaders/stone_palette.gdshader")
const PLATFORM := preload("res://battle/painted/registered_terrain/platform.gd")
const WATER_SHADER := preload("res://battle/painted/registered_terrain/shaders/water_ink.gdshader")
const GROUND_BAND := preload("res://battle/painted/registered_terrain/combat_ground_band.gd")
const GROUND_DETAILS := preload("res://battle/painted/registered_terrain/ground_details.gd")
const TERRAIN_COMPOSITION := preload("res://battle/painted/registered_terrain/terrain_composition.gd")

# Optional scene override. Normal production rooms declare this on ArenaDefinition.
@export_file("*.json") var registered_terrain_plan_path := ""
signal registered_terrain_configured(report: Dictionary)
var registered_terrain_ready := false
var limestone_tile_count := 0
var registered_floor_tile_count := 0
var combat_band_active := false
var combat_band_width_cells := 0.42
var _registered_plan: Dictionary = {}
var _render_viewport_rid := RID()
var _restore_snap_transforms := false
var _restore_snap_vertices := false

func _ready() -> void:
	_render_viewport_rid = get_viewport().get_viewport_rid()
	_restore_snap_transforms = bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false))
	_restore_snap_vertices = bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", false))
	RenderingServer.viewport_set_snap_2d_transforms_to_pixel(_render_viewport_rid, false)
	RenderingServer.viewport_set_snap_2d_vertices_to_pixel(_render_viewport_rid, false)
	set_meta("greek_fractional_rendering", true)
	super()
	var arena := room_data as ArenaDefinition
	if arena == null:
		_initialization_failed("registered_terrain_requires_arena_definition")
		return
	var scene_override := registered_terrain_plan_path
	registered_terrain_plan_path = arena.registered_terrain_plan_path
	if not scene_override.is_empty():
		registered_terrain_plan_path = scene_override
	if registered_terrain_plan_path.is_empty() or not FileAccess.file_exists(registered_terrain_plan_path):
		_initialization_failed("registered_terrain_plan_missing:%s" % registered_terrain_plan_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(registered_terrain_plan_path))
	if not parsed is Dictionary:
		_initialization_failed("registered_terrain_plan_invalid")
		return
	_registered_plan = parsed
	var platform := PLATFORM.new()
	# Stable node names and greek_* metadata preserve the validated probes.
	platform.name = "GreekPlatformRisersAndPits"
	platform.z_index = -5
	add_child(platform)
	platform.configure_palette(_registered_plan.get("pit_palette", {}))
	platform.configure(arena, grid_view, get_registered_terrain_manifest_path())
	if not platform.pit_annotation_errors.is_empty():
		_initialization_failed("registered_terrain_pit_annotations_invalid:%s" % platform.pit_annotation_errors)
		return
	var report := install_terrain_plan(registered_terrain_plan_path)
	if not bool(report.get("ok", false)):
		return
	_apply_floor_palette(arena, platform)
	for decoration: Node2D in arena_assembly.get("decorations", []):
		if decoration.has_method("configure_palette"):
			decoration.configure_palette(_registered_plan.get("props_palette", {}))
		if decoration.has_method("configure_footprint"):
			var cell: Vector2i = decoration.get_meta("arena_cell", Vector2i.ZERO)
			var footprint := PackedVector2Array()
			for point: Vector2 in grid_view.get_cell_polygon(cell):
				footprint.append(decoration.to_local(grid_view.to_global(point)))
			decoration.configure_footprint(footprint)
	var expected_floor_count := 0
	for definition in arena.cells:
		if definition != null and definition.defined and definition.cell_type != GridData.CellType.HOLE:
			expected_floor_count += 1
	if registered_floor_tile_count != expected_floor_count:
		_initialization_failed("registered_terrain_palette_count:%d_expected:%d" % [registered_floor_tile_count,expected_floor_count])
		return
	registered_terrain_ready = true
	set_meta("registered_terrain_ready", true)
	set_meta("registered_terrain_initialization", {"ok":true,"plan_path":registered_terrain_plan_path,"floor_tiles":registered_floor_tile_count})
	set_meta("registered_terrain_plan", registered_terrain_plan_path)
	registered_terrain_configured.emit({"ok":true,"plan_path":registered_terrain_plan_path,"floor_tiles":registered_floor_tile_count})

func _apply_floor_palette(arena: ArenaDefinition, platform: Node2D) -> void:
	var terrain := get_node("GreekTerrainComposition")
	var land := terrain.get_node("Land") as Polygon2D
	var meadow_style: Dictionary = _registered_plan.get("land", {})
	var meadow_texture: Texture2D = land.texture
	if meadow_texture == null:
		# Color-only plans are still valid; no biome-specific bitmap fallback.
		var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
		image.fill(land.color)
		meadow_texture = ImageTexture.create_from_image(image)
	var meadow_scale := STYLE.texture_scale(meadow_style.get("texture_scale", [1,1]))
	var meadow_tint := STYLE.color(meadow_style.get("tint", "#ffffff"), Color.WHITE)
	var meadow_repeat := bool(meadow_style.get("texture_repeat", true))
	var floor_palette: Dictionary = _registered_plan.get("floor_palette", {})
	var warmth_setting: Variant = floor_palette.get("warmth", [-0.080,-0.025,0.025,0.065])
	var warmth_values: Array = warmth_setting if warmth_setting is Array else [warmth_setting]
	if warmth_values.is_empty():
		warmth_values = [0.0]
	var palette_materials: Array[ShaderMaterial] = []
	for warmth: Variant in warmth_values:
		var material := ShaderMaterial.new()
		material.shader = _floor_palette_shader()
		material.set_shader_parameter("warmth", float(warmth))
		for name: String in ["shade", "body", "light"]:
			if floor_palette.has(name):
				material.set_shader_parameter("floor_%s" % name, STYLE.color(floor_palette[name],Color.WHITE))
		for name: String in ["painted_steps", "bevel_flatten_strength"]:
			if floor_palette.has(name):
				material.set_shader_parameter(name, float(floor_palette[name]))
		STYLE.apply_shader_parameters(material, floor_palette.get("shader_parameters", {}))
		var band_style: Dictionary = _registered_plan.get("combat_ground_band", {})
		STYLE.apply_shader_parameters(material, band_style.get("shader_parameters", {}))
		palette_materials.append(material)
	var floor_parent := arena_assembly.get("floor_parent") as Node2D
	limestone_tile_count = 0
	registered_floor_tile_count = 0
	if floor_parent == null:
		return
	for tile in floor_parent.get_children():
		if not str(tile.name).begins_with("ArenaTerrain_"):
			continue
		var visual := tile.get_node_or_null("Visual") as Sprite2D
		if visual == null:
			continue
		registered_floor_tile_count += 1
		# The palette remaps stone luminance to the room colors. Applying it
		# to water, lava or ice would erase their authored gameplay identity.
		if StringName(tile.get_meta("terrain_id", &"")) != &"stone":
			continue
		var cell: Vector2i = tile.get_meta("arena_cell", Vector2i.ZERO)
		var cell_hash: int = (cell.x*73856093) ^ (cell.y*19349663)
		cell_hash = (cell_hash ^ (cell_hash >> 13)) * 1274126177
		var material := palette_materials[posmod(cell_hash,palette_materials.size())].duplicate() as ShaderMaterial
		material.set_shader_parameter("meadow_texture", meadow_texture)
		material.set_shader_parameter("meadow_texture_scale", meadow_scale)
		material.set_shader_parameter("meadow_tint", meadow_tint)
		material.set_shader_parameter("meadow_repeat", meadow_repeat)
		material.set_shader_parameter("combat_band_enabled", combat_band_active)
		material.set_shader_parameter("band_width_cells", combat_band_width_cells)
		material.set_shader_parameter("cell_native_center", arena.grid_origin + Vector2(cell.x*arena.axis_x + cell.y*arena.axis_y))
		material.set_shader_parameter("cell_native_span", Vector2(absf(arena.axis_x.x)+absf(arena.axis_y.x), absf(arena.axis_x.y)+absf(arena.axis_y.y)))
		var exposed := Vector4.ZERO
		var directions := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
		for index in range(4):
			var neighbor: Vector2i = cell+directions[index]
			exposed[index] = 1.0 if not platform.floor_cells.has(neighbor) and not platform.pit_cells.has(neighbor) else 0.0
		material.set_shader_parameter("exterior_edges", exposed)
		visual.material = material
		limestone_tile_count += 1
	set_meta("greek_limestone_tile_count", limestone_tile_count)
	set_meta("registered_floor_tile_count", registered_floor_tile_count)

func _floor_palette_shader() -> Shader:
	return LIMESTONE_SHADER

func get_registered_terrain_manifest_path() -> String:
	var path := str(_registered_plan.get("geometry_manifest_path", "geometry_manifest.json"))
	return path if path.begins_with("res://") or path.is_absolute_path() else registered_terrain_plan_path.get_base_dir().path_join(path)

func _create_unit_view(unit: Unit) -> void:
	super(unit)
	var view := _unit_views.get(unit) as Node2D
	if view == null or grid_view == null:
		return
	var footprint := PackedVector2Array()
	for point: Vector2 in grid_view.get_cell_polygon(unit.grid_pos):
		footprint.append(view.to_local(grid_view.to_global(point)))
	for child in view.get_children():
		if child.is_in_group("iso_ground_shadow") and child.has_method("setup"):
			child.setup(footprint)
	view.queue_redraw()

func install_terrain_plan(path: String) -> Dictionary:
	var existing := get_node_or_null("GreekTerrainComposition")
	if existing != null:
		existing.free()
	var composition := TERRAIN_COMPOSITION.new()
	composition.name = "GreekTerrainComposition"
	add_child(composition)
	var report := composition.configure_from_file(path, grid_view, get_node("YSortedWorld") as Node2D)
	if not bool(report.get("ok",false)):
		composition.free()
		_initialization_failed("registered_terrain_composition_failed:%s" % report.get("errors", []))
		return report
	_registered_plan = composition.plan
	var water_style: Dictionary = _registered_plan.get("water", {})
	if not water_style.has("shader_path"):
		var water_material := ShaderMaterial.new()
		water_material.shader = WATER_SHADER
		STYLE.apply_shader_parameters(water_material, water_style.get("shader_parameters", {}))
		composition.get_node("Water").material = water_material
	var details := GROUND_DETAILS.new()
	details.name = "GroundDetails"
	composition.add_child(details)
	var detail_report := details.configure(room_data as ArenaDefinition, grid_view, composition)
	set_meta("greek_ground_details", detail_report)
	_install_combat_ground_band(composition)
	var band_style: Dictionary = _registered_plan.get("combat_ground_band", {})
	if not bool(detail_report.get("ok",false)) or (bool(band_style.get("enabled",false)) and not combat_band_active):
		report["ok"] = false
		report["errors"] = ["registered_terrain_ground_layers_incomplete"]
		_initialization_failed("registered_terrain_ground_layers_incomplete")
		return report
	get_node("PaintedBackground/BackgroundSprite").visible = false
	get_node("PaintedForeground/ForegroundSprite").visible = false
	set_meta("greek_terrain_plan", path)
	set_meta("registered_terrain_plan", path)
	return report

func _install_combat_ground_band(composition: Node2D) -> void:
	combat_band_active = false
	var style: Dictionary = composition.get("plan").get("combat_ground_band", {})
	if not bool(style.get("enabled", false)):
		return
	var band := GROUND_BAND.new()
	band.name = "GroundBand"
	composition.add_child(band)
	var report: Dictionary = band.configure(room_data as ArenaDefinition, grid_view, composition, get_node("GreekPlatformRisersAndPits"))
	if not bool(report.get("ok", false)):
		set_meta("greek_combat_ground_band", report)
		push_error("Registered combat ground band failed: %s" % report.get("errors", []))
		return
	var contour: PackedVector2Array = band.get("outer_contour_grid")
	if contour.size() < 3 or contour.size() > 128:
		band.visible = false
		set_meta("greek_combat_ground_band", {"ok":false,"errors":["ground_band_shader_contour_capacity"]})
		return
	var point_count := contour.size()
	contour.resize(128)
	var arena := room_data as ArenaDefinition
	combat_band_width_cells = float(style.get("width_cells", 0.42))
	for material: ShaderMaterial in band.materials():
		material.set_shader_parameter("contour_grid", contour)
		material.set_shader_parameter("contour_count", point_count)
		material.set_shader_parameter("grid_origin", arena.grid_origin)
		material.set_shader_parameter("grid_axis_x", arena.axis_x)
		material.set_shader_parameter("grid_axis_y", arena.axis_y)
		material.set_shader_parameter("band_width_cells", combat_band_width_cells)
	combat_band_active = true
	set_meta("greek_combat_ground_band", report)

func _initialization_failed(message: String) -> void:
	registered_terrain_ready = false
	var report := {"ok":false,"errors":[message]}
	set_meta("registered_terrain_ready", false)
	set_meta("registered_terrain_initialization", report)
	push_error(message)
	registered_terrain_configured.emit(report)

func _exit_tree() -> void:
	if _render_viewport_rid.is_valid():
		RenderingServer.viewport_set_snap_2d_transforms_to_pixel(_render_viewport_rid,_restore_snap_transforms)
		RenderingServer.viewport_set_snap_2d_vertices_to_pixel(_render_viewport_rid,_restore_snap_vertices)
	super()
