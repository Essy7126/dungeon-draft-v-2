@tool
class_name ArenaRuntimePreview
extends SubViewportContainer

signal preview_rebuilt(signature: Dictionary)
signal preview_failed(message: String)

enum ViewMode {
	LOGIC,
	ART,
	GAME,
}

const UNIT_VIEW_SCENE := preload("res://battle/unit_view.tscn")
const HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]
const DEFAULT_ENEMY := "res://data/units/ennemie/skeleton_melee.tres"
const ArenaCameraFramingServiceScript = preload(
	"res://addons/dungeon_draft_arena_studio/services/arena_camera_framing_service.gd"
)

var arena: ArenaDefinition = null
var view_mode := ViewMode.LOGIC
var show_characters := true
var show_dynamic_walls := true
var show_dynamic_terrains := true
var show_occlusion := true
var show_lighting := true
var preview_signature := {}
var rebuild_count := 0
var light_update_count := 0

var viewport: SubViewport = null
var world_root: Node2D = null
var camera: Camera2D = null
var grid: GridData = null
var pathfinder: Pathfinder = null
var grid_view: PaintedGridView = null
var runtime_state: ArenaRuntimeState = null
var dynamic_surface_visuals: DynamicSurfaceVisualAdapter = null
var assembly := {}
var _debounce: Timer = null
var _requested_generation := 0
var _built_generation := 0


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(640, 420)
	viewport = SubViewport.new()
	viewport.name = "ArenaPreviewViewport"
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	add_child(viewport)
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.12
	_debounce.timeout.connect(_perform_rebuild)
	add_child(_debounce)
	resized.connect(_on_resized)


func set_arena(value: ArenaDefinition, heavy := true) -> void:
	arena = value
	request_refresh(heavy)


func set_view_mode(value: int) -> void:
	view_mode = clampi(value, ViewMode.LOGIC, ViewMode.GAME)
	request_refresh(true)


func request_refresh(heavy := true) -> void:
	_requested_generation += 1
	if not heavy and is_instance_valid(grid_view):
		_apply_view_options()
		light_update_count += 1
		return
	if _debounce != null:
		_debounce.start()


func rebuild_now() -> bool:
	_requested_generation += 1
	if _debounce != null:
		_debounce.stop()
	return _perform_rebuild()


func cleanup_preview() -> void:
	if world_root != null and is_instance_valid(world_root):
		world_root.free()
	world_root = null
	grid_view = null
	grid = null
	pathfinder = null
	runtime_state = null
	dynamic_surface_visuals = null
	assembly = {}
	preview_signature = {}


func parity_with_runtime() -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	var expected := ArenaVisualAssembler.expected_visual_signature(arena)
	var actual := ArenaVisualAssembler.actual_visual_signature(assembly)
	var comparison := ArenaVisualAssembler.compare_expected_to_actual(expected, actual)
	var report := assembly.get("report") as ArenaVisualAssemblyReport
	comparison.ok = bool(comparison.ok) and report != null and report.valid
	comparison["preview"] = actual
	comparison["runtime"] = expected
	comparison["assembly_report"] = report.to_dict() if report != null else {}
	return comparison


func _perform_rebuild() -> bool:
	var generation := _requested_generation
	cleanup_preview()
	if arena == null:
		preview_failed.emit("ArenaDefinition absente.")
		return false
	runtime_state = ArenaRuntimeProjectionService.build(arena)
	if runtime_state == null or runtime_state.arena_projection == null:
		preview_failed.emit("La projection runtime ArenaDefinition est impossible.")
		return false
	var preview_arena := runtime_state.arena_projection
	grid = runtime_state.grid
	if grid == null:
		preview_failed.emit("GridData impossible a construire.")
		return false
	pathfinder = Pathfinder.new(grid)
	world_root = Node2D.new()
	world_root.name = "ArenaPreviewWorld"
	viewport.add_child(world_root)
	_build_background(preview_arena)
	var floor_parent := Node2D.new()
	floor_parent.name = "ArenaTilesLayer"
	floor_parent.y_sort_enabled = false
	world_root.add_child(floor_parent)
	grid_view = PaintedGridView.new()
	grid_view.name = "SharedGridView"
	grid_view.configure(
		preview_arena.painted_map_visual_data,
		preview_arena.grid_layout,
		preview_arena.hero_spawn_zone,
		preview_arena.enemy_spawn_zone
	)
	grid_view.setup(grid)
	world_root.add_child(grid_view)
	var y_sorted_world := Node2D.new()
	y_sorted_world.name = "YSortedWorld"
	y_sorted_world.y_sort_enabled = true
	world_root.add_child(y_sorted_world)
	assembly = ArenaVisualAssembler.assemble(
		preview_arena, grid, pathfinder, grid_view, y_sorted_world,
		world_root, show_dynamic_terrains, floor_parent
	)
	dynamic_surface_visuals = DynamicSurfaceVisualAdapter.new()
	dynamic_surface_visuals.name = "DynamicSurfaceVisualAdapter"
	world_root.add_child(dynamic_surface_visuals)
	dynamic_surface_visuals.configure(
		runtime_state.surface_service, grid_view, y_sorted_world
	)
	var assembly_report := assembly.get("report") as ArenaVisualAssemblyReport
	if assembly_report == null or not assembly_report.valid:
		preview_failed.emit(
			"Assemblage visuel incomplet : %s" % (
				", ".join(assembly_report.errors) if assembly_report != null \
				else "rapport absent"
			)
		)
	if not show_dynamic_walls:
		for wall in assembly.get("walls", []):
			wall.visible = false
	if view_mode == ViewMode.GAME and show_characters:
		_build_units(preview_arena, y_sorted_world)
	_build_foreground(preview_arena, y_sorted_world)
	camera = Camera2D.new()
	camera.name = "PreviewCamera"
	world_root.add_child(camera)
	camera.make_current()
	_apply_view_options()
	_fit_camera(preview_arena)
	preview_signature = ArenaVisualAssembler.actual_visual_signature(assembly)
	_built_generation = generation
	rebuild_count += 1
	preview_rebuilt.emit(preview_signature)
	return assembly_report != null and assembly_report.valid


func update_runtime_surface(cell: Vector2i, surface: int, source_unit = null) -> Dictionary:
	if runtime_state == null:
		return {"handled": false, "error": "Projection runtime absente."}
	return runtime_state.update_surface(cell, surface, source_unit)


func clear_runtime_surface(cell: Vector2i) -> bool:
	return runtime_state.clear_surface(cell) if runtime_state != null else false


func _build_background(value: ArenaDefinition) -> void:
	if value.visual_mode == ArenaDefinition.VisualMode.MODULAR:
		return
	var texture := value.painted_map_visual_data.load_background_texture()
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "PaintedBackground"
	sprite.texture = texture
	sprite.centered = false
	sprite.position = value.image_offset
	sprite.scale = value.image_scale
	sprite.z_index = -100
	world_root.add_child(sprite)


func _build_foreground(value: ArenaDefinition, y_sorted_world: Node2D) -> void:
	if value.visual_mode == ArenaDefinition.VisualMode.MODULAR or not show_occlusion:
		return
	var texture := value.painted_map_visual_data.load_foreground_texture()
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "PaintedForeground"
		sprite.texture = texture
		sprite.centered = false
		sprite.position = value.foreground_offset
		sprite.scale = value.foreground_scale
		sprite.z_index = 20
		world_root.add_child(sprite)
	var occluder := value.painted_map_visual_data.create_foreground_occluder(
		value.painted_map_visual_data.load_background_texture()
	)
	if occluder != null:
		y_sorted_world.add_child(occluder)


func _build_units(value: ArenaDefinition, parent: Node2D) -> void:
	var placed := 0
	for spawn in value.spawns:
		if spawn == null or placed >= 12 or not grid.is_walkable(spawn.cell):
			continue
		var data := _unit_data_for_spawn(spawn)
		if data == null:
			continue
		var unit := Unit.from_data(data)
		unit.grid_pos = spawn.cell
		# Certaines UnitData récentes portent un visual_scene 3D. UnitView est
		# bien le composant runtime réel 2D ; son fallback SpriteFrames est ici
		# préférable à l'instanciation d'un Node3D orphelin dans un SubViewport 2D.
		unit.visual_scene = null
		var view := UNIT_VIEW_SCENE.instantiate()
		parent.add_child(view)
		view.setup(unit)
		view.position = parent.to_local(
			grid_view.to_global(grid_view.grid_to_local(spawn.cell))
		)
		view.scale = Vector2(0.62, 0.62)
		view.set_meta("preview_unit", true)
		placed += 1


func _unit_data_for_spawn(spawn: ArenaSpawnDefinition) -> UnitData:
	if spawn.is_hero():
		var index := clampi(spawn.kind, 0, HERO_PATHS.size() - 1)
		return load(HERO_PATHS[index]) as UnitData
	if str(spawn.unit_id).begins_with("res://") and ResourceLoader.exists(str(spawn.unit_id)):
		return load(str(spawn.unit_id)) as UnitData
	return load(DEFAULT_ENEMY) as UnitData if ResourceLoader.exists(DEFAULT_ENEMY) else null


func _apply_view_options() -> void:
	if grid_view == null:
		return
	match view_mode:
		ViewMode.LOGIC:
			grid_view.visible = true
			grid_view.set_render_options(false, true, true, true)
			grid_view.set_debug_layers(true, true, true, true, false)
		ViewMode.ART:
			grid_view.visible = true
			grid_view.set_render_options(false, false, false, false)
			grid_view.set_debug_layers(false, false, false, false, false)
		ViewMode.GAME:
			grid_view.visible = true
			grid_view.set_render_options(false, false, false, false)
			grid_view.set_debug_layers(false, false, false, false, false)


func _fit_camera(value: ArenaDefinition) -> void:
	if camera == null or value.painted_map_visual_data == null:
		return
	if value.visual_mode != ArenaDefinition.VisualMode.MODULAR:
		var framing := ArenaCameraFramingServiceScript.painted_framing(
			value.painted_map_visual_data,
			Vector2(viewport.size),
			value.painted_map_visual_data.presentation_profile
		)
		if bool(framing.get("ok", false)):
			camera.position = framing.position
			camera.zoom = framing.zoom
		return
	var bounds := value.painted_map_visual_data.image_rect()
	if value.visual_mode == ArenaDefinition.VisualMode.MODULAR or bounds.size == Vector2.ZERO:
		bounds = value.painted_map_visual_data.grid_bounds_display().grow(64.0)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	camera.position = bounds.get_center() + value.camera_offset
	var viewport_size := Vector2(viewport.size)
	var factor := minf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y)
	factor = clampf(factor * 0.92 * value.camera_zoom, 0.05, 4.0)
	camera.zoom = Vector2(factor, factor)


func _on_resized() -> void:
	if viewport == null:
		return
	if arena != null:
		_fit_camera(arena)
