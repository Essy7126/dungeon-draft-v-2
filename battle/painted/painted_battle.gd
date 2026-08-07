extends "res://battle/battle.gd"

const ArenaCameraFramingServiceScript = preload(
	"res://addons/dungeon_draft_arena_studio/services/arena_camera_framing_service.gd"
)

## Adaptateur de scene commun aux trois peintures. Il configure le fond et la
## projection avant de laisser battle.gd construire exactement un GridData, un
## Pathfinder, un TerrainEffects et un DeploymentController.

var painted_visual_data: PaintedMapVisualData = null
var painted_grid_layout: RoomGridLayout = null
var presentation_profile: BattlePresentationProfile = null
var _presentation_camera_enabled := true
var _presentation_unit_scale_enabled := true
var _presentation_readability_enabled := true
var arena_assembly := {}


func _ready() -> void:
	room_data = GameManager.get_current_room()
	if room_data == null:
		push_error("PaintedBattle requiert la RoomData courante du GameManager.")
		return
	painted_visual_data = room_data.painted_map_visual_data
	painted_grid_layout = room_data.grid_layout
	presentation_profile = painted_visual_data.presentation_profile \
		if painted_visual_data != null else null
	if painted_visual_data == null or painted_grid_layout == null:
		push_error("La salle peinte doit declarer sa calibration et son layout.")
		return
	grid_cols = painted_grid_layout.logical_size.x
	grid_rows = painted_grid_layout.logical_size.y
	_configure_painted_layers()
	super()
	var definition := room_data as ArenaDefinition
	if definition != null and grid != null and pathfinder != null:
		var floor_parent := _find_or_create_arena_tile_parent(false)
		arena_assembly = ArenaVisualAssembler.assemble(
			definition, grid, pathfinder, get_node("IsoGridView"),
			get_node("YSortedWorld"), self,
			definition.visual_mode == ArenaDefinition.VisualMode.HYBRID,
			floor_parent
		)


func _configure_painted_layers() -> void:
	var background := get_node("PaintedBackground/BackgroundSprite") as Sprite2D
	background.texture = painted_visual_data.load_background_texture()
	background.centered = false
	background.position = painted_visual_data.image_offset
	background.scale = painted_visual_data.image_scale

	var foreground := get_node("PaintedForeground/ForegroundSprite") as Sprite2D
	foreground.texture = painted_visual_data.load_foreground_texture()
	foreground.centered = false
	foreground.position = painted_visual_data.foreground_offset
	foreground.scale = painted_visual_data.foreground_scale
	foreground.visible = foreground.texture != null
	_configure_painted_occluder(background.texture)

	var painted_view := get_node("IsoGridView") as PaintedGridView
	painted_view.configure(
		painted_visual_data,
		painted_grid_layout,
		room_data.hero_spawn_zone,
		room_data.enemy_spawn_zone
	)


func _configure_painted_occluder(background_texture: Texture2D) -> void:
	var world := get_node("YSortedWorld") as Node2D
	for child in world.get_children():
		if child.is_in_group("painted_foreground_occluders"):
			# La reconstruction peut arriver plusieurs fois dans la meme frame
			# (reload/capture). Retirer immediatement l'ancien masque garantit une
			# seule instance sans attendre la vidange de queue_free().
			child.free()
	var occluder := painted_visual_data.create_foreground_occluder(background_texture)
	if occluder != null:
		world.add_child(occluder)


func _import_terrain_from_tilemap() -> void:
	if painted_grid_layout != null:
		painted_grid_layout.apply_to_grid(grid)


func _create_unit_view(unit: Unit) -> void:
	super(unit)
	var view = _unit_views.get(unit)
	if is_instance_valid(view) and view.has_method("apply_painted_presentation"):
		view.apply_painted_presentation(
			presentation_profile,
			_presentation_unit_scale_enabled,
			_presentation_readability_enabled
		)
	_update_painted_occlusion()


func _process(_delta: float) -> void:
	_update_painted_occlusion()


func _update_painted_occlusion() -> void:
	if painted_visual_data == null:
		return
	for unit in _unit_views:
		var view = _unit_views[unit]
		if is_instance_valid(view):
			view.visible = not painted_visual_data.is_position_fully_occluded(
				view.position
			)


func _fit_camera_to_battle() -> void:
	if camera == null or painted_visual_data == null:
		return
	var framing := ArenaCameraFramingServiceScript.painted_framing(
		painted_visual_data, get_viewport_rect().size,
		presentation_profile if _presentation_camera_enabled else null
	)
	if not bool(framing.get("ok", false)):
		return
	camera.position = framing.position
	camera.zoom = framing.zoom


## Crochet deterministe pour les captures avant/apres. Le mode normal utilise
## toujours les trois options actives ; aucune logique de combat n'en depend.
func apply_presentation_variant(
		camera_enabled: bool,
		unit_scale_enabled: bool,
		readability_enabled: bool
	) -> void:
	_presentation_camera_enabled = camera_enabled
	_presentation_unit_scale_enabled = unit_scale_enabled
	_presentation_readability_enabled = readability_enabled
	_fit_camera_to_battle()
	for unit in _unit_views:
		var view = _unit_views[unit]
		if is_instance_valid(view) and view.has_method("apply_painted_presentation"):
			view.apply_painted_presentation(
				presentation_profile,
				unit_scale_enabled,
				readability_enabled
			)
