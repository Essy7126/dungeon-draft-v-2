class_name HubArchivist
extends Interactable

signal interaction_activated(actor: Node)

@export var occupied_cell := Vector2i(5, 11)
@export var approach_cells: Array[Vector2i] = [
	Vector2i(4, 11),
	Vector2i(5, 10),
	Vector2i(6, 11),
	Vector2i(5, 12),
]
@export var data: LanternboundArchivistData = null
@export var interaction_enabled := true
@export_range(0.1, 1.0, 0.01) var render_display_scale := 0.60
@export_range(40.0, 160.0, 1.0) var max_interaction_distance := 82.0
## Yaw fixe calibre pour que l'avant reel du GLB vise ArchivistLookTarget.
## Le SubViewport conserve ce cap : aucune cellule d'approche ne le modifie.
@export_range(-180.0, 180.0, 0.1) var facing_yaw_degrees := 55.0

@onready var render_sprite: Sprite2D = $RenderSprite
@onready var character_viewport: SubViewport = $CharacterViewport
@onready var character_world: Node3D = $CharacterViewport/CharacterWorld
@onready var camera: Camera3D = $CharacterViewport/CharacterWorld/Camera3D
@onready var model_pivot: Node3D = $CharacterViewport/CharacterWorld/ModelPivot
@onready var model: Node3D = $CharacterViewport/CharacterWorld/ModelPivot/Model
@onready var click_area: Area2D = $ClickArea
@onready var click_collision: CollisionShape2D = $ClickArea/CollisionShape2D

var _hovered := false
var _approach_world_positions := PackedVector2Array()


func _ready() -> void:
	render_sprite.texture = character_viewport.get_texture()
	render_sprite.scale = Vector2.ONE * render_display_scale
	model_pivot.rotation_degrees.y = facing_yaw_degrees
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	click_area.input_event.connect(_on_click_area_input)
	click_area.mouse_entered.connect(_on_click_area_mouse_entered)
	click_area.mouse_exited.connect(_on_click_area_mouse_exited)
	_realign_to_ground()


func _exit_tree() -> void:
	if _hovered:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if is_instance_valid(character_viewport):
		character_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func configure_navigation_points(
		occupied_world_position: Vector2,
		approach_world_positions: PackedVector2Array
	) -> void:
	global_position = occupied_world_position
	_approach_world_positions = approach_world_positions.duplicate()


func get_interaction_positions(
		_actor: Node,
		_navigation_region: HubNavigationRegion2D
	) -> PackedVector2Array:
	return _approach_world_positions.duplicate()


func can_interact(actor: Node) -> bool:
	return interaction_enabled and super.can_interact(actor)


func get_occupied_world_position() -> Vector2:
	return global_position


func get_max_interaction_distance() -> float:
	return max_interaction_distance


func get_approach_world_positions() -> PackedVector2Array:
	return _approach_world_positions.duplicate()


func interact(actor: Node) -> void:
	if can_interact(actor):
		interaction_activated.emit(actor)


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	click_area.input_pickable = enabled
	if not enabled:
		_set_hovered(false)


func is_click_proxy_world_point(world_position: Vector2) -> bool:
	if not interaction_enabled or click_collision.disabled:
		return false
	var rectangle := click_collision.shape as RectangleShape2D
	if rectangle == null:
		return false
	var local_point := click_collision.to_local(world_position)
	var half_size := rectangle.size * 0.5
	return absf(local_point.x) <= half_size.x \
		and absf(local_point.y) <= half_size.y


func is_hovered() -> bool:
	return _hovered


func get_model_scale() -> Vector3:
	return model.scale


func get_facing_yaw_degrees() -> float:
	return model_pivot.rotation_degrees.y


func _on_click_area_input(
		_viewport: Node,
		event: InputEvent,
		_shape_index: int
	) -> void:
	if interaction_enabled and event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		interaction_requested.emit(self)
		get_viewport().set_input_as_handled()


func _on_click_area_mouse_entered() -> void:
	if interaction_enabled:
		_set_hovered(true)


func _on_click_area_mouse_exited() -> void:
	_set_hovered(false)


func _set_hovered(enabled: bool) -> void:
	_hovered = enabled
	render_sprite.self_modulate = Color(1.12, 1.08, 0.92, 1.0) \
		if enabled else Color.WHITE
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if enabled else Input.CURSOR_ARROW
	)


func _realign_to_ground() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var ground_pixel := camera.unproject_position(character_world.to_global(Vector3.ZERO))
	render_sprite.position = -ground_pixel * render_sprite.scale
